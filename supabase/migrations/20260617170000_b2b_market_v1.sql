-- ============================================================
-- FırınNet — B2B Pazar V1 (Supabase backend)
-- Tarih: 2026-06-17
-- Amaç:
--   • B2B tedarik ağı veri modeli: mağaza vitrini + ürün + kampanya
--     + teklif talebi (ANONİM) + teklif cevabı.
--   • B2B mağaza profiles'ın KOPYASI DEĞİL: ayrı ticari vitrin
--     (owner_id → auth.users; tek vitrin = unique(owner_id)).
--   • Teklif Ağı ANONİM: b2b_quote_requests'te işletme adı/telefon/adres/
--     kişi adı KOLONU YOKTUR. buyer_id yalnız RLS/Tekliflerim için tutulur,
--     tedarikçiye ASLA açılmaz → tedarikçiler talepleri yalnız
--     b2b_open_quote_requests view'ından (buyer_id'siz) okur; tabloya
--     doğrudan SELECT yalnız talebin sahibinde.
--   • published=false (taslak) ürün/kampanyalar yalnız mağaza sahibine görünür.
-- Ek/additif: mevcut tablolara dokunulmaz, veri yazılmaz.
-- KAPSAM DIŞI: ödeme/paket/sepet/checkout/komisyon/chat/video YOK.
--   Görsel upload YOK (yalnız nullable *_url alanları; storage bucket bu
--   sprintte açılmaz).
-- ============================================================

-- updated_at otomatik tazeleme (B2B namespace; search_path sabit → advisor temiz)
create or replace function public.b2b_set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---- 1) b2b_supplier_shops (ayrı ticari vitrin) ----
create table if not exists public.b2b_supplier_shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  shop_name text not null,
  description text not null default '',
  city text,
  district text,
  service_regions text[] not null default '{}',
  categories text[] not null default '{}',
  logo_url text,
  cover_url text,
  is_active boolean not null default true,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id) -- tek vitrin / kullanıcı (myStore)
);
create index if not exists idx_b2b_shops_active on public.b2b_supplier_shops (is_active);

-- ---- 2) b2b_products (genel B2B ürün pazarı) ----
create table if not exists public.b2b_products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.b2b_supplier_shops(id) on delete cascade,
  name text not null,
  category text not null default '',
  min_order text not null default '',
  delivery_regions text[] not null default '{}',
  price_type text not null default 'quote',
  description text not null default '',
  image_url text,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_b2b_products_shop on public.b2b_products (shop_id);
create index if not exists idx_b2b_products_pub_cat on public.b2b_products (published, category);

