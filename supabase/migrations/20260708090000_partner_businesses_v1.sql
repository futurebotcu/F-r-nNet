-- Anlaşmalı İş Yerleri V1 (ADDITIVE; mevcut tablolara dokunmaz).
--
-- Ürün modeli:
--   * partner_businesses: FırınNet'in anlaştığı iş yerleri dizini. Yayınlama/
--     düzenleme V1'de ADMIN PANELSİZ — yalnız service role/backoffice yazar;
--     client hiçbir koşulda yazamaz. Kullanıcılar yalnız is_active=true
--     kayıtları görür.
--   * partner_business_applications: "Anlaşmalı iş yeri olmak istiyorum"
--     destek başvuruları. Yazma yalnız SECURITY DEFINER RPC ile —
--     requester_id CLIENT'TAN ALINMAZ, server-side auth.uid() set edilir.
--
-- Güvenlik (fail-closed):
--   * anon her iki tabloda tamamen dışarıda (grant yok).
--   * authenticated'a yalnız SELECT grant'ı (yazma grant'ı YOK — Supabase
--     default privileges kalıntısı da temizlenir; branch V2 hijyen emsali).
--   * Başvuru SELECT'i yalnız kendi satırı (enumeration yüzeyi yok).
--   * RPC'de saatlik rate limit: kullanıcı başına 5 başvuru.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. TABLOLAR
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.partner_businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 120),
  category text not null check (char_length(trim(category)) between 1 and 60),
  city text not null check (char_length(trim(city)) between 1 and 60),
  district text not null
    check (char_length(trim(district)) between 1 and 60),
  address text,
  phone text,
  email text,
  website_url text,
  map_url text,
  benefit_summary text,
  description text,
  logo_url text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.partner_businesses is
  'Anlaşmalı İş Yerleri V1 — yalnız backoffice/service role yazar; '
  'authenticated yalnız is_active=true satırları okur.';
create index if not exists idx_partner_businesses_active
  on public.partner_businesses(is_active, sort_order, name);

create table if not exists public.partner_business_applications (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references auth.users(id) on delete set null,
  business_name text not null
    check (char_length(trim(business_name)) between 1 and 120),
  contact_name text not null
    check (char_length(trim(contact_name)) between 1 and 120),
  phone text not null check (char_length(trim(phone)) between 5 and 30),
  email text,
  city text not null check (char_length(trim(city)) between 1 and 60),
  district text not null
    check (char_length(trim(district)) between 1 and 60),
  category text not null
    check (char_length(trim(category)) between 1 and 60),
  message text,
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'approved', 'rejected')),
  source text not null default 'support_form',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.partner_business_applications is
  'Anlaşmalı iş yeri başvuruları. INSERT yalnız RPC '
  '(create_partner_business_application — requester_id = auth.uid()); '
  'SELECT yalnız kendi satırı; durum yönetimi backoffice.';
create index if not exists idx_partner_applications_requester
  on public.partner_business_applications(requester_id, created_at desc);

-- updated_at dokunuşları (core schema'daki mevcut helper).
drop trigger if exists trg_partner_businesses_set_updated_at
  on public.partner_businesses;
create trigger trg_partner_businesses_set_updated_at
before update on public.partner_businesses
for each row execute function public.set_updated_at();

drop trigger if exists trg_partner_applications_set_updated_at
  on public.partner_business_applications;
create trigger trg_partner_applications_set_updated_at
before update on public.partner_business_applications
for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────────────────
-- 2. RLS + GRANTS
-- ────────────────────────────────────────────────────────────────────────

alter table public.partner_businesses enable row level security;
alter table public.partner_business_applications enable row level security;

-- partner_businesses: authenticated yalnız aktif kayıtları okur; yazma
-- policy YOK (backoffice/service role RLS'i zaten baypas eder).
drop policy if exists partner_businesses_select on public.partner_businesses;
create policy partner_businesses_select on public.partner_businesses
  for select to authenticated
  using (is_active = true);

-- partner_business_applications: yalnız kendi başvuruları; yazma policy YOK.
drop policy if exists partner_applications_select
  on public.partner_business_applications;
create policy partner_applications_select
  on public.partner_business_applications
  for select to authenticated
  using (requester_id = auth.uid());

-- Grant hijyeni: default privileges'ın verdiği geniş grant'lar asgariye
-- indirilir; anon tamamen dışarıda.
revoke all on public.partner_businesses from anon, public;
revoke all on public.partner_business_applications from anon, public;
revoke insert, update, delete, truncate, references, trigger
  on public.partner_businesses from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.partner_business_applications from authenticated;
grant select on public.partner_businesses to authenticated;
grant select on public.partner_business_applications to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 3. RPC — başvuru oluşturma (tek yazma yolu)
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.create_partner_business_application(
  p_business_name text,
  p_contact_name text,
  p_phone text,
  p_city text,
  p_district text,
  p_category text,
  p_email text default null,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_hourly int;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  -- Zorunlu alanlar server-side de doğrulanır (client validasyonu UX'tir).
  if trim(coalesce(p_business_name, '')) = ''
     or trim(coalesce(p_contact_name, '')) = ''
     or trim(coalesce(p_phone, '')) = ''
     or trim(coalesce(p_city, '')) = ''
     or trim(coalesce(p_district, '')) = ''
     or trim(coalesce(p_category, '')) = '' then
    raise exception 'missing required fields';
  end if;
  -- Rate limit: kullanıcı başına son 1 saatte en fazla 5 başvuru.
  select count(*) into v_hourly
  from public.partner_business_applications
  where requester_id = v_uid
    and created_at > now() - interval '1 hour';
  if v_hourly >= 5 then
    raise exception 'too many applications';
  end if;

  insert into public.partner_business_applications
    (requester_id, business_name, contact_name, phone, email, city,
     district, category, message)
  values
    (v_uid, trim(p_business_name), trim(p_contact_name), trim(p_phone),
     nullif(trim(coalesce(p_email, '')), ''), trim(p_city),
     trim(p_district), trim(p_category),
     nullif(trim(coalesce(p_message, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.create_partner_business_application(
  text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.create_partner_business_application(
  text, text, text, text, text, text, text, text) to authenticated;
