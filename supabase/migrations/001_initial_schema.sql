-- =============================================================================
-- Lyrical — initial schema, anonymous identity, and Row Level Security
-- =============================================================================
-- This migration is intended for the Supabase SQL Editor or CLI.
-- It never embeds service_role credentials. Client authorization always uses
-- auth.uid(), never a client-supplied user id in isolation.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Extensions
-- -----------------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.poem_status as enum ('pending', 'approved', 'rejected');
create type public.feature_type as enum ('daily', 'monthly', 'editorial');

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  anonymous_name text not null,
  gender text,
  bio text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_anonymous_name_unique unique (anonymous_name),
  constraint profiles_anonymous_name_length
    check (char_length(anonymous_name) between 3 and 64),
  constraint profiles_bio_length
    check (bio is null or char_length(bio) <= 500),
  -- Store canonical English keys only; Flutter localizes display labels.
  constraint profiles_gender_allowed
    check (gender is null or gender in ('female', 'male'))
);

comment on table public.profiles is
  'Public anonymous profiles. Email lives only in auth.users and must never be selected here.';

create table public.poems (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  content text not null,
  status public.poem_status not null default 'pending',
  is_hidden boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint poems_title_length
    check (char_length(title) between 1 and 120),
  constraint poems_content_length
    check (char_length(content) between 1 and 10000)
);

comment on table public.poems is
  'Poems start as pending. Moderation status is separate from author hide/soft-delete.';

create table public.tags (
  id bigint generated always as identity primary key,
  name text not null,
  slug text not null,
  constraint tags_name_unique unique (name),
  constraint tags_slug_unique unique (slug),
  constraint tags_name_length check (char_length(name) between 1 and 40),
  constraint tags_slug_length check (char_length(slug) between 1 and 40)
);

create table public.poem_tags (
  poem_id uuid not null references public.poems (id) on delete cascade,
  tag_id bigint not null references public.tags (id) on delete cascade,
  primary key (poem_id, tag_id)
);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followed_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint follows_no_self_follow check (follower_id <> followed_id)
);

create table public.featured_poems (
  id uuid primary key default gen_random_uuid(),
  poem_id uuid not null references public.poems (id) on delete cascade,
  feature_type public.feature_type not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  constraint featured_poems_valid_date_range check (end_date >= start_date),
  constraint featured_poems_unique_window
    unique (poem_id, feature_type, start_date, end_date)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  poem_id uuid references public.poems (id) on delete set null,
  type text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_type_length check (char_length(type) between 1 and 64)
);

-- -----------------------------------------------------------------------------
-- Indexes
-- -----------------------------------------------------------------------------

create index poems_author_id_idx on public.poems (author_id);
create index poems_status_idx on public.poems (status);
create index poems_created_at_idx on public.poems (created_at desc);
create index poems_published_at_idx on public.poems (published_at desc nulls last);
create index poems_visible_idx
  on public.poems (created_at desc)
  where status = 'approved'
    and is_hidden = false
    and deleted_at is null;

-- unique(anonymous_name) already indexes lookups; keep an explicit comment index alias unused.
create index follows_follower_id_idx on public.follows (follower_id);
create index follows_followed_id_idx on public.follows (followed_id);
create index notifications_user_unread_idx
  on public.notifications (user_id, is_read, created_at desc);
create index poem_tags_tag_id_idx on public.poem_tags (tag_id);
create index featured_poems_active_idx
  on public.featured_poems (start_date, end_date, feature_type);

-- -----------------------------------------------------------------------------
-- updated_at helper
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

-- poems.updated_at is set inside enforce_poem_update_guards (single BEFORE UPDATE).

-- -----------------------------------------------------------------------------
-- Anonymous username generation
-- SECURITY: names are random Spanish adjective + noun only. Never use email
-- or user metadata. Uniqueness under concurrency is enforced in handle_new_user.
-- -----------------------------------------------------------------------------

