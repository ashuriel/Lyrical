-- =============================================================================
-- 011_add_admin_moderation.sql
--
-- Secure first-version administrator poem moderation.
-- Adds profiles.role + admin-only RPCs for listing, viewing, approving, and
-- rejecting pending poems. Does not auto-promote any user.
--
-- Relies on existing poems_enforce_update_guards for published_at and on
-- poems_notify_moderation for exactly one poem_approved / poem_rejected
-- notification per successful status transition.
--
-- Does not implement bans, reports, bulk moderation, or audit dashboards.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) profiles.role — default user; clients cannot UPDATE or SELECT it
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists role text not null default 'user';

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('user', 'admin'));

comment on column public.profiles.role is
  'Authorization role: user (default) or admin. Never exposed via public profile '
  'RPC or client column SELECT. Promote only via privileged SQL.';

-- Existing rows keep default 'user' via NOT NULL DEFAULT.
-- Future inserts from handle_new_user omit role → default 'user'.

-- Column privileges: clients may not read or write role.
revoke select on table public.profiles from anon, authenticated;
grant select (
  id,
  anonymous_name,
  gender,
  bio,
  avatar_url,
  created_at,
  updated_at,
  has_completed_onboarding
) on table public.profiles to anon, authenticated;

revoke update on table public.profiles from authenticated;
grant update (gender, bio, avatar_url, has_completed_onboarding)
  on table public.profiles to authenticated;

-- Harden immutability: clients cannot change role even if grants slip.
create or replace function public.enforce_profile_update_guards()
returns trigger
language plpgsql
as $$
declare
  is_privileged boolean;
begin
  if new.id is distinct from old.id then
    raise exception 'profiles.id is immutable';
  end if;

  if new.anonymous_name is distinct from old.anonymous_name then
    raise exception 'anonymous_name is immutable';
  end if;

  if new.created_at is distinct from old.created_at then
    raise exception 'profiles.created_at is immutable';
  end if;

  is_privileged :=
    coalesce(auth.role(), '') = 'service_role'
    or current_user in ('postgres', 'supabase_admin');

  if new.role is distinct from old.role and not is_privileged then
    raise exception 'profiles.role cannot be changed by this role';
  end if;

  if new.role is distinct from old.role
     and new.role is distinct from 'user'
     and new.role is distinct from 'admin' then
    raise exception 'profiles.role must be user or admin';
  end if;

  return new;
end;
$$;

comment on function public.enforce_profile_update_guards() is
  'Blocks client changes to id, anonymous_name, created_at, and role. '
  'Privileged roles may change role for manual admin promotion.';

-- -----------------------------------------------------------------------------
-- 2) Internal admin authorization helper (not granted to clients)
-- -----------------------------------------------------------------------------

create or replace function public.require_current_user_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_role text;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  select pr.role
    into v_role
  from public.profiles as pr
  where pr.id = caller_id;

  if v_role is distinct from 'admin' then
    raise exception 'administrator access required'
      using errcode = '42501';
  end if;

  return caller_id;
end;
$$;

comment on function public.require_current_user_admin() is
  'Internal helper: returns auth.uid() when the caller profile role is admin. '
  'Raises 42501 otherwise. Not granted to anon/authenticated.';

revoke all on function public.require_current_user_admin() from public;
revoke all on function public.require_current_user_admin() from anon;
revoke all on function public.require_current_user_admin() from authenticated;

-- -----------------------------------------------------------------------------
-- 3) is_current_user_admin — safe boolean for Flutter authorization UI
-- -----------------------------------------------------------------------------

create or replace function public.is_current_user_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_role text;
begin
  if caller_id is null then
    return false;
  end if;

  select pr.role
    into v_role
  from public.profiles as pr
  where pr.id = caller_id;

  return v_role is not distinct from 'admin';
end;
$$;

comment on function public.is_current_user_admin() is
  'Returns true only when auth.uid() has profiles.role = admin. '
  'Returns false when unauthenticated. Accepts no parameters.';

revoke all on function public.is_current_user_admin() from public;
revoke all on function public.is_current_user_admin() from anon;
grant execute on function public.is_current_user_admin() to authenticated;

-- -----------------------------------------------------------------------------
-- 4) get_pending_poems_for_moderation — admin list (oldest first)
-- -----------------------------------------------------------------------------

