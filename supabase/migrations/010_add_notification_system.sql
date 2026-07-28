-- =============================================================================
-- 010_add_notification_system.sql
--
-- In-app notifications for follows, likes, and poem moderation.
-- Uses the existing public.notifications table (001). Does not recreate it.
--
-- Inserts happen only via SECURITY DEFINER triggers/helpers.
-- Clients keep SELECT own + UPDATE (is_read); no INSERT/DELETE for clients.
--
-- Does not implement push, email, Realtime, or bookmark notifications.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Indexes and type documentation
-- -----------------------------------------------------------------------------

-- Listing ordered by created_at, id for the current user.
create index if not exists notifications_user_created_id_idx
  on public.notifications (user_id, created_at desc, id desc);

comment on column public.notifications.type is
  'Allowed application values: new_follower, poem_liked, poem_approved, poem_rejected. '
  'Validated by insert_notification helper (not a hard CHECK, to tolerate legacy rows).';

-- -----------------------------------------------------------------------------
-- 2) Secure insert helper (trusted path only)
-- -----------------------------------------------------------------------------

create or replace function public.insert_notification(
  p_user_id uuid,
  p_actor_id uuid,
  p_poem_id uuid,
  p_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;

  if p_type not in (
    'new_follower',
    'poem_liked',
    'poem_approved',
    'poem_rejected'
  ) then
    raise exception 'invalid notification type: %', p_type
      using errcode = '22023';
  end if;

  -- Never notify a user about their own action.
  if p_actor_id is not null and p_actor_id = p_user_id then
    return;
  end if;

  insert into public.notifications (user_id, actor_id, poem_id, type, is_read)
  values (p_user_id, p_actor_id, p_poem_id, p_type, false);
end;
$$;

comment on function public.insert_notification(uuid, uuid, uuid, text) is
  'Internal helper for notification inserts. Not granted to anon/authenticated.';

revoke all on function public.insert_notification(uuid, uuid, uuid, text) from public;
revoke all on function public.insert_notification(uuid, uuid, uuid, text) from anon;
revoke all on function public.insert_notification(uuid, uuid, uuid, text) from authenticated;

-- -----------------------------------------------------------------------------
-- 3) new_follower — AFTER INSERT on follows
-- ON CONFLICT DO NOTHING does not fire this when the row already exists.
-- -----------------------------------------------------------------------------

create or replace function public.notify_on_new_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.insert_notification(
    new.followed_id,
    new.follower_id,
    null,
    'new_follower'
  );
  return new;
end;
$$;

drop trigger if exists follows_notify_new_follower on public.follows;
create trigger follows_notify_new_follower
  after insert on public.follows
  for each row
  execute function public.notify_on_new_follow();

comment on function public.notify_on_new_follow() is
  'Creates new_follower notification for the followed user after a real follow insert.';

revoke all on function public.notify_on_new_follow() from public;
revoke all on function public.notify_on_new_follow() from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4) poem_liked — AFTER INSERT on poem_likes
-- -----------------------------------------------------------------------------

create or replace function public.notify_on_poem_liked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
begin
  select po.author_id
  into v_author_id
  from public.poems as po
  where po.id = new.poem_id;

  if v_author_id is null then
    return new;
  end if;

  perform public.insert_notification(
    v_author_id,
    new.user_id,
    new.poem_id,
    'poem_liked'
  );
  return new;
end;
$$;

drop trigger if exists poem_likes_notify_liked on public.poem_likes;
create trigger poem_likes_notify_liked
  after insert on public.poem_likes
  for each row
  execute function public.notify_on_poem_liked();

comment on function public.notify_on_poem_liked() is
  'Creates poem_liked notification for the author after a real like insert.';

revoke all on function public.notify_on_poem_liked() from public;
revoke all on function public.notify_on_poem_liked() from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5) Moderation — pending → approved / rejected
-- Runs for privileged status changes (service_role / dashboard).
-- -----------------------------------------------------------------------------