create or replace function public.generate_anonymous_name()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Spanish-only, neutral/positive. Prefer epicene adjectives (Noble, Dulce,
  -- Libre, Suave, Brillante…) so pairings stay readable across noun genders.
  adjectives text[] := array[
    'Serena', 'Noble', 'Clara', 'Suave', 'Libre', 'Dulce', 'Brillante',
    'Gentil', 'Alegre', 'Lúcida', 'Pacífica', 'Valiente', 'Tranquila',
    'Radiante', 'Amable', 'Firme', 'Liviana', 'Celeste', 'Áurea', 'Sutil',
    'Pura', 'Viva', 'Armónica', 'Dorada', 'Plateada', 'Fresca', 'Abierta',
    'Cálida', 'Luminosa', 'Plácida', 'Nítida', 'Mansa', 'Apacible', 'Sosegada'
  ];
  nouns text[] := array[
    'Luna', 'Roble', 'Río', 'Nube', 'Aurora', 'Brisa', 'Piedra', 'Bosque',
    'Colibrí', 'Alba', 'Mar', 'Hoja', 'Cielo', 'Monte', 'Arena', 'Flor',
    'Arce', 'Niebla', 'Orilla', 'Sauce', 'Trigo', 'Coral', 'Cristal',
    'Olivo', 'Nieve', 'Rocío', 'Gorrión', 'Cedro', 'Prado', 'Marea',
    'Pétalo', 'Cumbre', 'Musgo', 'Ámbar', 'Almendro', 'Jazmín', 'Laurel',
    'Lucero'
  ];
  adjective text;
  noun text;
begin
  adjective := adjectives[1 + floor(random() * array_length(adjectives, 1))::integer];
  noun := nouns[1 + floor(random() * array_length(nouns, 1))::integer];
  return adjective || ' ' || noun;
end;
$$;

comment on function public.generate_anonymous_name() is
  'Returns a Spanish adjective + noun candidate. Never reads auth email. Uniqueness is enforced by handle_new_user retries.';

revoke all on function public.generate_anonymous_name() from public;
revoke all on function public.generate_anonymous_name() from anon, authenticated;

-- -----------------------------------------------------------------------------
-- Auth → profile bootstrap trigger
-- SECURITY DEFINER inserts the profile because clients have no INSERT policy.
-- Concurrent registrations may generate the same name; INSERT retries on
-- unique_violation for anonymous_name only.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_name text;
  attempt integer := 0;
  max_plain_attempts integer := 24;
  max_total_attempts integer := 40;
  suffix text;
  violated_constraint text;
begin
  -- Intentionally ignore new.email and raw_user_meta_data for naming.
  loop
    attempt := attempt + 1;

    if attempt <= max_plain_attempts then
      new_name := public.generate_anonymous_name();
    else
      -- UUID fallback after repeated ordinary collisions (still not email-based).
      suffix := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
      new_name := public.generate_anonymous_name() || ' ' || suffix;
    end if;

    begin
      insert into public.profiles (id, anonymous_name)
      values (new.id, new_name);
      return new;
    exception
      when unique_violation then
        get stacked diagnostics violated_constraint = constraint_name;

        -- Retry only anonymous_name races. Re-raise any other unique error.
        if violated_constraint is distinct from 'profiles_anonymous_name_unique' then
          raise;
        end if;

        if attempt >= max_total_attempts then
          raise exception
            'could not allocate a unique anonymous_name after % attempts',
            max_total_attempts;
        end if;
        -- Continue loop and try a new name.
    end;
  end loop;
end;
$$;

comment on function public.handle_new_user() is
  'After auth.users insert, creates an immutable anonymous profile. Retries on concurrent anonymous_name collisions.';

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Profile immutability for anonymous_name (and identity columns)
-- RLS alone cannot lock individual columns on UPDATE; this trigger does.
-- Column grants below further reduce PostgREST attack surface.
-- -----------------------------------------------------------------------------

create or replace function public.enforce_profile_update_guards()
returns trigger
language plpgsql
as $$
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

  return new;
end;
$$;

create trigger profiles_enforce_update_guards
  before update on public.profiles
  for each row
  execute function public.enforce_profile_update_guards();

-- -----------------------------------------------------------------------------
-- Poem column guards + published_at moderation automation
-- WHY NOT RLS-ONLY?
-- PostgreSQL RLS UPDATE policies are row-level. They cannot express
-- "allow update of is_hidden but forbid title/content/status" by themselves.
-- Secure approach used here (single BEFORE UPDATE trigger for determinism):
--   1) RLS: only the author may UPDATE their own non-deleted poem row.
--   2) This trigger: reject protected-column changes for clients; for
--      privileged roles, auto-set published_at on first approval.
--   3) Column privileges: authenticated may UPDATE only allowed columns.
-- Moderators / service_role bypass RLS and can change status via dashboard
-- or privileged backends (never the Flutter anon key).
-- -----------------------------------------------------------------------------

create or replace function public.enforce_poem_update_guards()
returns trigger
language plpgsql
as $$
declare
  is_privileged boolean;
