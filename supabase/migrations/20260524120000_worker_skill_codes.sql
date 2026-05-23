-- =============================================================================
-- FırınNet Data Foundation M7 — Controlled worker skill codes.
-- =============================================================================
-- Hedef: worker_profiles.skills[] comma-split free text yapısını kontrollü
-- skill taxonomy sistemine geçir. UI label gösterir; DB code yazar. Eski
-- skills[] label array korunur (display fallback).
--
-- Etki:
--   * worker_profiles.skill_codes text[] nullable (yeni)
--   * Array CHECK: null veya uzunluk ≤ 14 (taxonomy boyutu) + null
--     element yok. Per-element regex CHECK PostgreSQL'de subquery
--     yasak olduğu için app-side TurkeyLocations / FirinnetTaxonomy
--     validation yeterli.
--   * Eski skills[] (NOT NULL text[]) KORUNUR (display fallback).
--   * public_profile_detail RPC worker bloğuna skill_codes whitelist'e
--     ekleniyor.
--
-- Backfill YOK:
--   * Türkçe label varyasyonları (büyük/küçük + ç/ş/ğ/ı/ü/ö) tek bir CASE
--     map'le %100 doğru çevirmek zor.
--   * Mevcut row sayısı çok düşük (0 worker_profiles).
--   * Hydrate sırasında UI app-side dener; başarısızsa kullanıcı edit
--     ekranında yeniden seçer.
--
-- Geri dönüş:
--   alter table public.worker_profiles drop column skill_codes;
-- =============================================================================

-- ─── 1. Yeni nullable skill_codes kolonu ────────────────────────────
alter table public.worker_profiles
  add column if not exists skill_codes text[];


-- ─── 2. Array CHECK — uzunluk cap + null element yok ────────────────
alter table public.worker_profiles
  drop constraint if exists worker_profiles_skill_codes_chk;
alter table public.worker_profiles
  add constraint worker_profiles_skill_codes_chk
  check (
    skill_codes is null
    or (
      coalesce(array_length(skill_codes, 1), 0) <= 14
      and array_position(skill_codes, null) is null
    )
  );


-- ─── 3. public_profile_detail RPC — skill_codes whitelist'e ekle ────
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

  select to_jsonb(t) into v_profile
    from (
      select id, display_name, avatar_url, account_type,
             profession_badge, profession_badge_code,
             city, city_code
        from public.profiles
       where id = p_user_id
    ) t;

  if v_profile is null then
    return null;
  end if;

  select to_jsonb(t) into v_worker
    from (
      select profession_badge, profession_badge_code, experience_years,
             cities, city_codes, skills, skill_codes,
             shift_preference, bio
        from public.worker_profiles
       where owner_id = p_user_id
       limit 1
    ) t;

  select coalesce(
           jsonb_agg(to_jsonb(t) order by t.start_date desc nulls last),
           '[]'::jsonb
         )
    into v_experiences
    from (
      select id, title, city, city_code, start_date, end_date, description
        from public.worker_experiences
       where owner_id = p_user_id
       order by start_date desc nulls last
       limit 20
    ) t;

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
