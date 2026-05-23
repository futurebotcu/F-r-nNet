-- FırınNet V1 Unified Profile M2 — public profile aggregate RPC.
--
-- Hedef: SocialProfilePage tek public profile görünümü için güvenli,
-- whitelisted alanlarla aggregate veri. Geniş "select to true" RLS
-- açma YOK; salary_expectation gibi hassas alanlar UI'ya hiç sızmaz.
--
-- Düzeltilen güvenlik açığı:
--   * worker_profiles SELECT policy şu an USING (true) — herhangi
--     authenticated user salary_expectation dahil tüm kolonları
--     okuyabilir. Owner-only'a daraltılıyor.
--   * worker_experiences aynı şekilde USING (true) — owner-only.
--   * Public görünüm artık `public_profile_detail(uuid)` RPC üzerinden
--     SECURITY DEFINER ile whitelisted columns döner.
--   * bakeries (owner-only kalır) RPC üzerinden minimal field açılır.
--   * recipe_calculations zaten `select_public is_public=true` var,
--     ek policy gerekmiyor; RPC opsiyonel.
--
-- Apply YOK: bu dosya gözden geçirme için. Kullanıcı onayı sonrası
-- mcp__supabase__apply_migration ile uygulanır.


-- ─── 1. RLS daraltma — worker_profiles + worker_experiences ──────────

drop policy if exists worker_profiles_select_auth on public.worker_profiles;
create policy worker_profiles_select_own
  on public.worker_profiles
  for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists worker_experiences_select_auth on public.worker_experiences;
create policy worker_experiences_select_own
  on public.worker_experiences
  for select
  to authenticated
  using (owner_id = auth.uid());

-- (bakeries, recipe_calculations zaten owner-only veya public flag'li.
--  Onlara dokunmuyoruz.)


-- ─── 2. public_profile_detail RPC — whitelisted aggregate ────────────
--
-- Dönen JSON shape (jsonb):
-- {
--   "profile":    { id, display_name, avatar_url, account_type,
--                   profession_badge, city },
--   "worker":     { profession_badge, experience_years, cities,
--                   skills, shift_preference, bio }  // veya null
--   "experiences":[ { id, title, city, start_date, end_date,
--                     description }, ... ],
--   "bakery":     { id, name, city, district, description }  // veya null
-- }
--
-- SALARY_EXPECTATION YOK. Email YOK. Account internal flag YOK.
-- Kullanıcı R2 direktifine birebir uyumlu.

create or replace function public.public_profile_detail(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile     jsonb;
  v_worker      jsonb;
  v_experiences jsonb;
  v_bakery      jsonb;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- core profile (whitelist; email/account_type YALNIZCA gerekli olanlar)
  select to_jsonb(t) into v_profile
    from (
      select id, display_name, avatar_url, account_type,
             profession_badge, city
        from public.profiles
       where id = p_user_id
    ) t;

  if v_profile is null then
    -- Profile yoksa null dön (404 davranışı UI'da yorumlanır).
    return null;
  end if;

  -- worker minimal (salary_expectation hariç!)
  select to_jsonb(t) into v_worker
    from (
      select profession_badge, experience_years, cities, skills,
             shift_preference, bio
        from public.worker_profiles
       where owner_id = p_user_id
       limit 1
    ) t;

  -- worker experiences (en yeni 20 — chronological desc)
  select coalesce(
           jsonb_agg(to_jsonb(t) order by t.start_date desc nulls last),
           '[]'::jsonb
         )
    into v_experiences
    from (
      select id, title, city, start_date, end_date, description
        from public.worker_experiences
       where owner_id = p_user_id
       order by start_date desc nulls last
       limit 20
    ) t;

  -- bakery snippet (minimal — name/city/district/description)
  select to_jsonb(t) into v_bakery
    from (
      select id, name, city, district, description
        from public.bakeries
       where owner_id = p_user_id
       order by created_at desc nulls last
       limit 1
    ) t;

  return jsonb_build_object(
    'profile',     v_profile,
    'worker',      v_worker,
    'experiences', v_experiences,
    'bakery',      v_bakery
  );
end;
$$;

revoke all on function public.public_profile_detail(uuid) from public;
grant execute on function public.public_profile_detail(uuid) to authenticated;
