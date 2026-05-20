-- FırınNet — Market V1 Commit 1: market_listings expansion + media + saves.
--
-- Donor: bagisto opensource-ecommerce-mobile-app (MIT, see THIRD_PARTY_NOTICES)
-- Pattern alımı: listing card + image gallery + filter sheet + detail layout.
-- Bagisto cart/checkout/order/payment alınmaz. Tablo + RLS FırınNet'in
-- mevcut sıkı standardına uyar.
--
-- Mevcut durum (rows=0 olduğu için ALTER güvenli):
--   * market_listings.owner_id → profiles(id) on delete cascade
--   * Mevcut CHECK'ler: listing_type ('product','service','equipment'),
--     condition ('new','used','as_is'), category (8 değer V1 classified).
--   * is_active boolean — V1 sırasında kalır (V2 cleanup'ta status'a geçiş).
--
-- Kullanıcı kararı (Market V1 Commit 1):
--   * listing_type DARALTILIR: sadece ('equipment_sale','bakery_transfer').
--     'product'/'service'/'equipment' jenerik tipleri kaldırılır (rows=0).
--   * Default listing_type: 'equipment_sale'.
--   * status text + CHECK ('active','sold','paused') eklenir.
--   * is_deleted boolean + soft-delete RETURNING (sosyal sprint dersi).
--   * SELECT policy: ((status='active' AND is_deleted=false) OR
--     owner_id=auth.uid()) — owner self soft-deleted/paused/sold satırı
--     RETURNING için görür.
--   * condition CHECK: 'as_is' → 'refurbished' (rename, rows=0 güvenli).
--   * Ekipman + fırın devri özel alanları + currency + negotiable +
--     contact_phone/whatsapp + view_count.
--
-- Yeni tablolar:
--   * market_listing_media (owner_id → profiles(id) tutarlı)
--   * market_listing_saves (user_id → profiles(id))
--
-- Storage bucket: market-media (public; feed-media + story-media gibi).
-- Path: {owner_id}/{listing_id}/{media_id}.{ext}.

-- ─────────────────────────────────────── 1. market_listings: kolonlar
-- (status + is_deleted + classified marketplace özel alanları)
alter table public.market_listings
  add column if not exists status text not null default 'active',
  add column if not exists is_deleted boolean not null default false,
  add column if not exists equipment_category text,
  add column if not exists currency text not null default 'TRY',
  add column if not exists negotiable boolean not null default false,
  add column if not exists brand text,
  add column if not exists model text,
  add column if not exists year int,
  add column if not exists rent_price numeric,
  add column if not exists transfer_price numeric,
  add column if not exists equipment_included boolean,
  add column if not exists has_license boolean,
  add column if not exists area_m2 int,
  add column if not exists contact_phone text,
  add column if not exists contact_whatsapp text,
  add column if not exists view_count int not null default 0;

-- ─────────────────────────────────────── 2. market_listings: CHECK constraints
-- DROP + CREATE pattern (ALTER POLICY/CONSTRAINT kör replace yerine güvenli).

-- status enum-like CHECK
alter table public.market_listings
  drop constraint if exists market_listings_status_check;
alter table public.market_listings
  add constraint market_listings_status_check
    check (status in ('active', 'sold', 'paused'));

-- listing_type DARALTILIYOR: sadece ('equipment_sale','bakery_transfer').
-- rows=0, backward compat gerekmiyor (kullanıcı kararı: 'product' yok).
alter table public.market_listings
  drop constraint if exists market_listings_listing_type_check;
alter table public.market_listings
  alter column listing_type set default 'equipment_sale';
alter table public.market_listings
  add constraint market_listings_listing_type_check
    check (listing_type in ('equipment_sale', 'bakery_transfer'));

-- condition: 'as_is' → 'refurbished' rename (rows=0 güvenli).
alter table public.market_listings
  drop constraint if exists market_listings_condition_check;
alter table public.market_listings
  add constraint market_listings_condition_check
    check (condition is null or condition in ('new', 'used', 'refurbished'));

-- year sağlık kontrolü (1900–2100; insert hatalı yıl engellensin)
alter table public.market_listings
  drop constraint if exists market_listings_year_check;
alter table public.market_listings
  add constraint market_listings_year_check
    check (year is null or (year >= 1900 and year <= 2100));

-- rent_price / transfer_price / area_m2 non-negative
alter table public.market_listings
  drop constraint if exists market_listings_rent_price_check;
alter table public.market_listings
  add constraint market_listings_rent_price_check
    check (rent_price is null or rent_price >= 0);

alter table public.market_listings
  drop constraint if exists market_listings_transfer_price_check;
alter table public.market_listings
  add constraint market_listings_transfer_price_check
    check (transfer_price is null or transfer_price >= 0);

alter table public.market_listings
  drop constraint if exists market_listings_area_m2_check;
alter table public.market_listings
  add constraint market_listings_area_m2_check
    check (area_m2 is null or area_m2 > 0);

-- ─────────────────────────────────────── 3. market_listings: SELECT policy
-- Soft-delete RETURNING dersini uygula: owner kendi pasif/sold/soft-deleted
-- satırını UPDATE RETURNING için görsün. Client query yine
-- status='active' AND is_deleted=false ile filtre uygular.
drop policy if exists market_listings_select_active_or_own
  on public.market_listings;
create policy market_listings_select_active_or_own
  on public.market_listings
  for select
  using (
    (status = 'active' and is_deleted = false)
    or owner_id = auth.uid()
  );