-- ---- 3) b2b_campaigns (ticari fırsatlar) ----
create table if not exists public.b2b_campaigns (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.b2b_supplier_shops(id) on delete cascade,
  title text not null,
  category text not null default '',
  linked_product_id uuid references public.b2b_products(id) on delete set null,
  regions text[] not null default '{}',
  min_order text not null default '',
  valid_until date,
  description text not null default '',
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_b2b_campaigns_shop on public.b2b_campaigns (shop_id);
create index if not exists idx_b2b_campaigns_pub_cat on public.b2b_campaigns (published, category);

-- ---- 4) b2b_quote_requests (ANONİM — kimlik kolonu YOK) ----
create table if not exists public.b2b_quote_requests (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null default 'category'
    check (target_type in ('product','campaign','shop','category')),
  target_id uuid,
  category text not null default '',
  quantity text not null default '',
  city text,
  district text,
  buyer_type text not null default '',
  delivery_time text not null default '',
  note text not null default '',
  status text not null default 'open'
    check (status in ('open','replied','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
  -- KİMLİK ALANI YOK: işletme adı / telefon / açık adres / kişi adı kolonu
  -- bilinçli olarak eklenmez. buyer_id yalnız RLS içindir, view'da açılmaz.
);
create index if not exists idx_b2b_qr_buyer on public.b2b_quote_requests (buyer_id, created_at desc);
create index if not exists idx_b2b_qr_status on public.b2b_quote_requests (status, created_at desc);

-- ---- 5) b2b_quote_replies ----
create table if not exists public.b2b_quote_replies (
  id uuid primary key default gen_random_uuid(),
  quote_request_id uuid not null references public.b2b_quote_requests(id) on delete cascade,
  supplier_shop_id uuid not null references public.b2b_supplier_shops(id) on delete cascade,
  message text not null default '',
  price_note text,
  delivery_note text,
  status text not null default 'sent'
    check (status in ('sent','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_b2b_replies_request on public.b2b_quote_replies (quote_request_id);
create index if not exists idx_b2b_replies_shop on public.b2b_quote_replies (supplier_shop_id);

-- ---- updated_at triggerları ----
drop trigger if exists trg_b2b_shops_updated on public.b2b_supplier_shops;
create trigger trg_b2b_shops_updated before update on public.b2b_supplier_shops
  for each row execute function public.b2b_set_updated_at();
drop trigger if exists trg_b2b_products_updated on public.b2b_products;
create trigger trg_b2b_products_updated before update on public.b2b_products
  for each row execute function public.b2b_set_updated_at();
drop trigger if exists trg_b2b_campaigns_updated on public.b2b_campaigns;
create trigger trg_b2b_campaigns_updated before update on public.b2b_campaigns
  for each row execute function public.b2b_set_updated_at();
drop trigger if exists trg_b2b_qr_updated on public.b2b_quote_requests;
create trigger trg_b2b_qr_updated before update on public.b2b_quote_requests
  for each row execute function public.b2b_set_updated_at();
drop trigger if exists trg_b2b_replies_updated on public.b2b_quote_replies;
create trigger trg_b2b_replies_updated before update on public.b2b_quote_replies
  for each row execute function public.b2b_set_updated_at();

-- ============================================================
-- RLS
-- ============================================================
alter table public.b2b_supplier_shops enable row level security;
alter table public.b2b_products       enable row level security;
alter table public.b2b_campaigns      enable row level security;
alter table public.b2b_quote_requests enable row level security;
alter table public.b2b_quote_replies  enable row level security;

grant select, insert, update, delete on public.b2b_supplier_shops to authenticated;
grant select, insert, update, delete on public.b2b_products       to authenticated;
grant select, insert, update, delete on public.b2b_campaigns      to authenticated;
grant select, insert, update, delete on public.b2b_quote_requests to authenticated;
grant select, insert, update, delete on public.b2b_quote_replies  to authenticated;

-- shops: herkes aktif vitrini görür; sahip yönetir
drop policy if exists b2b_shops_select on public.b2b_supplier_shops;
create policy b2b_shops_select on public.b2b_supplier_shops
  for select to authenticated using (is_active = true or owner_id = auth.uid());
drop policy if exists b2b_shops_insert on public.b2b_supplier_shops;
create policy b2b_shops_insert on public.b2b_supplier_shops
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists b2b_shops_update on public.b2b_supplier_shops;
create policy b2b_shops_update on public.b2b_supplier_shops
  for update to authenticated using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- products: herkes yayında olanı görür; sahip taslak dahil kendi ürünlerini yönetir
drop policy if exists b2b_products_select on public.b2b_products;
create policy b2b_products_select on public.b2b_products
  for select to authenticated using (
    published = true
    or shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_products_insert on public.b2b_products;
create policy b2b_products_insert on public.b2b_products
  for insert to authenticated with check (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_products_update on public.b2b_products;
create policy b2b_products_update on public.b2b_products
  for update to authenticated using (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  ) with check (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_products_delete on public.b2b_products;
create policy b2b_products_delete on public.b2b_products
  for delete to authenticated using (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );

-- campaigns: products ile aynı desen
drop policy if exists b2b_campaigns_select on public.b2b_campaigns;
create policy b2b_campaigns_select on public.b2b_campaigns
  for select to authenticated using (
    published = true
    or shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_campaigns_insert on public.b2b_campaigns;
create policy b2b_campaigns_insert on public.b2b_campaigns
  for insert to authenticated with check (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_campaigns_update on public.b2b_campaigns;
create policy b2b_campaigns_update on public.b2b_campaigns
  for update to authenticated using (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  ) with check (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_campaigns_delete on public.b2b_campaigns;
create policy b2b_campaigns_delete on public.b2b_campaigns
  for delete to authenticated using (
    shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );

-- quote_requests: tabloya doğrudan SELECT YALNIZ talebin sahibinde (Tekliflerim).
-- Tedarikçi tabloyu doğrudan okuyamaz → buyer_id sızmaz.
drop policy if exists b2b_qr_select_own on public.b2b_quote_requests;
create policy b2b_qr_select_own on public.b2b_quote_requests
  for select to authenticated using (buyer_id = auth.uid());
drop policy if exists b2b_qr_insert_own on public.b2b_quote_requests;
create policy b2b_qr_insert_own on public.b2b_quote_requests
  for insert to authenticated with check (buyer_id = auth.uid());
drop policy if exists b2b_qr_update_own on public.b2b_quote_requests;
create policy b2b_qr_update_own on public.b2b_quote_requests
  for update to authenticated using (buyer_id = auth.uid())
  with check (buyer_id = auth.uid());

-- Teklif Ağı (anonim board): buyer_id'SİZ güvenli kolonlar. security_invoker=false
-- → view RLS'i bypass eder ve yalnız bu güvenli alt-kümeyi açar. Açık talepler
-- tüm authenticated kullanıcıya (tedarikçilere) görünür; alıcı kimliği ASLA gelmez.
drop view if exists public.b2b_open_quote_requests;
create view public.b2b_open_quote_requests
  with (security_invoker = false) as
  select id, target_type, target_id, category, quantity, city, district,
         buyer_type, delivery_time, note, status, created_at, updated_at
  from public.b2b_quote_requests
  where status <> 'closed';
grant select on public.b2b_open_quote_requests to authenticated;

-- quote_replies: cevaplayan (mağaza sahibi) kendi cevaplarını; talep sahibi
-- kendi talebine gelen cevapları görür/yönetir.
drop policy if exists b2b_replies_select on public.b2b_quote_replies;
create policy b2b_replies_select on public.b2b_quote_replies
  for select to authenticated using (
    supplier_shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
    or quote_request_id in (select id from public.b2b_quote_requests where buyer_id = auth.uid())
  );
drop policy if exists b2b_replies_insert on public.b2b_quote_replies;
create policy b2b_replies_insert on public.b2b_quote_replies
  for insert to authenticated with check (
    supplier_shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );
drop policy if exists b2b_replies_update on public.b2b_quote_replies;
create policy b2b_replies_update on public.b2b_quote_replies
  for update to authenticated using (
    supplier_shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  ) with check (
    supplier_shop_id in (select id from public.b2b_supplier_shops where owner_id = auth.uid())
  );

comment on table public.b2b_supplier_shops is
  'FırınNet B2B V1 — tedarikçi ticari vitrini (profiles kopyası DEĞİL). owner_id→auth.users, tek vitrin (unique owner_id). RLS: aktif herkese açık, sahip yönetir.';
comment on table public.b2b_quote_requests is
  'FırınNet B2B V1 — ANONİM teklif talebi. Kimlik kolonu YOK. Tabloya select yalnız buyer_id=auth.uid(); tedarikçi yalnız b2b_open_quote_requests view (buyer_id''siz) okur.';
