-- =============================================================================
-- 007_add_public_poem_search_rpc.sql
--
-- Public poem search for Lyrical (title, content, anonymous author name).
--
-- SECURITY INVOKER: RLS still applies. The WHERE clause also enforces
-- approved / visible / non-deleted so own pending/hidden rows never appear
-- even when poems_select_own would allow the caller to read them.
--
-- Matching uses case-insensitive substring via strpos(lower(...)), so % and _
-- in user input are literal characters (no ILIKE wildcards, no dynamic SQL).
--
-- Full-text search / trigram indexes may be introduced later when data volume
-- grows; this version intentionally keeps simple partial matching.
-- =============================================================================

-- Helpful for ORDER BY published_at desc, id desc under the public visibility
-- filter. Existing poems_published_at_idx / poems_visible_idx do not cover
-- (published_at, id) together for this partial predicate.
create index if not exists poems_public_published_id_idx
  on public.poems (published_at desc, id desc)
  where status = 'approved'
    and is_hidden = false
    and deleted_at is null;

comment on index public.poems_public_published_id_idx is
  'Public listing/search order by published_at, id. Not a full-text index.';

create or replace function public.search_public_poems(
  p_query text default null,
  p_poetry_type_id bigint default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  poem_id uuid,
  title text,
  content text,
  author_id uuid,
  author_anonymous_name text,
  author_avatar_url text,
  poetry_type_id bigint,
  poetry_type_name text,
  poetry_type_slug text,
  published_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_query text;
  v_limit integer;
  v_offset integer;
begin
  -- Trim; empty/whitespace-only becomes no text filter.
  v_query := nullif(btrim(coalesce(p_query, '')), '');

  -- Clamp pagination: limit 1..50 (default 20), offset >= 0.
  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select
    po.id as poem_id,
    po.title,
    po.content,
    po.author_id,
    pr.anonymous_name as author_anonymous_name,
    pr.avatar_url as author_avatar_url,
    po.poetry_type_id,
    pt.name as poetry_type_name,
    pt.slug as poetry_type_slug,
    po.published_at,
    po.created_at
  from public.poems as po
  inner join public.profiles as pr
    on pr.id = po.author_id
  inner join public.poetry_types as pt
    on pt.id = po.poetry_type_id
  where po.status = 'approved'
    and po.is_hidden = false
    and po.deleted_at is null
    and po.published_at is not null
    and (p_poetry_type_id is null or po.poetry_type_id = p_poetry_type_id)
    and (
      v_query is null
      or strpos(lower(po.title), lower(v_query)) > 0
      or strpos(lower(po.content), lower(v_query)) > 0
      or strpos(lower(pr.anonymous_name), lower(v_query)) > 0
    )
  order by po.published_at desc, po.id desc
  limit v_limit
  offset v_offset;
end;
$$;

comment on function public.search_public_poems(text, bigint, integer, integer) is
  'Searches publicly visible poems by title, content, or anonymous author name. '
  'Optional poetry_type_id filter. SECURITY INVOKER with explicit visibility '
  'filters. Simple case-insensitive partial match; full-text search may come later.';

revoke all on function public.search_public_poems(text, bigint, integer, integer)
  from public;
grant execute on function public.search_public_poems(text, bigint, integer, integer)
  to anon, authenticated;
