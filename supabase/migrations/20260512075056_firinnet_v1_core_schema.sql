-- Migration: firinnet_v1_core_schema
-- Version: 20260512075056
-- Source: applied to remote project sjeqwiqgwzagengdukye via MCP apply_migration on 2026-05-12
-- This file is a local mirror for source control. DO NOT re-apply to remote;
-- remote already records this version. Use only for fresh local stacks or replays.

-- FırınNet V1 Core Schema
-- Profiles, bakeries, products, recipes, production, dealers, deliveries, waste
-- Security model: RLS enabled on every table, owner-based via auth.uid()
-- No anon access, no public read, no service_role in policies.

create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- Shared trigger function: bump updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ============================================================
-- profiles
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  account_type text not null check (account_type in ('commercial','individual','wholesaler')),
  profession_badge text,
  city text,
  avatar_url text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy profiles_select_own
  on public.profiles for select to authenticated
  using (id = auth.uid());
create policy profiles_insert_self
  on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_delete_own
  on public.profiles for delete to authenticated
  using (id = auth.uid());

comment on table public.profiles is 'FırınNet V1 - kullanici profili. id = auth.users.id. RLS: yalniz kendisi.';

-- ============================================================
-- bakeries
-- ============================================================
create table public.bakeries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  city text,
  district text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_bakeries_owner_id on public.bakeries (owner_id);
create index idx_bakeries_city on public.bakeries (city);
create index idx_bakeries_is_active on public.bakeries (is_active);

create trigger trg_bakeries_set_updated_at
before update on public.bakeries
for each row execute function public.set_updated_at();

alter table public.bakeries enable row level security;

create policy bakeries_select_own on public.bakeries for select to authenticated
  using (owner_id = auth.uid());
create policy bakeries_insert_own on public.bakeries for insert to authenticated
  with check (owner_id = auth.uid());
create policy bakeries_update_own on public.bakeries for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy bakeries_delete_own on public.bakeries for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.bakeries is 'FırınNet V1 - firin isletme kaydi. RLS: owner_id = auth.uid()';

-- ============================================================
-- bakery_products
-- ============================================================
create table public.bakery_products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete cascade,
  name text not null,
  unit text not null default 'adet',
  default_price numeric(12,2) default 0 check (default_price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_bakery_products_owner_id on public.bakery_products (owner_id);
create index idx_bakery_products_bakery_id on public.bakery_products (bakery_id);
create index idx_bakery_products_is_active on public.bakery_products (is_active);

create trigger trg_bakery_products_set_updated_at
before update on public.bakery_products
for each row execute function public.set_updated_at();

alter table public.bakery_products enable row level security;

create policy bakery_products_select_own on public.bakery_products for select to authenticated
  using (owner_id = auth.uid());
create policy bakery_products_insert_own on public.bakery_products for insert to authenticated
  with check (owner_id = auth.uid());
create policy bakery_products_update_own on public.bakery_products for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy bakery_products_delete_own on public.bakery_products for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.bakery_products is 'FırınNet V1 - firin urun listesi. RLS: owner_id = auth.uid()';

-- ============================================================
-- recipe_calculations
-- ============================================================
create table public.recipe_calculations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  product_name text,
  flour_kg numeric(12,3) not null check (flour_kg > 0),
  water_percent numeric(8,3) not null check (water_percent >= 0),
  yeast_percent numeric(8,3) not null check (yeast_percent >= 0),
  salt_percent numeric(8,3) not null check (salt_percent >= 0),
  unit_weight_gr numeric(12,2) not null check (unit_weight_gr > 0),
  waste_percent numeric(8,3) not null default 0 check (waste_percent >= 0 and waste_percent <= 100),
  water_kg numeric(12,3),
  yeast_kg numeric(12,3),
  salt_kg numeric(12,3),
  total_dough_kg numeric(12,3),
  net_dough_kg numeric(12,3),
  estimated_count integer,
  created_at timestamptz not null default now()
);

create index idx_recipe_calculations_owner_id on public.recipe_calculations (owner_id);
create index idx_recipe_calculations_created_at on public.recipe_calculations (created_at desc);

create or replace function public.calculate_recipe_calculation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.water_kg := new.flour_kg * new.water_percent / 100.0;
  new.yeast_kg := new.flour_kg * new.yeast_percent / 100.0;
  new.salt_kg  := new.flour_kg * new.salt_percent  / 100.0;
  new.total_dough_kg := new.flour_kg + new.water_kg + new.yeast_kg + new.salt_kg;
  new.net_dough_kg := new.total_dough_kg * (1 - new.waste_percent / 100.0);
  if new.unit_weight_gr is null or new.unit_weight_gr = 0 then
    new.estimated_count := 0;
  else
    new.estimated_count := floor((new.net_dough_kg * 1000.0) / new.unit_weight_gr)::integer;
  end if;
  return new;
end;
$$;