-- INSERT / UPDATE / DELETE policy'leri (owner_id=auth.uid()) zaten doğru;
-- dokunmuyoruz.

-- ─────────────────────────────────────── 4. Indexler (read/listele/filter)
create index if not exists market_listings_status_deleted_created_idx
  on public.market_listings (status, is_deleted, created_at desc);

create index if not exists market_listings_type_city_idx
  on public.market_listings (listing_type, city);

create index if not exists market_listings_owner_created_idx
  on public.market_listings (owner_id, created_at desc);

-- ─────────────────────────────────────── 5. market_listing_media tablosu
-- owner_id → profiles(id) tutarlılık (market_listings.owner_id ile aynı target).
create table if not exists public.market_listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null
    references public.market_listings(id) on delete cascade,
  owner_id uuid not null
    references public.profiles(id) on delete cascade,
  storage_path text not null,
  sort_order int not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists market_listing_media_listing_idx
  on public.market_listing_media (listing_id, sort_order, created_at);

alter table public.market_listing_media enable row level security;

-- SELECT policy: media.is_deleted=false yetmez — parent listing aktif mi?
-- Sosyal sprint dersi: RETURNING için owner kendi soft-deleted'ı görsün.
-- Joining via EXISTS: listing aktif görünüyorsa media da görünür;
-- listing owner ise tüm media (sort/edit için).
drop policy if exists market_listing_media_select_visible
  on public.market_listing_media;
create policy market_listing_media_select_visible
  on public.market_listing_media
  for select
  using (
    -- owner her zaman görür (RETURNING + edit/sort)
    owner_id = auth.uid()
    or
    -- aksi halde: media silinmemiş + parent listing aktif/canlı
    (
      is_deleted = false
      and exists (
        select 1 from public.market_listings ml
        where ml.id = market_listing_media.listing_id
          and ml.status = 'active'
          and ml.is_deleted = false
      )
    )
  );

drop policy if exists market_listing_media_insert_own
  on public.market_listing_media;
create policy market_listing_media_insert_own
  on public.market_listing_media
  for insert
  with check (owner_id = auth.uid());

drop policy if exists market_listing_media_update_own
  on public.market_listing_media;
create policy market_listing_media_update_own
  on public.market_listing_media
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists market_listing_media_delete_own
  on public.market_listing_media;
create policy market_listing_media_delete_own
  on public.market_listing_media
  for delete
  using (owner_id = auth.uid());

-- ─────────────────────────────────────── 6. market_listing_saves tablosu
-- user_id → profiles(id) tutarlılık. Composite PK (listing_id, user_id)
-- idempotent ve unique save garantisi.
create table if not exists public.market_listing_saves (
  listing_id uuid not null
    references public.market_listings(id) on delete cascade,
  user_id uuid not null
    references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (listing_id, user_id)
);

alter table public.market_listing_saves enable row level security;

drop policy if exists market_listing_saves_select_own
  on public.market_listing_saves;
create policy market_listing_saves_select_own
  on public.market_listing_saves
  for select
  using (user_id = auth.uid());

drop policy if exists market_listing_saves_insert_own
  on public.market_listing_saves;
create policy market_listing_saves_insert_own
  on public.market_listing_saves
  for insert
  with check (user_id = auth.uid());

drop policy if exists market_listing_saves_delete_own
  on public.market_listing_saves;
create policy market_listing_saves_delete_own
  on public.market_listing_saves
  for delete
  using (user_id = auth.uid());

-- ─────────────────────────────────────── 7. Storage bucket: market-media
-- V1 public (feed-media + story-media gibi). Path: {owner_id}/{listing_id}/{media_id}.{ext}.
insert into storage.buckets (id, name, public)
  values ('market-media', 'market-media', true)
  on conflict (id) do nothing;

drop policy if exists market_media_select_authenticated on storage.objects;
create policy market_media_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'market-media');

drop policy if exists market_media_insert_owner_prefix on storage.objects;
create policy market_media_insert_owner_prefix
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'market-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists market_media_update_owner_prefix on storage.objects;
create policy market_media_update_owner_prefix
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'market-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'market-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists market_media_delete_owner_prefix on storage.objects;
create policy market_media_delete_owner_prefix
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'market-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────── 8. Tablo açıklamaları
comment on column public.market_listings.status is
  'V1 Market: active | sold | paused. UI ana akışı sadece active gösterir.';
comment on column public.market_listings.is_deleted is
  'Soft-delete. Client query is_deleted=false filtreler; RLS owner self görür.';
comment on column public.market_listings.listing_type is
  'V1 Market: equipment_sale (ekipman satışı) veya bakery_transfer '
  '(fırın/işletme devri). Mevcut ''product''/''service''/''equipment'' '
  'jenerik tipleri V1 darltıldı.';
comment on column public.market_listings.equipment_category is
  'Ekipman alt kategorisi (listing_type=equipment_sale için). Örnek: '
  'oven/mixer/dough_divider/proofing/refrigerator/display_counter/vehicle/other.';
comment on column public.market_listings.rent_price is
  'Fırın devri kiralık aylık fiyat (listing_type=bakery_transfer için).';
comment on column public.market_listings.transfer_price is
  'Fırın devri devir bedeli (listing_type=bakery_transfer için).';

comment on table public.market_listing_media is
  'V1 Market: ilan görselleri. RLS owner her zaman görür; diğerleri '
  'media.is_deleted=false AND parent listing active+not deleted.';
comment on table public.market_listing_saves is
  'V1 Market: kullanıcının kaydettiği ilanlar. Composite PK idempotent.';