begin
  -- Keep updated_at maintenance in this same trigger so poem BEFORE UPDATE
  -- order is deterministic (no second poems_set_updated_at trigger).
  new.updated_at := now();

  is_privileged :=
    coalesce(auth.role(), '') = 'service_role'
    or current_user in ('postgres', 'supabase_admin');

  -- Privileged moderation path.
  -- When status becomes approved for the first time, stamp published_at.
  -- Do not overwrite an existing published_at on later privileged updates.
  if is_privileged then
    if new.status = 'approved'
       and old.status is distinct from 'approved'::public.poem_status
       and new.published_at is null then
      new.published_at := now();
    end if;
    return new;
  end if;

  -- Authenticated client path: protected columns stay immutable.
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

  if new.created_at is distinct from old.created_at then
    raise exception 'poems.created_at is immutable';
  end if;

  -- Soft-delete is one-way for clients: clearing deleted_at is not allowed.
  if old.deleted_at is not null
     and new.deleted_at is distinct from old.deleted_at then
    raise exception 'soft-deleted poems cannot be restored by clients';
  end if;

  return new;
end;
$$;

comment on function public.enforce_poem_update_guards() is
  'Client guard for protected poem columns; privileged path sets published_at on first approval.';

create trigger poems_enforce_update_guards
  before update on public.poems
  for each row
  execute function public.enforce_poem_update_guards();

-- Force pending status and author ownership on INSERT even if the client tampers.
create or replace function public.enforce_poem_insert_guards()
returns trigger
language plpgsql
as $$
begin
  -- Privileged backends may insert freely; clients are constrained below.
  if coalesce(auth.role(), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if auth.uid() is null then
    raise exception 'authentication required to create poems';
  end if;

  if new.author_id is distinct from auth.uid() then
    raise exception 'author_id must equal auth.uid()';
  end if;

  new.status := 'pending';
  new.is_hidden := coalesce(new.is_hidden, false);
  new.published_at := null;
  new.deleted_at := null;

  return new;
end;
$$;

create trigger poems_enforce_insert_guards
  before insert on public.poems
  for each row
  execute function public.enforce_poem_insert_guards();

-- Limit each poem to at most three tags (product rule for every role).
create or replace function public.enforce_poem_tags_limit()
returns trigger
language plpgsql
as $$
declare
  tag_count integer;
begin
  -- Serialize tag inserts per poem so concurrent writers cannot exceed 3.
  perform 1
  from public.poems po
  where po.id = new.poem_id
  for update;

  select count(*)::integer
  into tag_count
  from public.poem_tags pt
  where pt.poem_id = new.poem_id;

  if tag_count >= 3 then
    raise exception 'a poem may have at most 3 tags';
  end if;

  return new;
end;
$$;

comment on function public.enforce_poem_tags_limit() is
  'Enforces a maximum of three tags per poem on INSERT. Duplicate tags remain blocked by the composite PK.';

create trigger poem_tags_enforce_limit
  before insert on public.poem_tags
  for each row
  execute function public.enforce_poem_tags_limit();

-- Notifications: clients may only flip is_read on their own rows.
create or replace function public.enforce_notification_update_guards()
returns trigger
language plpgsql
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.actor_id is distinct from old.actor_id
     or new.poem_id is distinct from old.poem_id
     or new.type is distinct from old.type
     or new.created_at is distinct from old.created_at
     or new.id is distinct from old.id then
    raise exception 'only is_read may be updated on notifications';
  end if;

  return new;
end;
$$;

create trigger notifications_enforce_update_guards
  before update on public.notifications
  for each row
  execute function public.enforce_notification_update_guards();

-- -----------------------------------------------------------------------------
-- Seed tags
-- -----------------------------------------------------------------------------

insert into public.tags (name, slug) values
  ('Amor', 'amor'),
  ('Naturaleza', 'naturaleza'),
  ('Melancolía', 'melancolia'),
  ('Esperanza', 'esperanza'),
  ('Vida', 'vida'),
  ('Muerte', 'muerte'),
  ('Sueños', 'suenos'),
  ('Soledad', 'soledad'),
  ('Fantasía', 'fantasia'),
  ('Reflexión', 'reflexion');

-- -----------------------------------------------------------------------------
-- Row Level Security
-- Avoid recursive policies: poem_tags/featured read poems by direct EXISTS
-- without policies that re-enter the same table through helpers calling back.
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.poems enable row level security;
alter table public.tags enable row level security;
alter table public.poem_tags enable row level security;
alter table public.follows enable row level security;
alter table public.featured_poems enable row level security;
alter table public.notifications enable row level security;

-- Force RLS even for table owners in the API path (service_role still bypasses).
alter table public.profiles force row level security;
alter table public.poems force row level security;
alter table public.tags force row level security;
alter table public.poem_tags force row level security;
alter table public.follows force row level security;
alter table public.featured_poems force row level security;
alter table public.notifications force row level security;

-- Profiles --------------------------------------------------------------
-- Public readable. No client INSERT/DELETE. UPDATE only own editable fields.

create policy "profiles_select_public"
  on public.profiles
  for select
  to anon, authenticated
  using (true);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Intentional omission: no INSERT/DELETE policies for anon/authenticated.
-- Profile rows are created only by handle_new_user (security definer).

-- Poems -----------------------------------------------------------------
create policy "poems_select_public_visible"
  on public.poems
  for select
  to anon, authenticated
  using (
    status = 'approved'
    and is_hidden = false
    and deleted_at is null
  );

create policy "poems_select_own"
  on public.poems
  for select
  to authenticated
  using (
    author_id = auth.uid()
    and deleted_at is null
  );

create policy "poems_insert_own_pending"
  on public.poems
  for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and status = 'pending'
  );