create trigger trg_recipe_calculations_calculate
before insert or update on public.recipe_calculations
for each row execute function public.calculate_recipe_calculation();

alter table public.recipe_calculations enable row level security;

create policy recipe_calculations_select_own on public.recipe_calculations for select to authenticated
  using (owner_id = auth.uid());
create policy recipe_calculations_insert_own on public.recipe_calculations for insert to authenticated
  with check (owner_id = auth.uid());
create policy recipe_calculations_update_own on public.recipe_calculations for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy recipe_calculations_delete_own on public.recipe_calculations for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.recipe_calculations is 'FırınNet V1 - recete hesaplama. su/maya/tuz/toplam/net/adet trigger ile doldurulur. RLS: owner_id = auth.uid()';

-- ============================================================
-- production_entries
-- ============================================================
create table public.production_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete cascade,
  product_id uuid references public.bakery_products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity >= 0),
  production_date date not null default current_date,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_production_entries_owner_id on public.production_entries (owner_id);
create index idx_production_entries_bakery_id on public.production_entries (bakery_id);
create index idx_production_entries_production_date on public.production_entries (production_date desc);
create index idx_production_entries_product_id on public.production_entries (product_id);

create trigger trg_production_entries_set_updated_at
before update on public.production_entries
for each row execute function public.set_updated_at();

alter table public.production_entries enable row level security;

create policy production_entries_select_own on public.production_entries for select to authenticated
  using (owner_id = auth.uid());
create policy production_entries_insert_own on public.production_entries for insert to authenticated
  with check (owner_id = auth.uid());
create policy production_entries_update_own on public.production_entries for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy production_entries_delete_own on public.production_entries for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.production_entries is 'FırınNet V1 - gunluk uretim kaydi. RLS: owner_id = auth.uid()';

-- ============================================================
-- dealers
-- ============================================================
create table public.dealers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete cascade,
  name text not null,
  city text,
  district text,
  phone text,
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_dealers_owner_id on public.dealers (owner_id);
create index idx_dealers_bakery_id on public.dealers (bakery_id);
create index idx_dealers_is_active on public.dealers (is_active);
create index idx_dealers_name on public.dealers (name);

create trigger trg_dealers_set_updated_at
before update on public.dealers
for each row execute function public.set_updated_at();

alter table public.dealers enable row level security;

create policy dealers_select_own on public.dealers for select to authenticated
  using (owner_id = auth.uid());
create policy dealers_insert_own on public.dealers for insert to authenticated
  with check (owner_id = auth.uid());
create policy dealers_update_own on public.dealers for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealers_delete_own on public.dealers for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.dealers is 'FırınNet V1 - bayi/market/bakkal kaydi. RLS: owner_id = auth.uid()';

-- ============================================================
-- dealer_deliveries
-- ============================================================
create table public.dealer_deliveries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  delivery_date date not null default current_date,
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  returned_amount numeric(12,2) not null default 0 check (returned_amount >= 0),
  remaining_amount numeric(12,2) not null default 0,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_dealer_deliveries_owner_id on public.dealer_deliveries (owner_id);
create index idx_dealer_deliveries_bakery_id on public.dealer_deliveries (bakery_id);
create index idx_dealer_deliveries_dealer_id on public.dealer_deliveries (dealer_id);
create index idx_dealer_deliveries_delivery_date on public.dealer_deliveries (delivery_date desc);

create or replace function public.compute_dealer_delivery_remaining()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.remaining_amount := coalesce(new.total_amount,0)
                        - coalesce(new.returned_amount,0)
                        - coalesce(new.paid_amount,0);
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_dealer_deliveries_compute_remaining
before insert or update on public.dealer_deliveries
for each row execute function public.compute_dealer_delivery_remaining();

alter table public.dealer_deliveries enable row level security;

create policy dealer_deliveries_select_own on public.dealer_deliveries for select to authenticated
  using (owner_id = auth.uid());
create policy dealer_deliveries_insert_own on public.dealer_deliveries for insert to authenticated
  with check (owner_id = auth.uid());
create policy dealer_deliveries_update_own on public.dealer_deliveries for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealer_deliveries_delete_own on public.dealer_deliveries for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.dealer_deliveries is 'FırınNet V1 - bayi teslimat ust kaydi. total/returned itemlardan triggerla, remaining buradaki BEFORE triggerla hesaplanir.';

-- ============================================================
-- dealer_delivery_items
-- ============================================================
create table public.dealer_delivery_items (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.dealer_deliveries(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.bakery_products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity >= 0),
  unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
  returned_quantity integer not null default 0 check (returned_quantity >= 0),
  line_total numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  constraint chk_returned_le_quantity check (returned_quantity <= quantity)
);

create index idx_dealer_delivery_items_owner_id on public.dealer_delivery_items (owner_id);
create index idx_dealer_delivery_items_delivery_id on public.dealer_delivery_items (delivery_id);
create index idx_dealer_delivery_items_product_id on public.dealer_delivery_items (product_id);

