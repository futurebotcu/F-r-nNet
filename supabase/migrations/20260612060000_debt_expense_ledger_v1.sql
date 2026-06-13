-- ============================================================
-- FırınNet — Borç & Gider Defteri V1 (debt_expense_entries)
-- Tarih: 2026-06-12
-- Amaç:
--   • Ticari/fırın kullanıcı için basit borç/gider/personel ödeme takibi.
--   • Tek tablo, kind ile üç tür: debt | expense | staff_payment.
--   • total_amount / paid_amount tutulur; remaining ve status UYGULAMADA
--     türetilir (DB'de tutulmaz → drift yok). Ödeme = paid_amount artırımı.
--   • owner-only RLS (CRUD), anon erişim YOK. RLS gevşetme yok.
-- Bayi Defteri (dealer_transactions) pattern'i birebir izlenir
-- (owner_id → profiles, to authenticated, owner_id = auth.uid()).
-- Ek/additif: mevcut tablolara dokunulmaz, veri yazılmaz.
-- ============================================================

create table if not exists public.debt_expense_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  -- debt: fırının borcu | expense: gider | staff_payment: personel ödemesi
  kind text not null check (kind in ('debt','expense','staff_payment')),
  -- Kime/ne için (Uncu Mehmet, Kira, Ahmet…). Serbest metin.
  title text not null default '',
  -- Kategori (preset label veya "Diğer" → manuel metin). Serbest metin.
  category text,
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  due_date date,
  -- Yalnız staff_payment için: salary|advance|bonus|meal_transport|other
  staff_payment_type text
    check (staff_payment_type is null or staff_payment_type in
      ('salary','advance','bonus','meal_transport','other')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_debt_expense_owner_kind_created
  on public.debt_expense_entries (owner_id, kind, created_at desc);
create index if not exists idx_debt_expense_owner_due
  on public.debt_expense_entries (owner_id, due_date);

alter table public.debt_expense_entries enable row level security;

drop policy if exists debt_expense_select_own on public.debt_expense_entries;
drop policy if exists debt_expense_insert_own on public.debt_expense_entries;
drop policy if exists debt_expense_update_own on public.debt_expense_entries;
drop policy if exists debt_expense_delete_own on public.debt_expense_entries;
create policy debt_expense_select_own on public.debt_expense_entries
  for select to authenticated using (owner_id = auth.uid());
create policy debt_expense_insert_own on public.debt_expense_entries
  for insert to authenticated with check (owner_id = auth.uid());
create policy debt_expense_update_own on public.debt_expense_entries
  for update to authenticated using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
create policy debt_expense_delete_own on public.debt_expense_entries
  for delete to authenticated using (owner_id = auth.uid());

comment on table public.debt_expense_entries is
  'FırınNet V1 — Borç & Gider Defteri. kind=debt|expense|staff_payment. '
  'remaining/status uygulamada türetilir. owner-only RLS.';
