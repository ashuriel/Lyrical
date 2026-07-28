-- =============================================================================
-- 009_add_public_profiles_and_follows.sql
--
-- Public profile RPC + follow/unfollow via SECURITY DEFINER RPCs.
-- The follows table already exists (001); this migration does not recreate it.
--
-- Direct INSERT/DELETE on follows are revoked from clients; mutations go
-- through follow_user / unfollow_user. SELECT remains for public relationship
-- visibility (counts also come from get_public_profile).
--
-- Does not implement follower lists, notifications, chat, or comments.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Harden follows constraints (idempotent if already present)
-- -----------------------------------------------------------------------------

-- Primary key (follower_id, followed_id) and follows_no_self_follow already
-- exist from 001. Ensure indexes for count patterns exist.
create index if not exists follows_follower_id_idx on public.follows (follower_id);
create index if not exists follows_followed_id_idx on public.follows (followed_id);

-- -----------------------------------------------------------------------------
-- 2) get_public_profile
-- Missing profile raises controlled error 'profile not available' (P0002).
-- Never returns email, onboarding, bookmarks, or auth metadata.
-- -----------------------------------------------------------------------------

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
    and po.status = 'approved'
    and po.is_hidden = false
    and po.deleted_at is null;

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

comment on function public.get_public_profile(uuid) is
  'Public profile card: display fields, public poem count, follow counts, '
  'and current-user follow flags. Raises profile not available when missing. '
  'Never returns email, onboarding, or bookmarks.';

revoke all on function public.get_public_profile(uuid) from public;
grant execute on function public.get_public_profile(uuid) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3) follow_user
-- -----------------------------------------------------------------------------

create or replace function public.follow_user(p_followed_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_count bigint;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if p_followed_id = caller_id then
    raise exception 'cannot follow yourself'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.profiles as pr where pr.id = p_followed_id
  ) then
    raise exception 'profile not available'
      using errcode = 'P0002';
  end if;

  insert into public.follows (follower_id, followed_id)
  values (caller_id, p_followed_id)
  on conflict (follower_id, followed_id) do nothing;

  select count(*)::bigint
  into v_count
  from public.follows as f
  where f.followed_id = p_followed_id;

  return json_build_object(
    'is_following', true,
    'follower_count', v_count
  );
end;
$$;

comment on function public.follow_user(uuid) is
  'Idempotent follow. follower_id is always auth.uid(). Returns is_following and follower_count.';

revoke all on function public.follow_user(uuid) from public;
revoke all on function public.follow_user(uuid) from anon;
grant execute on function public.follow_user(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) unfollow_user
-- -----------------------------------------------------------------------------

create or replace function public.unfollow_user(p_followed_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_count bigint;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  delete from public.follows as f
  where f.follower_id = caller_id
    and f.followed_id = p_followed_id;

  select count(*)::bigint
  into v_count
  from public.follows as f
  where f.followed_id = p_followed_id;

  return json_build_object(
    'is_following', false,
    'follower_count', v_count
  );
end;
$$;

comment on function public.unfollow_user(uuid) is
  'Idempotent unfollow of the caller''s relationship only. Returns is_following=false and follower_count.';

revoke all on function public.unfollow_user(uuid) from public;
revoke all on function public.unfollow_user(uuid) from anon;
grant execute on function public.unfollow_user(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Direct follows privilege changes
-- -----------------------------------------------------------------------------
-- Clients no longer insert/delete follows directly; RPCs own mutations.
-- Keep SELECT so the public follow graph remains readable if needed later;
-- public counts are served by get_public_profile.
-- Drop insert/delete policies so unused write paths are not advertised.

drop policy if exists "follows_insert_as_self" on public.follows;
drop policy if exists "follows_delete_as_self" on public.follows;

revoke insert, delete on table public.follows from authenticated;
-- SELECT grants from 001 remain: anon, authenticated.