create or replace function public.calculate_dealer_delivery_item()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_delivery_owner uuid;
begin
  -- Item owner_id parent delivery owner_id ile uyumlu olmali (cross-owner data injection engellenir)
  select owner_id into v_delivery_owner
  from public.dealer_deliveries
  where id = new.delivery_id;

  if v_delivery_owner is null then
    raise exception 'dealer_delivery_items: parent delivery not found (%)', new.delivery_id;
  end if;

  if v_delivery_owner <> new.owner_id then
    raise exception 'dealer_delivery_items: owner_id (%) must equal parent delivery owner_id (%)',
      new.owner_id, v_delivery_owner;
  end if;

  new.line_total := new.quantity * new.unit_price;
  return new;
end;
$$;

create trigger trg_dealer_delivery_items_calculate
before insert or update on public.dealer_delivery_items
for each row execute function public.calculate_dealer_delivery_item();

-- Item degisikliginden sonra parent totals yeniden hesaplanir.
create or replace function public.recalculate_dealer_delivery_totals(p_delivery_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(12,2);
  v_returned numeric(12,2);
begin
  select
    coalesce(sum(line_total), 0),
    coalesce(sum(returned_quantity * unit_price), 0)
  into v_total, v_returned
  from public.dealer_delivery_items
  where delivery_id = p_delivery_id;

  update public.dealer_deliveries
  set total_amount = v_total,
      returned_amount = v_returned
  where id = p_delivery_id;
end;
$$;

revoke all on function public.recalculate_dealer_delivery_totals(uuid) from public;
revoke all on function public.recalculate_dealer_delivery_totals(uuid) from anon;
revoke all on function public.recalculate_dealer_delivery_totals(uuid) from authenticated;

create or replace function public.trg_dealer_delivery_items_recalc()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recalculate_dealer_delivery_totals(old.delivery_id);
    return old;
  else
    perform public.recalculate_dealer_delivery_totals(new.delivery_id);
    if (tg_op = 'UPDATE' and old.delivery_id is distinct from new.delivery_id) then
      perform public.recalculate_dealer_delivery_totals(old.delivery_id);
    end if;
    return new;
  end if;
end;
$$;

create trigger trg_dealer_delivery_items_recalc_iud
after insert or update or delete on public.dealer_delivery_items
for each row execute function public.trg_dealer_delivery_items_recalc();

alter table public.dealer_delivery_items enable row level security;

create policy dealer_delivery_items_select_own on public.dealer_delivery_items for select to authenticated
  using (owner_id = auth.uid());
create policy dealer_delivery_items_insert_own on public.dealer_delivery_items for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.dealer_deliveries d
      where d.id = delivery_id and d.owner_id = auth.uid()
    )
  );
create policy dealer_delivery_items_update_own on public.dealer_delivery_items for update to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.dealer_deliveries d
      where d.id = delivery_id and d.owner_id = auth.uid()
    )
  );
create policy dealer_delivery_items_delete_own on public.dealer_delivery_items for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.dealer_delivery_items is 'FırınNet V1 - teslimat kalemleri. line_total trigger ile, parent totals AFTER triggerla guncellenir. owner cross-check triggerda.';

-- ============================================================
-- waste_entries
-- ============================================================
create table public.waste_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bakery_id uuid references public.bakeries(id) on delete cascade,
  product_id uuid references public.bakery_products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity >= 0),
  unit_cost numeric(12,2) not null default 0 check (unit_cost >= 0),
  estimated_loss numeric(12,2) not null default 0,
  waste_type text not null default 'waste' check (waste_type in ('waste','return','leftover')),
  waste_date date not null default current_date,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_waste_entries_owner_id on public.waste_entries (owner_id);
create index idx_waste_entries_bakery_id on public.waste_entries (bakery_id);
create index idx_waste_entries_waste_date on public.waste_entries (waste_date desc);
create index idx_waste_entries_waste_type on public.waste_entries (waste_type);

create or replace function public.calculate_waste_entry()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.estimated_loss := new.quantity * new.unit_cost;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_waste_entries_calculate
before insert or update on public.waste_entries
for each row execute function public.calculate_waste_entry();

alter table public.waste_entries enable row level security;

create policy waste_entries_select_own on public.waste_entries for select to authenticated
  using (owner_id = auth.uid());
create policy waste_entries_insert_own on public.waste_entries for insert to authenticated
  with check (owner_id = auth.uid());
create policy waste_entries_update_own on public.waste_entries for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy waste_entries_delete_own on public.waste_entries for delete to authenticated
  using (owner_id = auth.uid());

comment on table public.waste_entries is 'FırınNet V1 - fire/iade/kalan kaydi. estimated_loss = quantity*unit_cost trigger ile. RLS: owner_id = auth.uid()';
