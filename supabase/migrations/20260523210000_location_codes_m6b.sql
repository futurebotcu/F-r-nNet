-- =============================================================================
-- FırınNet Data Foundation M6B — Controlled location codes (dealer +
-- job_offer + bakery).
-- =============================================================================
-- Hedef: M6A'da profile/worker/job_seek tarafına eklenen plaka kodu pattern'i
-- şimdi dealer, job_offer_posts ve bakeries tablolarına uygulanır.
-- Marketplace ile birlikte tüm "konum" tüketicileri code-tabanlı olur.
--
-- Etki:
--   * dealers.city_code              text nullable + regex CHECK (01..81)
--   * dealers.district_code          text nullable + slug CHECK + city zorunlu
--   * job_offer_posts.city_code      text nullable + regex CHECK
--   * job_offer_posts.district_code  text nullable + slug CHECK + city zorunlu
--   * bakeries.city_code             text nullable + regex CHECK
--   * bakeries.district_code         text nullable + slug CHECK + city zorunlu
--   * Eski city / district text kolonları KORUNUR (display fallback)
--
-- district_code:
--   * Format: ASCII slug, lower-case, harf/rakam/tire; 1..40 karakter.
--   * Liste her ilin district set'inden geldiği için per-province CHECK
--     pratik değil; format CHECK + app-side TurkeyLocations validation
--     yeterli.
--   * Zorunlu: district_code varsa city_code da olmalı (orphan engel).
--
-- Backfill YOK:
--   * Mevcut row sayıları düşük (dealer 0 satır; job_offer 0; bakery küçük).
--   * Eski text'i kullanan tüketiciler aynı şekilde çalışır.
--   * UI hydrate'te TurkeyLocations.findProvinceByName / findDistrict ile
--     bir kez denenir; başarısızsa kullanıcı edit ekranında yeniden seçer.
--
-- Geri dönüş:
--   alter table public.dealers          drop column district_code;
--   alter table public.dealers          drop column city_code;
--   alter table public.job_offer_posts  drop column district_code;
--   alter table public.job_offer_posts  drop column city_code;
--   alter table public.bakeries         drop column district_code;
--   alter table public.bakeries         drop column city_code;
-- =============================================================================

-- ─── 1. Yeni nullable code kolonları ────────────────────────────────
alter table public.dealers
  add column if not exists city_code text,
  add column if not exists district_code text;

alter table public.job_offer_posts
  add column if not exists city_code text,
  add column if not exists district_code text;

alter table public.bakeries
  add column if not exists city_code text,
  add column if not exists district_code text;


-- ─── 2. Regex CHECK constraint'ler (plaka 01..81) ───────────────────
alter table public.dealers
  drop constraint if exists dealers_city_code_chk;
alter table public.dealers
  add constraint dealers_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');

alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_city_code_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');

alter table public.bakeries
  drop constraint if exists bakeries_city_code_chk;
alter table public.bakeries
  add constraint bakeries_city_code_chk
  check (city_code is null or city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$');


-- ─── 3. district_code format + parent-city zorunlu CHECK ────────────
--
-- Format: ASCII slug, lower-case + rakam + tire; 1..40 karakter.
--   pattern: ^[a-z0-9]+(-[a-z0-9]+)*$
-- Plus: district_code varsa city_code zorunlu (orphan engel).

alter table public.dealers
  drop constraint if exists dealers_district_code_chk;
alter table public.dealers
  add constraint dealers_district_code_chk
  check (
    district_code is null
    or (
      city_code is not null
      and district_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
      and length(district_code) <= 40
    )
  );

alter table public.job_offer_posts
  drop constraint if exists job_offer_posts_district_code_chk;
alter table public.job_offer_posts
  add constraint job_offer_posts_district_code_chk
  check (
    district_code is null
    or (
      city_code is not null
      and district_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
      and length(district_code) <= 40
    )
  );

alter table public.bakeries
  drop constraint if exists bakeries_district_code_chk;
alter table public.bakeries
  add constraint bakeries_district_code_chk
  check (
    district_code is null
    or (
      city_code is not null
      and district_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
      and length(district_code) <= 40
    )
  );

-- Not: public_profile_detail RPC bakery bloğunda city/district zaten
-- döndürülüyor (M2'den). bakeries.city_code/district_code public profile'da
-- gerekli olduğunda ayrı sprintte (M6C bakery setup UI) RPC whitelist'e
-- eklenecek.
