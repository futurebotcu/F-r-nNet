-- ============================================================
-- FırınNet — Bayi V1.2 Schema Extensions
-- Tarih: 2026-05-13
-- Amaç:
--   • dealers tablosuna contact_name + working_type + customer_type sütunları
--   • dealer_transactions (payment/return/adjustment + delivery için ortak ledger)
--   • dealer_prices (bayi+ürün+geçerlilik fiyat tarihi)
--   • dealer_notes (çoklu not desteği)
--   • Üç tabloda da owner-only RLS (CRUD)
--   • customer_type ile ticari (bakery_dealer) ve toptancı (wholesale_customer)
--     ortak altyapıyı paylaşır.
-- RLS gevşetme yok; anon erişim eklenmedi.
-- ============================================================

-- ───────────────────────────── dealers extensions
alter table public.dealers
  add column if not exists contact_name text,
  add column if not exists working_type text
    check (working_type is null or working_type in ('cash','term','mixed')),
  add column if not exists customer_type text not null default 'bakery_dealer'
    check (customer_type in ('bakery_dealer','wholesale_customer'));

create index if not exists idx_dealers_owner_customer_type
  on public.dealers (owner_id, customer_type);

comment on column public.dealers.contact_name is 'Yetkili kişi adı (UI: contactName)';
comment on column public.dealers.working_type is 'cash | term | mixed (UI: Peşin/Vadeli/Karma)';
comment on column public.dealers.customer_type is 'bakery_dealer (ticari) | wholesale_customer (toptancı). Aynı tablo iki rolü paylaşır.';

-- ───────────────────────────── dealer_transactions
create table if not exists public.dealer_transactions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  type text not null check (type in ('delivery','payment','return','adjustment')),
  product_name text,
  quantity integer check (quantity is null or quantity >= 0),
  unit_price numeric(12,2) check (unit_price is null or unit_price >= 0),
  amount numeric(12,2) not null default 0,
  payment_method text check (payment_method is null or payment_method in ('cash','transfer','card','other')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dealer_transactions_dealer_created
  on public.dealer_transactions (dealer_id, created_at desc);
create index if not exists idx_dealer_transactions_owner_created
  on public.dealer_transactions (owner_id, created_at desc);

alter table public.dealer_transactions enable row level security;

drop policy if exists dealer_transactions_select_own on public.dealer_transactions;
drop policy if exists dealer_transactions_insert_own on public.dealer_transactions;
drop policy if exists dealer_transactions_update_own on public.dealer_transactions;
drop policy if exists dealer_transactions_delete_own on public.dealer_transactions;
create policy dealer_transactions_select_own on public.dealer_transactions
  for select to authenticated using (owner_id = auth.uid());
create policy dealer_transactions_insert_own on public.dealer_transactions
  for insert to authenticated with check (owner_id = auth.uid());
create policy dealer_transactions_update_own on public.dealer_transactions
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealer_transactions_delete_own on public.dealer_transactions
  for delete to authenticated using (owner_id = auth.uid());

comment on table public.dealer_transactions is
  'FırınNet V1.2 — bayi/müşteri için tek tip ledger (delivery/payment/return/adjustment). owner-only RLS.';

-- ───────────────────────────── dealer_prices
create table if not exists public.dealer_prices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  valid_from date not null default current_date,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dealer_prices_dealer_product_valid
  on public.dealer_prices (dealer_id, product_name, valid_from desc);

alter table public.dealer_prices enable row level security;

drop policy if exists dealer_prices_select_own on public.dealer_prices;
drop policy if exists dealer_prices_insert_own on public.dealer_prices;
drop policy if exists dealer_prices_update_own on public.dealer_prices;
drop policy if exists dealer_prices_delete_own on public.dealer_prices;
create policy dealer_prices_select_own on public.dealer_prices
  for select to authenticated using (owner_id = auth.uid());
create policy dealer_prices_insert_own on public.dealer_prices
  for insert to authenticated with check (owner_id = auth.uid());
create policy dealer_prices_update_own on public.dealer_prices
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealer_prices_delete_own on public.dealer_prices
  for delete to authenticated using (owner_id = auth.uid());

comment on table public.dealer_prices is
  'FırınNet V1.2 — bayi+ürün+valid_from fiyat geçmişi. owner-only RLS.';

-- ───────────────────────────── dealer_notes
create table if not exists public.dealer_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_dealer_notes_dealer_created
  on public.dealer_notes (dealer_id, created_at desc);

alter table public.dealer_notes enable row level security;

drop policy if exists dealer_notes_select_own on public.dealer_notes;
drop policy if exists dealer_notes_insert_own on public.dealer_notes;
drop policy if exists dealer_notes_update_own on public.dealer_notes;
drop policy if exists dealer_notes_delete_own on public.dealer_notes;
create policy dealer_notes_select_own on public.dealer_notes
  for select to authenticated using (owner_id = auth.uid());
create policy dealer_notes_insert_own on public.dealer_notes
  for insert to authenticated with check (owner_id = auth.uid());
create policy dealer_notes_update_own on public.dealer_notes
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealer_notes_delete_own on public.dealer_notes
  for delete to authenticated using (owner_id = auth.uid());

comment on table public.dealer_notes is
  'FırınNet V1.2 — bayi başına çoklu not. owner-only RLS.';