create or replace function public.notify_on_poem_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if old.status = 'pending'::public.poem_status
     and new.status = 'approved'::public.poem_status then
    perform public.insert_notification(
      new.author_id,
      null,
      new.id,
      'poem_approved'
    );
  elsif old.status = 'pending'::public.poem_status
     and new.status = 'rejected'::public.poem_status then
    perform public.insert_notification(
      new.author_id,
      null,
      new.id,
      'poem_rejected'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists poems_notify_moderation on public.poems;
create trigger poems_notify_moderation
  after update of status on public.poems
  for each row
  execute function public.notify_on_poem_moderation();

comment on function public.notify_on_poem_moderation() is
  'Creates poem_approved / poem_rejected when status changes from pending. '
  'Does not fire for unrelated column updates. Preserves published_at automation '
  'in enforce_poem_update_guards (BEFORE UPDATE).';

revoke all on function public.notify_on_poem_moderation() from public;
revoke all on function public.notify_on_poem_moderation() from anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6) Client privileges — confirm no INSERT/DELETE for API roles
-- -----------------------------------------------------------------------------

revoke insert, delete on table public.notifications from public;
revoke insert, delete on table public.notifications from anon;
revoke insert, delete on table public.notifications from authenticated;

-- SELECT own + UPDATE (is_read) remain from 001.
grant select on table public.notifications to authenticated;
grant update (is_read) on table public.notifications to authenticated;

-- -----------------------------------------------------------------------------
-- 7) list_my_notifications
-- -----------------------------------------------------------------------------

create or replace function public.list_my_notifications(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  notification_id uuid,
  type text,
  is_read boolean,
  created_at timestamptz,
  actor_id uuid,
  actor_anonymous_name text,
  actor_avatar_url text,
  poem_id uuid,
  poem_title text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  v_limit integer;
  v_offset integer;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select
    n.id as notification_id,
    n.type,
    n.is_read,
    n.created_at,
    n.actor_id,
    actor.anonymous_name as actor_anonymous_name,
    actor.avatar_url as actor_avatar_url,
    n.poem_id,
    po.title as poem_title
  from public.notifications as n
  left join public.profiles as actor
    on actor.id = n.actor_id
  left join public.poems as po
    on po.id = n.poem_id
  where n.user_id = caller_id
  order by n.created_at desc, n.id desc
  limit v_limit
  offset v_offset;
end;
$$;

comment on function public.list_my_notifications(integer, integer) is
  'Paginated notifications for auth.uid() only. Joins actor and poem display fields.';

revoke all on function public.list_my_notifications(integer, integer) from public;
revoke all on function public.list_my_notifications(integer, integer) from anon;
grant execute on function public.list_my_notifications(integer, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 8) get_unread_notification_count
-- -----------------------------------------------------------------------------

create or replace function public.get_unread_notification_count()
returns bigint
language plpgsql
stable
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

  select count(*)::bigint
  into v_count
  from public.notifications as n
  where n.user_id = caller_id
    and n.is_read = false;

  return coalesce(v_count, 0);
end;
$$;

comment on function public.get_unread_notification_count() is
  'Unread notification count for auth.uid() only.';

revoke all on function public.get_unread_notification_count() from public;
revoke all on function public.get_unread_notification_count() from anon;
grant execute on function public.get_unread_notification_count() to authenticated;

-- -----------------------------------------------------------------------------
-- 9) mark_notification_read
-- -----------------------------------------------------------------------------

create or replace function public.mark_notification_read(p_notification_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  updated_count integer;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  update public.notifications as n
  set is_read = true
  where n.id = p_notification_id
    and n.user_id = caller_id
    and n.is_read = false;

  get diagnostics updated_count = row_count;

  -- Idempotent: already-read or missing-for-caller still returns is_read true
  -- only when the row exists and belongs to the caller.
  if exists (
    select 1
    from public.notifications as n
    where n.id = p_notification_id
      and n.user_id = caller_id
  ) then
    return json_build_object('is_read', true);
  end if;

  raise exception 'notification not available'
    using errcode = 'P0002';
end;
$$;

comment on function public.mark_notification_read(uuid) is
  'Marks one owned notification as read. Idempotent for already-read rows.';

revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_notification_read(uuid) from anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 10) mark_all_notifications_read
-- -----------------------------------------------------------------------------

create or replace function public.mark_all_notifications_read()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  updated_count integer;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  update public.notifications as n
  set is_read = true
  where n.user_id = caller_id
    and n.is_read = false;

  get diagnostics updated_count = row_count;

  return json_build_object('updated_count', updated_count);
end;
$$;

comment on function public.mark_all_notifications_read() is
  'Marks all unread notifications for auth.uid() as read. Returns updated_count.';

revoke all on function public.mark_all_notifications_read() from public;
revoke all on function public.mark_all_notifications_read() from anon;
grant execute on function public.mark_all_notifications_read() to authenticated;
