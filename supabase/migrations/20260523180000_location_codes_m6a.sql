-- =============================================================================
-- FırınNet Data Foundation M6A — Controlled location codes (profile + worker
-- + job_seek).
-- =============================================================================
-- Hedef: profil + worker + iş arama akışlarında şehir bilgisini ASCII plaka
-- kodu ile tut. UI label gösterir; DB code yazar.
--
-- Etki:
--   * profiles.city_code               text nullable (tek il)
--   * worker_profiles.city_codes       text[] nullable (çoklu il — worker
--                                       hangi illerde çalışmaya açık)
--   * worker_experiences.city_code     text nullable (geçmiş iş yeri ili)
--   * job_seek_posts.city_code         text nullable (ilan ili)
--   * 3 yeni regex CHECK constraint (plaka 01..81 formatı)
--   * Array CHECK: city_codes uzunluk cap 81 + null-safe
--   * Eski city / cities[] text kolonları KORUNUR (display fallback)
--   * public_profile_detail RPC city_code whitelist
--
-- Backfill YOK:
--   * Canlı row sayıları çok düşük; Türkçe label → plaka kodu eşlemesi 81
--     il × karakter varyasyonu için maliyetli ve eksik. UI hydrate'te
--     TurkeyLocations.findProvinceByName ile bir kez denenir; başarısızsa
--     kullanıcı edit ekranında yeniden seçer.
--
-- Geri dönüş:
--   alter table public.profiles            drop column city_code;
--   alter table public.worker_profiles     drop column city_codes;
--   alter table public.worker_experiences  drop column city_code;
--   alter table public.job_seek_posts      drop column city_code;
-- =============================================================================

-- ─── 1. Yeni nullable code kolonları ────────────────────────────────
alter table public.profiles
  add column if not exists city_code text;

alter table public.worker_profiles
  add column if not exists city_codes text[];

alter table public.worker_experiences
  add column if not exists city_code text;

alter table public.job_seek_posts
  add column if not exists city_code text;


-- ─── 2. CHECK constraints — plaka regex (01..81) ────────────────────
--
-- Plaka kodu 2 hane string: '01'..'81'. Regex (immutable):
--   ^(0[1-9]|[1-7][0-9]|8[01])$
-- TurkeyLocations.provinces ile birebir; ileride yeni il açılırsa
-- migration güncellenir (Türkiye'de değişim seyrek).

alter table public.profiles
  drop constraint if exists profiles_city_code_chk;
alter table public.profiles
  add constraint profiles_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');

alter table public.worker_experiences
  drop constraint if exists worker_experiences_city_code_chk;
alter table public.worker_experiences
  add constraint worker_experiences_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');

alter table public.job_seek_posts
  drop constraint if exists job_seek_posts_city_code_chk;
alter table public.job_seek_posts
  add constraint job_seek_posts_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');


-- ─── 3. worker_profiles.city_codes array CHECK ──────────────────────
--
-- Subquery CHECK'te yasak; per-element regex doğrulaması app-side
-- (TurkeyLocations.isValidProvinceCode). DB seviyesinde defansif:
--   * null veya boş array kabul
--   * en fazla 81 el (Türkiye il sayısı)
--   * null element yok

alter table public.worker_profiles
  drop constraint if exists worker_profiles_city_codes_chk;
alter table public.worker_profiles
  add constraint worker_profiles_city_codes_chk
  check (
    city_codes is null
    or (
      coalesce(array_length(city_codes, 1), 0) <= 81
      and array_position(city_codes, null) is null
    )
  );


-- ─── 4. public_profile_detail RPC — city_code whitelist'e ekle ──────
--
-- Profile bloğuna city_code, worker bloğuna city_codes eklenir. Eski
-- profile.city (text) + worker.cities (text[]) korunur (display fallback).

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
             cities, city_codes, skills, shift_preference, bio
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
