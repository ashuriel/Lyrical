-- =============================================================================
-- 008_add_poem_likes_and_bookmarks.sql
--
-- Public poem likes (countable) and private bookmarks (owner-only).
-- Mutations go through SECURITY DEFINER RPCs. Clients do not get INSERT/DELETE
-- on these tables. Bookmarks may be SELECTed by the owner for Guardados.
-- Like rows are not directly selectable by clients (counts via RPCs only).
--
-- Does not implement follows, notifications, comments, or public profiles.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) poem_likes
-- -----------------------------------------------------------------------------

create table public.poem_likes (
  user_id uuid not null references public.profiles (id) on delete cascade,
  poem_id uuid not null references public.poems (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, poem_id)
);

comment on table public.poem_likes is
  'Public appreciation of poems. One like per user per poem. Mutations via RPC only.';

-- PK (user_id, poem_id) covers "has this user liked this poem?".
-- Index poem_id for efficient public like counts.
create index poem_likes_poem_id_idx on public.poem_likes (poem_id);

-- -----------------------------------------------------------------------------
-- 2) poem_bookmarks
-- -----------------------------------------------------------------------------

create table public.poem_bookmarks (
  user_id uuid not null references public.profiles (id) on delete cascade,
  poem_id uuid not null references public.poems (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, poem_id)
);

comment on table public.poem_bookmarks is
  'Private saved poems. Visible only to the owning user. Mutations via RPC only.';

-- Owner library ordered by save time (user_id = auth.uid() filter + order).
create index poem_bookmarks_user_created_idx
  on public.poem_bookmarks (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 3) RLS
-- -----------------------------------------------------------------------------

alter table public.poem_likes enable row level security;
alter table public.poem_likes force row level security;

alter table public.poem_bookmarks enable row level security;
alter table public.poem_bookmarks force row level security;

-- No SELECT/INSERT/UPDATE/DELETE policies on poem_likes for anon/authenticated.
-- All like reads/writes go through SECURITY DEFINER RPCs so like-user identities
-- and unrestricted like history are not exposed via PostgREST.

-- Bookmarks: owner may SELECT own rows for Guardados joins. No INSERT/DELETE
-- policies — mutations use RPCs only.
create policy "poem_bookmarks_select_own"
  on public.poem_bookmarks
  for select
  to authenticated
  using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 4) Table privileges
-- -----------------------------------------------------------------------------

-- Likes: no direct client access. RPCs (definer) bypass RLS for controlled ops.
revoke all on table public.poem_likes from public;
revoke all on table public.poem_likes from anon;
revoke all on table public.poem_likes from authenticated;

-- Bookmarks: SELECT own rows only (RLS). No INSERT/UPDATE/DELETE for clients.
revoke all on table public.poem_bookmarks from public;
revoke all on table public.poem_bookmarks from anon;
revoke all on table public.poem_bookmarks from authenticated;
grant select on table public.poem_bookmarks to authenticated;

-- -----------------------------------------------------------------------------
-- Helpers (internal): public poem visibility check
-- -----------------------------------------------------------------------------

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
      and po.status = 'approved'
      and po.is_hidden = false
      and po.deleted_at is null
  );
$$;

comment on function public.is_public_poem(uuid) is
  'Internal helper: true when poem is approved, visible, and not deleted.';

revoke all on function public.is_public_poem(uuid) from public;
revoke all on function public.is_public_poem(uuid) from anon;
revoke all on function public.is_public_poem(uuid) from authenticated;

-- -----------------------------------------------------------------------------
-- 5) like_poem
-- -----------------------------------------------------------------------------