create or replace function public.get_pending_poems_for_moderation(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  poem_id uuid,
  title text,
  content text,
  poetry_type_id bigint,
  poetry_type_name text,
  author_id uuid,
  author_anonymous_name text,
  author_avatar_url text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_offset integer;
begin
  perform public.require_current_user_admin();

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select
    po.id as poem_id,
    po.title,
    po.content,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.created_at
  from public.poems as po
  join public.profiles as pr
    on pr.id = po.author_id
  join public.poetry_types as pt
    on pt.id = po.poetry_type_id
  where po.status = 'pending'::public.poem_status
    and po.deleted_at is null
  order by po.created_at asc, po.id asc
  limit v_limit
  offset v_offset;
end;
$$;

comment on function public.get_pending_poems_for_moderation(integer, integer) is
  'Admin-only pending poem queue. Oldest first. Never returns email or role.';

revoke all on function public.get_pending_poems_for_moderation(integer, integer)
  from public;
revoke all on function public.get_pending_poems_for_moderation(integer, integer)
  from anon;
grant execute on function public.get_pending_poems_for_moderation(integer, integer)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 5) get_pending_poem_for_moderation — admin detail
-- -----------------------------------------------------------------------------

create or replace function public.get_pending_poem_for_moderation(p_poem_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row record;
begin
  perform public.require_current_user_admin();

  if p_poem_id is null then
    raise exception 'poem not available for moderation'
      using errcode = 'P0002';
  end if;

  select
    po.id as poem_id,
    po.title,
    po.content,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.created_at
  into v_row
  from public.poems as po
  join public.profiles as pr
    on pr.id = po.author_id
  join public.poetry_types as pt
    on pt.id = po.poetry_type_id
  where po.id = p_poem_id
    and po.status = 'pending'::public.poem_status
    and po.deleted_at is null;

  if v_row.poem_id is null then
    raise exception 'poem not available for moderation'
      using errcode = 'P0002';
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
    'created_at', v_row.created_at
  );
end;
$$;

comment on function public.get_pending_poem_for_moderation(uuid) is
  'Admin-only pending poem detail. Raises P0002 when unavailable. No email.';

revoke all on function public.get_pending_poem_for_moderation(uuid) from public;
revoke all on function public.get_pending_poem_for_moderation(uuid) from anon;
grant execute on function public.get_pending_poem_for_moderation(uuid)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 6) approve_poem — admin only; concurrent-safe pending → approved
-- -----------------------------------------------------------------------------

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

  -- Conditional update: only one concurrent admin can win.
  update public.poems as po
  set status = 'approved'::public.poem_status
  where po.id = p_poem_id
    and po.status = 'pending'::public.poem_status
    and po.deleted_at is null
  returning po.id, po.status, po.published_at
  into v_poem_id, v_status, v_published_at;

  get diagnostics updated_count = row_count;

  if updated_count = 1 then
    -- published_at is stamped by poems_enforce_update_guards (privileged path).
    -- poem_approved notification is created by poems_notify_moderation.
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
  'Admin-only approve of a pending non-deleted poem. Concurrent updates race '
  'on status = pending. Relies on existing published_at + notification triggers.';

revoke all on function public.approve_poem(uuid) from public;
revoke all on function public.approve_poem(uuid) from anon;
grant execute on function public.approve_poem(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7) reject_poem — admin only; concurrent-safe pending → rejected
-- -----------------------------------------------------------------------------

create or replace function public.reject_poem(p_poem_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
  v_poem_id uuid;
  v_status public.poem_status;
begin
  perform public.require_current_user_admin();

  if p_poem_id is null then
    raise exception 'poem already reviewed or unavailable'
      using errcode = 'P0002';
  end if;

  update public.poems as po
  set status = 'rejected'::public.poem_status
  where po.id = p_poem_id
    and po.status = 'pending'::public.poem_status
    and po.deleted_at is null
  returning po.id, po.status
  into v_poem_id, v_status;

  get diagnostics updated_count = row_count;

  if updated_count = 1 then
    -- poem_rejected notification is created by poems_notify_moderation.
    return json_build_object(
      'poem_id', v_poem_id,
      'status', v_status::text,
      'success', true
    );
  end if;

  raise exception 'poem already reviewed or unavailable'
    using errcode = 'P0002';
end;
$$;

comment on function public.reject_poem(uuid) is
  'Admin-only reject of a pending non-deleted poem. Concurrent updates race '
  'on status = pending. Relies on existing notification trigger.';

revoke all on function public.reject_poem(uuid) from public;
revoke all on function public.reject_poem(uuid) from anon;
grant execute on function public.reject_poem(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Manual promotion (developer runs separately — not part of automatic apply):
--
--   update public.profiles
--   set role = 'admin'
--   where id = '<ADMIN_USER_UUID>';
--
-- Then optionally: notify pgrst, 'reload schema';
-- =============================================================================
