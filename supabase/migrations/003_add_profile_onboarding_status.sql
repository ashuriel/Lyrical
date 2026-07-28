-- =============================================================================
-- Lyrical — persist first-login onboarding completion on profiles
-- =============================================================================
-- Depends on 001_initial_schema.sql (already executed). Do not re-run 001/002.
-- Controls whether the welcome experience has been completed after first login.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1–2) Add has_completed_onboarding (default false for new and existing rows)
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column has_completed_onboarding boolean not null default false;

comment on column public.profiles.has_completed_onboarding is
  'True after the user finishes the first-login welcome experience. Persisted in the database so the welcome screen is not shown again on other devices.';

-- -----------------------------------------------------------------------------
-- 3–5) Column-level UPDATE grants for authenticated clients
-- RLS policy profiles_update_own is unchanged: users may still update only
-- their own row. Immutable columns remain blocked by column grants and by
-- enforce_profile_update_guards (id, anonymous_name, created_at).
-- updated_at continues to be maintained by the profiles_set_updated_at trigger.
-- -----------------------------------------------------------------------------

revoke update on table public.profiles from authenticated;

grant update (gender, bio, avatar_url, has_completed_onboarding)
  on table public.profiles to authenticated;

-- Intentional omissions preserved from 001:
-- no INSERT/DELETE policies or grants for anon/authenticated on profiles.
-- profiles_select_public and profiles_update_own remain as defined in 001.