create policy "poems_update_own"
  on public.poems
  for update
  to authenticated
  using (
    author_id = auth.uid()
    and deleted_at is null
  )
  with check (
    author_id = auth.uid()
  );

-- No DELETE policy: soft-delete via deleted_at only.

-- Tags ------------------------------------------------------------------
create policy "tags_select_all"
  on public.tags
  for select
  to anon, authenticated
  using (true);

-- No INSERT/UPDATE/DELETE for normal clients.

-- Poem tags -------------------------------------------------------------
create policy "poem_tags_select_public_or_author"
  on public.poem_tags
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.poems po
      where po.id = poem_tags.poem_id
        and (
          (
            po.status = 'approved'
            and po.is_hidden = false
            and po.deleted_at is null
          )
          or (
            auth.uid() is not null
            and po.author_id = auth.uid()
            and po.deleted_at is null
          )
        )
    )
  );

create policy "poem_tags_insert_own_pending"
  on public.poem_tags
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.poems po
      where po.id = poem_tags.poem_id
        and po.author_id = auth.uid()
        and po.status = 'pending'
        and po.deleted_at is null
    )
  );

create policy "poem_tags_delete_own_pending"
  on public.poem_tags
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.poems po
      where po.id = poem_tags.poem_id
        and po.author_id = auth.uid()
        and po.status = 'pending'
        and po.deleted_at is null
    )
  );

-- Follows ---------------------------------------------------------------
create policy "follows_select_all"
  on public.follows
  for select
  to anon, authenticated
  using (true);

create policy "follows_insert_as_self"
  on public.follows
  for insert
  to authenticated
  with check (
    follower_id = auth.uid()
    and followed_id <> auth.uid()
  );

create policy "follows_delete_as_self"
  on public.follows
  for delete
  to authenticated
  using (follower_id = auth.uid());

-- Featured poems --------------------------------------------------------
-- Readable only while the feature window is active AND the related poem is
-- publicly visible. Direct EXISTS on poems avoids RLS recursion (poem policies
-- never query featured_poems).
create policy "featured_poems_select_active"
  on public.featured_poems
  for select
  to anon, authenticated
  using (
    start_date <= current_date
    and end_date >= current_date
    and exists (
      select 1
      from public.poems po
      where po.id = featured_poems.poem_id
        and po.status = 'approved'
        and po.is_hidden = false
        and po.deleted_at is null
    )
  );

-- No client writes: curated by privileged roles only.

-- Notifications ---------------------------------------------------------
-- Clients cannot INSERT. Future secure design: security definer RPCs /
-- database triggers owned by a privileged role create notification rows.
create policy "notifications_select_own"
  on public.notifications
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "notifications_update_own"
  on public.notifications
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Privileges (least privilege for API roles)
-- service_role bypasses RLS and is never shipped to the Flutter app.
-- -----------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;

grant select on table public.profiles to anon, authenticated;
grant update (gender, bio, avatar_url) on table public.profiles to authenticated;

grant select on table public.poems to anon, authenticated;
-- status defaults to pending; omit from INSERT grants so clients cannot set it.
grant insert (id, author_id, title, content, is_hidden) on table public.poems to authenticated;
grant update (is_hidden, deleted_at) on table public.poems to authenticated;

grant select on table public.tags to anon, authenticated;

grant select on table public.poem_tags to anon, authenticated;
grant insert, delete on table public.poem_tags to authenticated;

grant select on table public.follows to anon, authenticated;
grant insert, delete on table public.follows to authenticated;

grant select on table public.featured_poems to anon, authenticated;

grant select on table public.notifications to authenticated;
grant update (is_read) on table public.notifications to authenticated;

grant usage, select on all sequences in schema public to authenticated;
