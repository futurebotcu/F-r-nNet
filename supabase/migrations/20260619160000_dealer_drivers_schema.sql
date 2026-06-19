-- Bayi Yönetimi — Şoförler özelliği · Sprint 1: ADDITIVE şema (yalnız tablo/kolon).
--
-- Prensip: "tek defter, çoklu görünüm". Mevcut Bayi Yönetimi davranışı DEĞİŞMEZ.
--   * owner_id TÜM dealer satırlarında patron/ticari kullanıcı kalır.
--   * dealer_transactions.driver_id NULLABLE → eski hareketler aynen çalışır;
--     bakiye/gün sonu/rapor hesapları (DealerBalanceService) ETKİLENMEZ.
--   * Bu sprintte ŞOFÖR ERİŞİMİ AÇILMAZ: yeni tablolar yalnız owner-only RLS;
--     şoföre özel SELECT/INSERT RLS ve yazma RPC'si Sprint 3-4'te gelir.
--   * Mevcut dealers / dealer_transactions / dealer_deliveries / dealer_prices /
--     dealer_notes politikalarına DOKUNULMAZ.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ===== 1) dealer_drivers — patron ↔ şoför bağı =====
create table if not exists public.dealer_drivers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  driver_user_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  phone text,
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, driver_user_id)
);
create index if not exists idx_dealer_drivers_owner on public.dealer_drivers(owner_id);

alter table public.dealer_drivers enable row level security;

drop policy if exists dealer_drivers_select_own on public.dealer_drivers;
create policy dealer_drivers_select_own on public.dealer_drivers
  for select to authenticated using (owner_id = auth.uid());
drop policy if exists dealer_drivers_insert_own on public.dealer_drivers;
create policy dealer_drivers_insert_own on public.dealer_drivers
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists dealer_drivers_update_own on public.dealer_drivers;
create policy dealer_drivers_update_own on public.dealer_drivers
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists dealer_drivers_delete_own on public.dealer_drivers;
create policy dealer_drivers_delete_own on public.dealer_drivers
  for delete to authenticated using (owner_id = auth.uid());

-- ===== 2) dealer_driver_assignments — şoföre atanan bayiler =====
create table if not exists public.dealer_driver_assignments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  driver_id uuid not null references public.dealer_drivers(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (driver_id, dealer_id)
);
create index if not exists idx_dealer_driver_assignments_owner on public.dealer_driver_assignments(owner_id);
create index if not exists idx_dealer_driver_assignments_dealer on public.dealer_driver_assignments(dealer_id);

alter table public.dealer_driver_assignments enable row level security;

drop policy if exists dealer_driver_assignments_select_own on public.dealer_driver_assignments;
create policy dealer_driver_assignments_select_own on public.dealer_driver_assignments
  for select to authenticated using (owner_id = auth.uid());
drop policy if exists dealer_driver_assignments_insert_own on public.dealer_driver_assignments;
create policy dealer_driver_assignments_insert_own on public.dealer_driver_assignments
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists dealer_driver_assignments_update_own on public.dealer_driver_assignments;
create policy dealer_driver_assignments_update_own on public.dealer_driver_assignments
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists dealer_driver_assignments_delete_own on public.dealer_driver_assignments;
create policy dealer_driver_assignments_delete_own on public.dealer_driver_assignments
  for delete to authenticated using (owner_id = auth.uid());

-- ===== 3) dealer_transactions.driver_id — NULLABLE, additive =====
-- Eski hareketler NULL kalır; hesaplar değişmez. on delete set null → şoför
-- kaydı silinse de hareket tarihçesi korunur.
alter table public.dealer_transactions
  add column if not exists driver_id uuid references public.dealer_drivers(id) on delete set null;

-- ===== 4) Tek-patron tutarlılık guard'ı (CHECK cross-table yapamaz → trigger) =====
-- assignment.owner_id == driver.owner_id == dealer.owner_id olmalı; biri başka
-- patrona aitse atama reddedilir. Sadece doğrulama; veri değiştirmez.
create or replace function public.dealer_assignment_owner_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_owner uuid;
  v_dealer_owner uuid;
begin
  select owner_id into v_driver_owner from public.dealer_drivers where id = new.driver_id;
  select owner_id into v_dealer_owner from public.dealers where id = new.dealer_id;
  if v_driver_owner is null or v_dealer_owner is null then
    raise exception 'dealer_driver_assignments: driver veya dealer bulunamadı';
  end if;
  if new.owner_id <> v_driver_owner or new.owner_id <> v_dealer_owner then
    raise exception 'dealer_driver_assignments: cross-owner atama yasak (owner=% driver_owner=% dealer_owner=%)',
      new.owner_id, v_driver_owner, v_dealer_owner;
  end if;
  return new;
end;
$$;
revoke execute on function public.dealer_assignment_owner_guard() from public, anon, authenticated;

drop trigger if exists trg_dealer_assignment_owner_guard on public.dealer_driver_assignments;
create trigger trg_dealer_assignment_owner_guard
  before insert or update on public.dealer_driver_assignments
  for each row execute function public.dealer_assignment_owner_guard();
