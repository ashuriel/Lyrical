-- =============================================================================
-- Lyrical — Storage RLS policies for the existing `avatars` bucket
-- =============================================================================
-- Depends on prior migrations. Do not recreate the bucket here.
-- Expected object path: <auth.uid()>/avatar.<extension>
-- Example: 550e8400-e29b-41d4-a716-446655440000/avatar.webp
-- Authorization always compares the first path segment to auth.uid()::text.
-- Never trust a client-supplied user id without that comparison.
--
-- NOTE: Running this in the Dashboard SQL Editor often fails with:
--   "must be owner of relation objects"
-- because storage.objects is owned by supabase_storage_admin.
-- Prefer one of:
--   1) Supabase CLI / linked project migrations
--   2) Storage → avatars → Policies (Dashboard UI)
--   3) Management API / MCP apply_migration (elevated)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Replace known policy names safely (no CASCADE; unexpected errors still raise)
-- -----------------------------------------------------------------------------

drop policy if exists "lyrical_avatars_public_select" on storage.objects;
drop policy if exists "lyrical_avatars_authenticated_insert_own_folder" on storage.objects;
drop policy if exists "lyrical_avatars_authenticated_update_own_folder" on storage.objects;
drop policy if exists "lyrical_avatars_authenticated_delete_own_folder" on storage.objects;

-- -----------------------------------------------------------------------------
-- 1) Public read: anyone may read objects in the avatars bucket only
-- -----------------------------------------------------------------------------

create policy "lyrical_avatars_public_select"
  on storage.objects
  for select
  to public
  using (
    bucket_id = 'avatars'
  );

-- -----------------------------------------------------------------------------
-- 2) Authenticated upload: insert only into the caller's UUID folder
-- storage.foldername(name)[1] must equal auth.uid()::text
-- -----------------------------------------------------------------------------

create policy "lyrical_avatars_authenticated_insert_own_folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- 3) Authenticated update: own folder only (USING + WITH CHECK)
-- Prevents moving/overwriting into another user's path
-- -----------------------------------------------------------------------------

create policy "lyrical_avatars_authenticated_update_own_folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- 4) Authenticated delete: own folder only
-- -----------------------------------------------------------------------------

create policy "lyrical_avatars_authenticated_delete_own_folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );