-- Fırın Defteri V1 (ADDITIVE) — bakery panel'in günlük operasyon defterine
-- dönüşümü.
--
-- Kapsam:
--   1. bakery_day_books — günlük ciro + gün notu + kasa notu + gün kapatma
--      (owner+bakery+business_date başına TEK satır).
--   2. bakery_tasks — "Bugün ne yapacağım?" işleri.
--   3. waste_entries.waste_type CHECK genişletmesi — fire SEBEBİ artık
--      anlamlı seçenekler: yanık/fazla üretim/iade/bozulma/personel hatası/
--      diğer (eski 'waste'/'return'/'leftover' değerleri GEÇERLİ KALIR;
--      mevcut veri bozulmaz).
--
-- Güvenlik (fail-closed):
--   * Yeni tablolarda CLIENT YAZAMAZ (INSERT/UPDATE/DELETE policy YOK) —
--     tüm yazma SECURITY DEFINER RPC'lerle; owner_id + bakery_id SERVER-SIDE
--     auth.uid() üzerinden set edilir (client'tan bakery_id ALINMAZ →
--     yabancı bakery'ye kayıt imkânsız).
--   * SELECT yalnız kendi satırları; anon tamamen dışarıda.
--   * service_role'e açık grant (backoffice + öğrenilen ders: default
--     privileges bu projede service_role'e işlemiyor).
--   * Mevcut production/waste RLS'ine DOKUNULMAZ.
--
-- KAPSAM SINIRI: gider/borç (debt_expense_*), bayi finansı (dealer_*) ve
-- şube (branch_*) tablolarına dokunulmaz — Fırın Defteri yalnız günlük
-- fırın operasyonudur.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. TABLOLAR
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.bakery_day_books (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  bakery_id uuid not null references public.bakeries(id) on delete cascade,
  business_date date not null,
  -- Günlük ciro NOTU'dur; muhasebe/fatura/tahsilat kaydı DEĞİLDİR.
  revenue_amount numeric(12,2)
    check (revenue_amount is null or revenue_amount >= 0),
  cash_note text,
  day_note text,
  status text not null default 'open' check (status in ('open', 'closed')),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, bakery_id, business_date)
);
comment on table public.bakery_day_books is
  'Fırın Defteri V1 — gün başına ciro/not/kapanış. Yazma yalnız RPC '
  '(upsert_bakery_day_book / close_bakery_day / reopen_bakery_day).';
create index if not exists idx_bakery_day_books_owner_date
  on public.bakery_day_books(owner_id, business_date desc);

create table if not exists public.bakery_tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  bakery_id uuid not null references public.bakeries(id) on delete cascade,
  business_date date not null,
  title text not null check (char_length(trim(title)) between 1 and 120),
  category text,
  note text,
  is_done boolean not null default false,
  completed_at timestamptz,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.bakery_tasks is
  'Fırın Defteri V1 — "Bugün ne yapacağım?" işleri. Yazma yalnız RPC '
  '(create_/update_/delete_bakery_task).';
create index if not exists idx_bakery_tasks_owner_date
  on public.bakery_tasks(owner_id, business_date desc, sort_order);

-- updated_at dokunuşları (core schema'daki mevcut helper).
drop trigger if exists trg_bakery_day_books_set_updated_at
  on public.bakery_day_books;
create trigger trg_bakery_day_books_set_updated_at
before update on public.bakery_day_books
for each row execute function public.set_updated_at();

drop trigger if exists trg_bakery_tasks_set_updated_at on public.bakery_tasks;
create trigger trg_bakery_tasks_set_updated_at
before update on public.bakery_tasks
for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────────────────
-- 2. waste_entries.waste_type — fire sebebi genişletmesi (superset; eski
--    değerler geçerli kalır, veri değişmez)
-- ────────────────────────────────────────────────────────────────────────

alter table public.waste_entries
  drop constraint if exists waste_entries_waste_type_check;
alter table public.waste_entries
  add constraint waste_entries_waste_type_check
  check (waste_type in ('waste', 'return', 'leftover', 'burnt',
                        'overproduction', 'spoilage', 'staff_error',
                        'other'));

-- ────────────────────────────────────────────────────────────────────────
-- 3. RLS + GRANTS
-- ────────────────────────────────────────────────────────────────────────

alter table public.bakery_day_books enable row level security;
alter table public.bakery_tasks enable row level security;

drop policy if exists bakery_day_books_select_own on public.bakery_day_books;
create policy bakery_day_books_select_own on public.bakery_day_books
  for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists bakery_tasks_select_own on public.bakery_tasks;
create policy bakery_tasks_select_own on public.bakery_tasks
  for select to authenticated
  using (owner_id = auth.uid());

-- Grant hijyeni: default privileges asgariye iner; anon dışarıda;
-- service_role açık (backoffice/edge — grant_service_role_push_tables dersi).
revoke all on public.bakery_day_books from anon, public;
revoke all on public.bakery_tasks from anon, public;
revoke insert, update, delete, truncate, references, trigger
  on public.bakery_day_books from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.bakery_tasks from authenticated;
grant select on public.bakery_day_books to authenticated;
grant select on public.bakery_tasks to authenticated;
grant select, insert, update, delete
  on public.bakery_day_books to service_role;
grant select, insert, update, delete
  on public.bakery_tasks to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 4. RPC'LER (tüm yazma buradan; bakery server-side çözülür)
-- ────────────────────────────────────────────────────────────────────────

-- Çağıranın varsayılan fırınını bul/oluştur (client bakery_id GÖNDEREMEZ).
create or replace function public.ensure_my_bakery()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  select id into v_id from public.bakeries
    where owner_id = v_uid
    order by created_at
    limit 1;
  if v_id is null then
    insert into public.bakeries (owner_id, name)
    values (v_uid, 'Fırınım')
    returning id into v_id;
  end if;
  return v_id;
end;
$$;
revoke execute on function public.ensure_my_bakery()
  from public, anon, authenticated;

-- ── Günlük defter satırı upsert (ciro / gün notu / kasa notu) ──
-- NULL parametre = o alanı DEĞİŞTİRME. Kapalı günde güncelleme reddedilir
-- (önce reopen_bakery_day).
create or replace function public.upsert_bakery_day_book(
  p_business_date date,
  p_revenue_amount numeric default null,
  p_day_note text default null,
  p_cash_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bakery uuid;
  v_row record;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_business_date is null then
    raise exception 'business_date required';
  end if;
  if p_revenue_amount is not null and p_revenue_amount < 0 then
    raise exception 'invalid revenue';
  end if;
  v_bakery := public.ensure_my_bakery();
  select * into v_row from public.bakery_day_books
    where owner_id = v_uid and bakery_id = v_bakery
      and business_date = p_business_date;
  if v_row.id is null then
    insert into public.bakery_day_books
      (owner_id, bakery_id, business_date, revenue_amount, day_note,
       cash_note)
    values (v_uid, v_bakery, p_business_date, p_revenue_amount,
       nullif(trim(coalesce(p_day_note, '')), ''),
       nullif(trim(coalesce(p_cash_note, '')), ''))
    returning id into v_row;
    return v_row.id;
  end if;
  if v_row.status = 'closed' then
    raise exception 'day closed';
  end if;
  update public.bakery_day_books
    set revenue_amount = coalesce(p_revenue_amount, revenue_amount),
        day_note = coalesce(nullif(trim(coalesce(p_day_note, '')), ''),
                            day_note),
        cash_note = coalesce(nullif(trim(coalesce(p_cash_note, '')), ''),
                             cash_note),
        updated_at = now()
  where id = v_row.id;
  return v_row.id;
end;
$$;
revoke execute on function
  public.upsert_bakery_day_book(date, numeric, text, text)
  from public, anon;
grant execute on function
  public.upsert_bakery_day_book(date, numeric, text, text)
  to authenticated;

-- ── Günü kapat / yeniden aç ──
create or replace function public.close_bakery_day(p_business_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bakery uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_business_date is null then
    raise exception 'business_date required';
  end if;
  v_bakery := public.ensure_my_bakery();
  insert into public.bakery_day_books
    (owner_id, bakery_id, business_date, status, closed_at)
  values (v_uid, v_bakery, p_business_date, 'closed', now())
  on conflict (owner_id, bakery_id, business_date) do update
    set status = 'closed', closed_at = now(), updated_at = now();
end;
$$;
revoke execute on function public.close_bakery_day(date) from public, anon;
grant execute on function public.close_bakery_day(date) to authenticated;

create or replace function public.reopen_bakery_day(p_business_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bakery uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  v_bakery := public.ensure_my_bakery();
  update public.bakery_day_books
    set status = 'open', closed_at = null, updated_at = now()
  where owner_id = v_uid and bakery_id = v_bakery
    and business_date = p_business_date;
end;
$$;
revoke execute on function public.reopen_bakery_day(date) from public, anon;
grant execute on function public.reopen_bakery_day(date) to authenticated;

-- ── Görevler ──
create or replace function public.create_bakery_task(
  p_business_date date,
  p_title text,
  p_category text default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bakery uuid;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_business_date is null then
    raise exception 'business_date required';
  end if;
  if trim(coalesce(p_title, '')) = '' then
    raise exception 'title required';
  end if;
  v_bakery := public.ensure_my_bakery();
  insert into public.bakery_tasks
    (owner_id, bakery_id, business_date, title, category, note)
  values (v_uid, v_bakery, p_business_date, trim(p_title),
    nullif(trim(coalesce(p_category, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function
  public.create_bakery_task(date, text, text, text) from public, anon;
grant execute on function
  public.create_bakery_task(date, text, text, text) to authenticated;

create or replace function public.update_bakery_task(
  p_task_id uuid,
  p_is_done boolean default null,
  p_title text default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  select * into v_row from public.bakery_tasks
    where id = p_task_id and owner_id = v_uid;
  if v_row.id is null then
    raise exception 'task not found';
  end if;
  update public.bakery_tasks
    set is_done = coalesce(p_is_done, is_done),
        completed_at = case
          when p_is_done is true then now()
          when p_is_done is false then null
          else completed_at
        end,
        title = coalesce(nullif(trim(coalesce(p_title, '')), ''), title),
        note = coalesce(nullif(trim(coalesce(p_note, '')), ''), note),
        updated_at = now()
  where id = p_task_id;
end;
$$;
revoke execute on function
  public.update_bakery_task(uuid, boolean, text, text) from public, anon;
grant execute on function
  public.update_bakery_task(uuid, boolean, text, text) to authenticated;

create or replace function public.delete_bakery_task(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  delete from public.bakery_tasks
  where id = p_task_id and owner_id = v_uid;
end;
$$;
revoke execute on function public.delete_bakery_task(uuid) from public, anon;
grant execute on function public.delete_bakery_task(uuid) to authenticated;
