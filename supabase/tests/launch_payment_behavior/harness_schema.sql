-- Launch payment behavior test harness (İZOLE lokal PostgreSQL için).
--
-- Supabase'e özgü parçaları taklit eder: auth şeması, auth.uid(), roller.
-- Ardından GERÇEK migration dosyaları uygulanır:
--   1) supabase/migrations/20260712120000_store_payments_foundation_v1.sql
--   2) supabase/migrations/20260923120000_launch_premium_and_listing_v1.sql
-- (runner PGOPTIONS='-c check_function_bodies=off' ile uygular; migration'lar
-- burada var olmayan modüllere -b2b vb.- yalnız fonksiyon gövdesinde değinir.)
--
-- ASLA production/paylaşılan bir veritabanına çalıştırmayın.

-- 1) Supabase rolleri (mock).
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
  -- Supabase'te service_role BYPASSRLS taşır; mock da aynı olmalı.
  alter role service_role bypassrls;
end
$$;

grant usage on schema public to anon, authenticated, service_role;

-- 2) auth şeması mock'u. auth.uid() GUC üzerinden test kullanıcısını okur.
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  created_at timestamptz not null default now()
);
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to public;

-- 3) Migration'ların DDL seviyesinde ihtiyaç duyduğu çekirdek tablolar.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  account_type text not null default 'individual'
);

-- user_entitlements: 20260711090000_commercial_entitlement_foundation_v1.sql
-- ile birebir aynı DDL + RLS + grant seti (davranış testleri bu kontrata
-- dayanır; tam migration zinciri 20260518'deki tarihî sözdizimi hatası
-- nedeniyle burada uygulanamıyor).
create table if not exists public.user_entitlements (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free'
    check (plan in ('free', 'pro', 'premium')),
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  current_period_started_at timestamptz,
  current_period_ends_at timestamptz,
  source text not null default 'manual'
    check (source in ('manual', 'backoffice', 'iap', 'system')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_user_entitlements_set_updated_at
  on public.user_entitlements;
create trigger trg_user_entitlements_set_updated_at
before update on public.user_entitlements
for each row execute function public.set_updated_at();

alter table public.user_entitlements enable row level security;
drop policy if exists user_entitlements_select_own on public.user_entitlements;
create policy user_entitlements_select_own on public.user_entitlements
  for select to authenticated
  using (owner_id = auth.uid());
revoke all on public.user_entitlements from anon, public;
revoke insert, update, delete, truncate, references, trigger
  on public.user_entitlements from authenticated;
grant select on public.user_entitlements to authenticated;
grant select, insert, update, delete
  on public.user_entitlements to service_role;

-- Launch migration'ın DDL seviyesinde dokunduğu ilan tabloları (stub; kolon
-- seti migration'ın trigger/policy/update ifadelerinin gerektirdiği kadar).
create table if not exists public.job_offer_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  is_active boolean not null default true,
  fee_required boolean not null default false,
  fee_amount_cents integer not null default 0,
  fee_currency text not null default 'TRY',
  fee_status text not null default 'waived',
  paid_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.market_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  status text not null default 'active',
  is_deleted boolean not null default false,
  fee_required boolean not null default false,
  fee_amount_cents integer not null default 0,
  fee_currency text not null default 'TRY',
  fee_status text not null default 'waived',
  paid_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.job_offer_posts enable row level security;
alter table public.market_listings enable row level security;

create table if not exists public.recipe_calculations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null
);

-- Migration fonksiyon gövdelerinin çağırdığı, bu test kapsamı dışındaki
-- modüllerin stub'ları.
create or replace function public.mark_listing_fee_paid(
  p_listing_id uuid,
  p_reference text
)
returns boolean
language sql
as $$ select true $$;

create or replace function public.can_add_b2b_product(p_owner_id uuid)
returns boolean language sql stable as $$ select true $$;
create or replace function public.can_add_b2b_campaign(p_owner_id uuid)
returns boolean language sql stable as $$ select true $$;
create or replace function public.can_reply_b2b_quote(p_owner_id uuid)
returns boolean language sql stable as $$ select true $$;

-- Bildirim tablosu aynası (canlı DDL'in davranış testleri için gereken
-- kolon seti; supplier launch hatırlatmaları buraya yazar).
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  route text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated using (recipient_id = auth.uid());
revoke all on public.notifications from anon, public;
revoke insert, update, delete, truncate, references, trigger
  on public.notifications from authenticated;
grant select on public.notifications to authenticated;
grant select, insert, update, delete on public.notifications to service_role;

-- 4) Test kullanıcıları.
insert into auth.users (id) values
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003'),
  ('00000000-0000-4000-8000-000000000004'),
  ('00000000-0000-4000-8000-000000000005'),
  ('00000000-0000-4000-8000-000000000006'),
  ('00000000-0000-4000-8000-000000000009'),
  ('00000000-0000-4000-8000-000000000010')
on conflict do nothing;

insert into public.profiles (id, account_type) values
  ('00000000-0000-4000-8000-000000000001', 'commercial'),
  ('00000000-0000-4000-8000-000000000002', 'commercial'),
  ('00000000-0000-4000-8000-000000000003', 'commercial'),
  ('00000000-0000-4000-8000-000000000004', 'commercial'),
  ('00000000-0000-4000-8000-000000000005', 'commercial'),
  ('00000000-0000-4000-8000-000000000006', 'commercial'),
  ('00000000-0000-4000-8000-000000000009', 'wholesaler'),
  ('00000000-0000-4000-8000-000000000010', 'individual')
on conflict do nothing;

-- 5) Eşzamanlılık testlerinin sonuç panosu.
create table if not exists public.test_results (
  label text not null,
  a text,
  b text,
  c text,
  recorded_at timestamptz not null default now()
);
grant select, insert on public.test_results to public;