create or replace function public.like_poem(p_poem_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  poem_author uuid;
  v_count bigint;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  select po.author_id
  into poem_author
  from public.poems as po
  where po.id = p_poem_id
    and po.status = 'approved'
    and po.is_hidden = false
    and po.deleted_at is null;

  if poem_author is null then
    raise exception 'poem not available'
      using errcode = 'P0002';
  end if;

  if poem_author = caller_id then
    raise exception 'cannot like own poem'
      using errcode = 'P0001';
  end if;

  insert into public.poem_likes (user_id, poem_id)
  values (caller_id, p_poem_id)
  on conflict (user_id, poem_id) do nothing;

  select count(*)::bigint
  into v_count
  from public.poem_likes as pl
  where pl.poem_id = p_poem_id;

  return json_build_object(
    'is_liked', true,
    'like_count', v_count
  );
end;
$$;

comment on function public.like_poem(uuid) is
  'Idempotent like for a public poem. Rejects self-likes. Returns is_liked and like_count.';

revoke all on function public.like_poem(uuid) from public;
revoke all on function public.like_poem(uuid) from anon;
grant execute on function public.like_poem(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) unlike_poem
-- -----------------------------------------------------------------------------

create or replace function public.unlike_poem(p_poem_id uuid)
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

  delete from public.poem_likes as pl
  where pl.user_id = caller_id
    and pl.poem_id = p_poem_id;

  select count(*)::bigint
  into v_count
  from public.poem_likes as pl
  where pl.poem_id = p_poem_id;

  return json_build_object(
    'is_liked', false,
    'like_count', v_count
  );
end;
$$;

comment on function public.unlike_poem(uuid) is
  'Idempotent unlike for the caller only. Returns is_liked=false and like_count.';

revoke all on function public.unlike_poem(uuid) from public;
revoke all on function public.unlike_poem(uuid) from anon;
grant execute on function public.unlike_poem(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7) bookmark_poem
-- -----------------------------------------------------------------------------

create or replace function public.bookmark_poem(p_poem_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if not public.is_public_poem(p_poem_id) then
    raise exception 'poem not available'
      using errcode = 'P0002';
  end if;

  insert into public.poem_bookmarks (user_id, poem_id)
  values (caller_id, p_poem_id)
  on conflict (user_id, poem_id) do nothing;

  return json_build_object('is_bookmarked', true);
end;
$$;

comment on function public.bookmark_poem(uuid) is
  'Idempotent private bookmark of a public poem. No bookmark count returned.';

revoke all on function public.bookmark_poem(uuid) from public;
revoke all on function public.bookmark_poem(uuid) from anon;
grant execute on function public.bookmark_poem(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 8) remove_poem_bookmark
-- -----------------------------------------------------------------------------

create or replace function public.remove_poem_bookmark(p_poem_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  delete from public.poem_bookmarks as pb
  where pb.user_id = caller_id
    and pb.poem_id = p_poem_id;

  return json_build_object('is_bookmarked', false);
end;
$$;

comment on function public.remove_poem_bookmark(uuid) is
  'Idempotent removal of the caller''s bookmark only.';

revoke all on function public.remove_poem_bookmark(uuid) from public;
revoke all on function public.remove_poem_bookmark(uuid) from anon;
grant execute on function public.remove_poem_bookmark(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 9) get_poem_engagement
-- -----------------------------------------------------------------------------

create or replace function public.get_poem_engagement(p_poem_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_count bigint;
  v_liked boolean := false;
  v_bookmarked boolean := false;
begin
  -- Public poems only in this phase.
  if not public.is_public_poem(p_poem_id) then
    raise exception 'poem not available'
      using errcode = 'P0002';
  end if;

  select count(*)::bigint
  into v_count
  from public.poem_likes as pl
  where pl.poem_id = p_poem_id;

  if caller_id is not null then
    select exists (
      select 1
      from public.poem_likes as pl
      where pl.user_id = caller_id
        and pl.poem_id = p_poem_id
    )
    into v_liked;

    select exists (
      select 1
      from public.poem_bookmarks as pb
      where pb.user_id = caller_id
        and pb.poem_id = p_poem_id
    )
    into v_bookmarked;
  end if;

  return json_build_object(
    'poem_id', p_poem_id,
    'like_count', v_count,
    'is_liked_by_current_user', v_liked,
    'is_bookmarked_by_current_user', v_bookmarked
  );
end;
$$;

comment on function public.get_poem_engagement(uuid) is
  'Public like_count plus current-user like/bookmark flags. No bookmark count or identities.';

revoke all on function public.get_poem_engagement(uuid) from public;
grant execute on function public.get_poem_engagement(uuid) to anon, authenticated;
