-- =============================================================================
-- 012_fix_publication_and_like_featured_selection.sql
--
-- 1) Fix approved poems missing from Explorer/Search when published_at is null.
-- 2) Align public visibility helpers with the canonical public-poem rule.
-- 3) Replace client-side daily/monthly heuristics with like-period RPCs
--    (America/Santo_Domingo calendar windows).
--
-- Does not drop featured_poems (legacy table may remain unused by Explorer).
-- Does not duplicate poem_approved / poem_rejected notification inserts.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Canonical public visibility (documentation + helpers)
-- A public poem must satisfy ALL of:
--   status = 'approved'
--   deleted_at IS NULL
--   is_hidden = false
--   published_at IS NOT NULL
-- -----------------------------------------------------------------------------

-- 1) Align is_public_poem with Explorer / Search filters
create or replace function public.is_public_poem(p_poem_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.poems as po
    where po.id = p_poem_id
      and po.status = 'approved'::public.poem_status
      and po.is_hidden = false
      and po.deleted_at is null
      and po.published_at is not null
  );
$$;

comment on function public.is_public_poem(uuid) is
  'True when poem is publicly visible: approved, not hidden, not deleted, '
  'and published_at is set. Used by engagement RPCs.';

revoke all on function public.is_public_poem(uuid) from public;
revoke all on function public.is_public_poem(uuid) from anon, authenticated;

-- 2) Align public profile published count with the same rule
create or replace function public.get_public_profile(p_user_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_anonymous_name text;
  v_gender text;
  v_bio text;
  v_avatar_url text;
  v_created_at timestamptz;
  v_published_count bigint;
  v_follower_count bigint;
  v_following_count bigint;
  v_is_followed boolean := false;
  v_is_current boolean := false;
begin
  select
    pr.anonymous_name,
    pr.gender,
    pr.bio,
    pr.avatar_url,
    pr.created_at
  into
    v_anonymous_name,
    v_gender,
    v_bio,
    v_avatar_url,
    v_created_at
  from public.profiles as pr
  where pr.id = p_user_id;

  if v_anonymous_name is null then
    raise exception 'profile not available'
      using errcode = 'P0002';
  end if;

  select count(*)::bigint
    into v_published_count
  from public.poems as po
  where po.author_id = p_user_id
    and po.status = 'approved'::public.poem_status
    and po.is_hidden = false
    and po.deleted_at is null
    and po.published_at is not null;

  select count(*)::bigint
    into v_follower_count
  from public.follows as f
  where f.followed_id = p_user_id;

  select count(*)::bigint
    into v_following_count
  from public.follows as f
  where f.follower_id = p_user_id;

  if caller_id is not null then
    v_is_current := (caller_id = p_user_id);

    select exists (
      select 1
      from public.follows as f
      where f.follower_id = caller_id
        and f.followed_id = p_user_id
    )
    into v_is_followed;
  end if;

  return json_build_object(
    'user_id', p_user_id,
    'anonymous_name', v_anonymous_name,
    'gender', v_gender,
    'bio', v_bio,
    'avatar_url', v_avatar_url,
    'created_at', v_created_at,
    'published_poem_count', v_published_count,
    'follower_count', v_follower_count,
    'following_count', v_following_count,
    'is_followed_by_current_user', v_is_followed,
    'is_current_user', v_is_current
  );
end;
$$;

-- 3) Harden published_at automation + approve_poem
-- Privileged path still stamps published_at; approve_poem also sets it
-- explicitly so Explorer/Search never see approved + null published_at.

create or replace function public.enforce_poem_update_guards()
returns trigger
language plpgsql
as $$
declare
  is_privileged boolean;
