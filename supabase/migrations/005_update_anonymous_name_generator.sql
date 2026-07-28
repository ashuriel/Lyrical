-- =============================================================================
-- 005_update_anonymous_name_generator.sql
--
-- Anonymous poetic identity format (future registrations only):
--   <Noun> <Adjective>
--
-- Grammatical gender agreement:
--   Each noun carries gender ('m' | 'f').
--   Each adjective stores (masculine_form, feminine_form).
--   Gender-invariant adjectives store the same value in both forms
--   (e.g. Noble/Noble, Suave/Suave, Libre/Libre).
--   The generator always picks the adjective form that matches the noun.
--
-- EXISTING IDENTITIES ARE INTENTIONALLY PRESERVED.
-- This migration does NOT UPDATE public.profiles.anonymous_name.
-- Only profiles created after this migration use the new generator.
--
-- Concurrency:
--   handle_new_user retries on unique_violation of anonymous_name.
--   After ordinary collisions, fallback is:
--     <Noun> <Adjective> <ShortSuffix>
--   where ShortSuffix is a short uppercase fragment from gen_random_uuid().
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Generator: structured noun + gender-aware adjective
-- Never reads email, metadata, or profile personal fields.
-- ---------------------------------------------------------------------------
create or replace function public.generate_anonymous_name()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  -- nouns[i][1] = word, nouns[i][2] = grammatical gender ('m' | 'f')
  nouns text[][] := array[
    -- feminine (la …)
    array['Luna', 'f'],
    array['Aurora', 'f'],
    array['Brisa', 'f'],
    array['Estrella', 'f'],
    array['Nube', 'f'],
    array['Lluvia', 'f'],
    array['Hoja', 'f'],
    array['Flor', 'f'],
    array['Mariposa', 'f'],
    array['Golondrina', 'f'],
    array['Luciérnaga', 'f'],
    array['Montaña', 'f'],
    array['Pradera', 'f'],
    array['Cascada', 'f'],
    array['Semilla', 'f'],
    array['Gaviota', 'f'],
    array['Perla', 'f'],
    array['Ventana', 'f'],
    array['Pluma', 'f'],
    array['Sombra', 'f'],
    -- masculine (el …)
    array['Río', 'm'],
    array['Bosque', 'm'],
    array['Roble', 'm'],
    array['Gorrión', 'm'],
    array['Faro', 'm'],
    array['Cielo', 'm'],
    array['Viento', 'm'],
    array['Mar', 'm'],
    array['Lago', 'm'],
    array['Valle', 'm'],
    array['Jardín', 'm'],
    array['Lucero', 'm'],
    array['Sendero', 'm'],
    array['Sauce', 'm'],
    array['Colibrí', 'm'],
    array['Ciervo', 'm'],
    array['Delfín', 'm'],
    array['Cometa', 'm'],
    array['Cristal', 'm'],
    array['Horizonte', 'm']
  ];

  -- adjectives[i][1] = masculine form, adjectives[i][2] = feminine form
  -- Gender-invariant adjectives repeat the same string in both slots.
  adjectives text[][] := array[
    array['Sereno', 'Serena'],
    array['Claro', 'Clara'],
    array['Tranquilo', 'Tranquila'],
    array['Silencioso', 'Silenciosa'],
    array['Lejano', 'Lejana'],
    array['Dorado', 'Dorada'],
    array['Luminoso', 'Luminosa'],
    array['Tierno', 'Tierna'],
    array['Curioso', 'Curiosa'],
    array['Eterno', 'Eterna'],
    array['Paciente', 'Paciente'],
    array['Noble', 'Noble'],
    array['Suave', 'Suave'],
    array['Libre', 'Libre'],
    array['Gentil', 'Gentil'],
    array['Sutil', 'Sutil'],
    array['Brillante', 'Brillante'],
    array['Radiante', 'Radiante'],
    array['Alegre', 'Alegre'],
    array['Valiente', 'Valiente']
  ];

  noun_index integer;
  adjective_index integer;
  noun_word text;
  noun_gender text;
  adjective_word text;
begin
  noun_index := 1 + floor(random() * array_length(nouns, 1))::integer;
  adjective_index := 1 + floor(random() * array_length(adjectives, 1))::integer;

  noun_word := nouns[noun_index][1];
  noun_gender := nouns[noun_index][2];

  -- Select the adjective form that agrees with the noun gender.
  if noun_gender = 'm' then
    adjective_word := adjectives[adjective_index][1];
  else
    adjective_word := adjectives[adjective_index][2];
  end if;

  -- Required format: <Noun> <Adjective>
  return noun_word || ' ' || adjective_word;
end;
$$;

comment on function public.generate_anonymous_name() is
  'Returns Spanish <Noun> <Adjective> with grammatical gender agreement. '
  'Nouns carry gender; adjectives provide masculine and feminine forms '
  '(identical values for gender-invariant adjectives). '
  'Never reads email or user metadata. '
  'Does not rewrite existing profile anonymous_name values.';

revoke all on function public.generate_anonymous_name() from public;
revoke all on function public.generate_anonymous_name() from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Auth bootstrap: preserve one profile row per new auth.users insert.
-- Retry on anonymous_name unique_violation; UUID-suffix fallback after
-- ordinary collisions. Unrelated profile defaults (e.g. onboarding) unchanged.
-- ---------------------------------------------------------------------------
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
      -- Ordinary candidate: <Noun> <Adjective>
      new_name := public.generate_anonymous_name();
    else
      -- Finite combination space: after repeated collisions, append a short
      -- non-personal uppercase fragment from gen_random_uuid().
      -- Fallback format: <Noun> <Adjective> <ShortSuffix>
      -- Example: Luna Serena A7F2
      suffix := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4));
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
  'After auth.users insert, creates exactly one anonymous profile. '
  'Retries on concurrent anonymous_name collisions. '
  'After ordinary retries, uses <Noun> <Adjective> <ShortSuffix> fallback '
  'from gen_random_uuid(). Never derives names from email or metadata. '
  'Existing anonymous_name values are never rewritten by this function.';

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon, authenticated;

-- on_auth_user_created trigger is not recreated; it already points at
-- public.handle_new_user(). No UPDATE against existing public.profiles rows.
