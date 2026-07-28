-- =============================================================================
-- 006_add_soft_delete_poem_rpc.sql
--
-- Soft deletion of poems cannot use a direct client UPDATE on deleted_at:
-- after deleted_at is set, SELECT policies hide the row and PostgREST/RLS
-- rejects the mutation ("new row violates row-level security policy").
--
-- Solution: SECURITY DEFINER RPC that authorizes via auth.uid(), sets
-- deleted_at server-side, and does not return the deleted row.
--
-- Clients lose direct UPDATE on deleted_at; they keep UPDATE on is_hidden
-- for hide/unhide. There is no restore RPC and no hard-delete RPC.
-- =============================================================================

create or replace function public.soft_delete_poem(p_poem_id uuid)
returns void
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

  -- Authorize exclusively with auth.uid(). Never trust a client author id.
  -- Works for pending, approved (visible or hidden), and rejected poems.
  update public.poems as p
  set deleted_at = now()
  where p.id = p_poem_id
    and p.author_id = caller_id
    and p.deleted_at is null;

  get diagnostics updated_count = row_count;

  if updated_count = 1 then
    return;
  end if;

  -- Own poem already soft-deleted (visible to definer; not to normal SELECT).
  if exists (
    select 1
    from public.poems as p
    where p.id = p_poem_id
      and p.author_id = caller_id
      and p.deleted_at is not null
  ) then
    raise exception 'poem already deleted'
      using errcode = 'P0001';
  end if;

  -- Missing poem or poem owned by someone else: do not leak which.
  raise exception 'poem not found or not authorized'
    using errcode = 'P0002';
end;
$$;

comment on function public.soft_delete_poem(uuid) is
  'Soft-deletes the caller''s poem by setting deleted_at = now(). '
  'SECURITY DEFINER avoids RLS visibility conflict after soft delete. '
  'Does not return the deleted row. No restore path.';

revoke all on function public.soft_delete_poem(uuid) from public;
revoke all on function public.soft_delete_poem(uuid) from anon;
grant execute on function public.soft_delete_poem(uuid) to authenticated;

-- Clients may still hide/unhide via direct UPDATE; soft delete goes through RPC.
revoke update on table public.poems from authenticated;
grant update (is_hidden) on table public.poems to authenticated;