begin
  new.updated_at := now();

  is_privileged :=
    coalesce(auth.role(), '') = 'service_role'
    or current_user in ('postgres', 'supabase_admin');

  if is_privileged then
    if new.status = 'approved'::public.poem_status
       and old.status is distinct from 'approved'::public.poem_status
       and new.published_at is null then
      new.published_at := now();
    end if;
    return new;
  end if;

  if new.id is distinct from old.id then
    raise exception 'poems.id is immutable';
  end if;

  if new.author_id is distinct from old.author_id then
    raise exception 'poems.author_id is immutable';
  end if;

  if new.title is distinct from old.title
     or new.content is distinct from old.content then
    raise exception 'poem title and content cannot be edited after submission';
  end if;

  if new.status is distinct from old.status then
    raise exception 'poem moderation status cannot be changed by this role';
  end if;

  if new.published_at is distinct from old.published_at then
    raise exception 'published_at cannot be changed by clients';
  end if;

  if new.poetry_type_id is distinct from old.poetry_type_id then
    raise exception 'poetry_type_id cannot be changed after submission';
  end if;

  if new.created_at is distinct from old.created_at then
    raise exception 'poems.created_at is immutable';
  end if;

  if old.deleted_at is not null
     and new.deleted_at is distinct from old.deleted_at then
    raise exception 'soft-deleted poems cannot be restored by clients';
  end if;

  return new;
end;
$$;

create or replace function public.approve_poem(p_poem_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
  v_poem_id uuid;
  v_status public.poem_status;
  v_published_at timestamptz;
begin
  perform public.require_current_user_admin();

  if p_poem_id is null then
    raise exception 'poem already reviewed or unavailable'
      using errcode = 'P0002';
  end if;

  -- Set published_at in the same statement (coalesce preserves any prior stamp).
  -- poems_enforce_update_guards also stamps when privileged and null.
  -- poems_notify_moderation still creates exactly one poem_approved notification.
  update public.poems as po
  set
    status = 'approved'::public.poem_status,
    published_at = coalesce(po.published_at, now())
  where po.id = p_poem_id
    and po.status = 'pending'::public.poem_status
    and po.deleted_at is null
  returning po.id, po.status, po.published_at
  into v_poem_id, v_status, v_published_at;

  get diagnostics updated_count = row_count;

  if updated_count = 1 then
    return json_build_object(
      'poem_id', v_poem_id,
      'status', v_status::text,
      'published_at', v_published_at,
      'success', true
    );
  end if;

  raise exception 'poem already reviewed or unavailable'
    using errcode = 'P0002';
end;
$$;

comment on function public.approve_poem(uuid) is
  'Admin-only approve. Sets status=approved and published_at=coalesce(existing, now()). '
  'Concurrent updates race on status=pending. Notification via poems_notify_moderation.';

-- Backfill already-approved poems that are invisible to Explorer/Search.
update public.poems as po
set published_at = coalesce(po.updated_at, po.created_at, now())
where po.status = 'approved'::public.poem_status
  and po.deleted_at is null
  and po.published_at is null;

-- -----------------------------------------------------------------------------
-- 4) Indexes for like-period ranking (skip if already present)
-- -----------------------------------------------------------------------------

create index if not exists poem_likes_created_at_poem_id_idx
  on public.poem_likes (created_at, poem_id);

create index if not exists poems_public_visibility_published_idx
  on public.poems (published_at desc, id desc)
  where status = 'approved'
    and is_hidden = false
    and deleted_at is null
    and published_at is not null;

-- -----------------------------------------------------------------------------
-- 5) Shared featured selection helper (SECURITY DEFINER, not granted to clients)
-- Timezone: America/Santo_Domingo for calendar day/month boundaries.
-- Ranking: period_like_count DESC, total_like_count DESC, published_at ASC, id ASC
-- Fallback: most recently published public poem in the period, else overall.
-- -----------------------------------------------------------------------------

create or replace function public._featured_poem_for_period(
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_row record;
begin
  -- Primary: most likes received within [start, end).
  select
    po.id as poem_id,
    po.title,
    po.content,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.published_at,
    po.created_at,
    coalesce(period_likes.cnt, 0)::bigint as period_like_count,
    coalesce(total_likes.cnt, 0)::bigint as total_like_count,
    case
      when caller_id is null then false
      else exists (
        select 1
        from public.poem_likes as pl
        where pl.poem_id = po.id
          and pl.user_id = caller_id
      )
    end as is_liked_by_current_user,
    case
      when caller_id is null then false
      else exists (
        select 1
        from public.poem_bookmarks as pb
        where pb.poem_id = po.id
          and pb.user_id = caller_id
      )
    end as is_bookmarked_by_current_user
  into v_row
  from public.poems as po
  join public.profiles as pr
    on pr.id = po.author_id
  join public.poetry_types as pt
    on pt.id = po.poetry_type_id
  left join lateral (
    select count(*)::bigint as cnt
    from public.poem_likes as pl
    where pl.poem_id = po.id
      and pl.created_at >= p_period_start
      and pl.created_at < p_period_end
  ) as period_likes on true
  left join lateral (
    select count(*)::bigint as cnt
    from public.poem_likes as pl
    where pl.poem_id = po.id
  ) as total_likes on true
  where po.status = 'approved'::public.poem_status
    and po.is_hidden = false
    and po.deleted_at is null
    and po.published_at is not null
  order by
    coalesce(period_likes.cnt, 0) desc,
    coalesce(total_likes.cnt, 0) desc,
    po.published_at asc,
    po.id asc
  limit 1;

  -- If the winner has zero period likes, still accept it only when it truly
  -- ranked first (all zeros). Prefer period-local recent publish as fallback
  -- when every candidate has zero period likes — replace with recent-in-period.
  if v_row.poem_id is not null and coalesce(v_row.period_like_count, 0) > 0 then
    return json_build_object(
      'poem_id', v_row.poem_id,
      'title', v_row.title,
      'content', v_row.content,
      'poetry_type_id', v_row.poetry_type_id,
      'poetry_type_name', v_row.poetry_type_name,
      'author_id', v_row.author_id,
      'author_anonymous_name', v_row.author_anonymous_name,
      'author_avatar_url', v_row.author_avatar_url,
      'published_at', v_row.published_at,
      'created_at', v_row.created_at,
      'period_like_count', v_row.period_like_count,
      'total_like_count', v_row.total_like_count,
      'is_liked_by_current_user', v_row.is_liked_by_current_user,
      'is_bookmarked_by_current_user', v_row.is_bookmarked_by_current_user,
      'selection_mode', 'likes'
    );
  end if;

  -- Fallback A: most recently published public poem within the period window
  -- (by published_at), period_like_count may be 0.
  select
    po.id as poem_id,
    po.title,
    po.content,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.published_at,
    po.created_at,
    coalesce((
      select count(*)::bigint
      from public.poem_likes as pl
      where pl.poem_id = po.id
        and pl.created_at >= p_period_start
        and pl.created_at < p_period_end
    ), 0) as period_like_count,
    coalesce((
      select count(*)::bigint
      from public.poem_likes as pl
      where pl.poem_id = po.id
    ), 0) as total_like_count,
    case
      when caller_id is null then false
      else exists (
        select 1 from public.poem_likes as pl
        where pl.poem_id = po.id and pl.user_id = caller_id
      )
    end as is_liked_by_current_user,
    case
      when caller_id is null then false
      else exists (
        select 1 from public.poem_bookmarks as pb
        where pb.poem_id = po.id and pb.user_id = caller_id
      )
    end as is_bookmarked_by_current_user
  into v_row
  from public.poems as po
  join public.profiles as pr on pr.id = po.author_id
  join public.poetry_types as pt on pt.id = po.poetry_type_id
  where po.status = 'approved'::public.poem_status
    and po.is_hidden = false
    and po.deleted_at is null
    and po.published_at is not null
    and po.published_at >= p_period_start
    and po.published_at < p_period_end
  order by po.published_at desc, po.id desc
  limit 1;

  if v_row.poem_id is not null then
    return json_build_object(
      'poem_id', v_row.poem_id,
      'title', v_row.title,
      'content', v_row.content,
      'poetry_type_id', v_row.poetry_type_id,
      'poetry_type_name', v_row.poetry_type_name,
      'author_id', v_row.author_id,
      'author_anonymous_name', v_row.author_anonymous_name,
      'author_avatar_url', v_row.author_avatar_url,
      'published_at', v_row.published_at,
      'created_at', v_row.created_at,
      'period_like_count', v_row.period_like_count,
      'total_like_count', v_row.total_like_count,
      'is_liked_by_current_user', v_row.is_liked_by_current_user,
      'is_bookmarked_by_current_user', v_row.is_bookmarked_by_current_user,
      'selection_mode', 'fallback_period'
    );
  end if;

  -- Fallback B: most recently published public poem overall.
  select
    po.id as poem_id,
    po.title,
    po.content,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.published_at,
    po.created_at,
    coalesce((
      select count(*)::bigint
      from public.poem_likes as pl
      where pl.poem_id = po.id
        and pl.created_at >= p_period_start
        and pl.created_at < p_period_end
    ), 0) as period_like_count,
    coalesce((
      select count(*)::bigint
      from public.poem_likes as pl
      where pl.poem_id = po.id
    ), 0) as total_like_count,
    case
      when caller_id is null then false
      else exists (
        select 1 from public.poem_likes as pl
        where pl.poem_id = po.id and pl.user_id = caller_id
      )
    end as is_liked_by_current_user,
    case
      when caller_id is null then false
      else exists (
        select 1 from public.poem_bookmarks as pb
        where pb.poem_id = po.id and pb.user_id = caller_id
      )
    end as is_bookmarked_by_current_user
  into v_row
  from public.poems as po
  join public.profiles as pr on pr.id = po.author_id
  join public.poetry_types as pt on pt.id = po.poetry_type_id
  where po.status = 'approved'::public.poem_status
    and po.is_hidden = false
    and po.deleted_at is null
    and po.published_at is not null
  order by po.published_at desc, po.id desc
  limit 1;

  if v_row.poem_id is null then
    return null;
  end if;

  return json_build_object(
    'poem_id', v_row.poem_id,
    'title', v_row.title,
    'content', v_row.content,
    'poetry_type_id', v_row.poetry_type_id,
    'poetry_type_name', v_row.poetry_type_name,
    'author_id', v_row.author_id,
    'author_anonymous_name', v_row.author_anonymous_name,
    'author_avatar_url', v_row.author_avatar_url,
    'published_at', v_row.published_at,
    'created_at', v_row.created_at,
    'period_like_count', v_row.period_like_count,
    'total_like_count', v_row.total_like_count,
    'is_liked_by_current_user', v_row.is_liked_by_current_user,
    'is_bookmarked_by_current_user', v_row.is_bookmarked_by_current_user,
    'selection_mode', 'fallback_recent'
  );
end;
$$;

comment on function public._featured_poem_for_period(timestamptz, timestamptz) is
  'Internal helper for daily/monthly featured selection. Not granted to clients.';

revoke all on function public._featured_poem_for_period(timestamptz, timestamptz)
  from public;
revoke all on function public._featured_poem_for_period(timestamptz, timestamptz)
  from anon, authenticated;

-- 6) Daily featured — America/Santo_Domingo calendar day
create or replace function public.get_daily_featured_poem()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text := 'America/Santo_Domingo';
  v_local_now timestamp;
  v_start timestamptz;
  v_end timestamptz;
