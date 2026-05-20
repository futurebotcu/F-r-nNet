-- FırınNet V1 Market M2 — controlled data fix.
--
-- Amaç: market_listings'in şehir/ilçe alanları artık serbest text değil,
-- canonical kod (TR plaka + kebab-case ilçe slug) ile filtrelenebilir
-- olsun. country_code ileride çok-ülke desteği için baseline.
--
-- city/district mevcut text alanları korunur (display label); arama ve
-- filtreleme yeni *_code alanlarından yapılır.
--
-- Apply öncesi: bu dosyanın içeriği kullanıcıya gösterilir, onay alındıktan
-- sonra mcp__supabase__apply_migration ile uygulanır. RLS policy değişikliği
-- YOK; mevcut SELECT/INSERT/UPDATE policy'leri yeni alanları kapsar.

-- ─── 1. country_code ────────────────────────────────────────────────
-- V1 sadece TR ilanlarını destekler; default 'TR' atanır. NOT NULL
-- çünkü filtreleme/raporlama için tek elden zorunlu.
alter table public.market_listings
  add column if not exists country_code text not null default 'TR';

-- ─── 2. city_code / district_code ───────────────────────────────────
-- Plaka kodu 2 hane string ('34'), ilçe kebab-case slug ('kadikoy').
-- Nullable: eski satırlarda boş kalabilir (data backfill V1.1'de).
alter table public.market_listings
  add column if not exists city_code text;

alter table public.market_listings
  add column if not exists district_code text;

-- ─── 3. Indexes ──────────────────────────────────────────────────────
-- Filter UX: il → ilçe arama; listing_type + il bazlı keşif.
create index if not exists market_listings_city_district_idx
  on public.market_listings (city_code, district_code)
  where is_deleted = false;

create index if not exists market_listings_type_city_idx
  on public.market_listings (listing_type, city_code)
  where is_deleted = false;

-- ─── 4. CHECK constraint — country_code whitelist (V1 sadece TR) ────
-- V2'de çoklu ülke açıldığında bu CHECK genişletilir.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'market_listings_country_code_check'
      and conrelid = 'public.market_listings'::regclass
  ) then
    alter table public.market_listings
      add constraint market_listings_country_code_check
      check (country_code in ('TR'));
  end if;
end$$;

-- ─── 5. Format CHECK (city_code 2 hane; district_code lower-kebab) ──
-- Defansif: client doğru gönderiyorsa zaten geçer; yanlış format DB'de
-- reddedilir. NULL'ı kabul eder.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'market_listings_city_code_format_check'
      and conrelid = 'public.market_listings'::regclass
  ) then
    alter table public.market_listings
      add constraint market_listings_city_code_format_check
      check (city_code is null or city_code ~ '^[0-9]{2}$');
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'market_listings_district_code_format_check'
      and conrelid = 'public.market_listings'::regclass
  ) then
    alter table public.market_listings
      add constraint market_listings_district_code_format_check
      check (district_code is null or district_code ~ '^[a-z0-9][a-z0-9-]*$');
  end if;
end$$;

-- ─── 6. Cross-field invariant: district_code ⇒ city_code ────────────
-- İlçe seçildiyse il de seçilmiş olmalı (UI tarafı zaten zorluyor;
-- DB seviyesinde de garanti edelim).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'market_listings_district_requires_city_check'
      and conrelid = 'public.market_listings'::regclass
  ) then
    alter table public.market_listings
      add constraint market_listings_district_requires_city_check
      check (district_code is null or city_code is not null);
  end if;
end$$;