begin
  v_local_now := timezone(v_tz, now());
  v_start := (date_trunc('day', v_local_now) at time zone v_tz);
  v_end := ((date_trunc('day', v_local_now) + interval '1 day') at time zone v_tz);
  return public._featured_poem_for_period(v_start, v_end);
end;
$$;

comment on function public.get_daily_featured_poem() is
  'Public poem with the most likes during the current America/Santo_Domingo day. '
  'Falls back to recent public poems when the day has no likes. Never returns email.';

revoke all on function public.get_daily_featured_poem() from public;
grant execute on function public.get_daily_featured_poem() to anon, authenticated;

-- 7) Monthly featured — America/Santo_Domingo calendar month
create or replace function public.get_monthly_featured_poem()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tz text := 'America/Santo_Domingo';
  v_local_now timestamp;
  v_start timestamptz;
  v_end timestamptz;
begin
  v_local_now := timezone(v_tz, now());
  v_start := (date_trunc('month', v_local_now) at time zone v_tz);
  v_end := ((date_trunc('month', v_local_now) + interval '1 month') at time zone v_tz);
  return public._featured_poem_for_period(v_start, v_end);
end;
$$;

comment on function public.get_monthly_featured_poem() is
  'Public poem with the most likes during the current America/Santo_Domingo month. '
  'Falls back to recent public poems when the month has no likes. Never returns email.';

revoke all on function public.get_monthly_featured_poem() from public;
grant execute on function public.get_monthly_featured_poem() to anon, authenticated;

-- Note: public.featured_poems remains in the schema for legacy compatibility
-- but Explorer no longer reads it after this migration.
