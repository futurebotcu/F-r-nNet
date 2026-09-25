-- PRODUCTION ŞEMA REPLİKASI (2026-09-24, canlı pg_catalog'dan çıkarıldı).
--
-- Kaynak: production Supabase — pg_get_functiondef / pg_get_constraintdef /
-- pg_get_indexdef / pg_get_triggerdef / pg_policies / role_table_grants.
-- Kapsam: 20260923 launch migration'ının dokunduğu tabloların ve testlerin
-- çağırdığı fonksiyonların CANLI tanımları (harness mirror değil).
-- Kapsam dışı modüller (b2b, bakeries) yalnız FK/runtime için stub'dır.
--
-- pg_dump kullanılamadı (DB şifresi yok; yalnız MCP PAT erişimi var).
-- ASLA production/paylaşılan bir veritabanına çalıştırmayın.

-- ── 1) Supabase rolleri + auth mock ──
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
  alter role service_role bypassrls;
end
$$;
grant usage on schema public to anon, authenticated, service_role;

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid()
returns uuid language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to public;

-- ── 2) Kapsam dışı modül stub'ları (FK hedefi / my_entitlement runtime) ──
create table if not exists public.bakeries (
  id uuid primary key default gen_random_uuid()
);
create table if not exists public.b2b_supplier_shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null
);
create table if not exists public.b2b_products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null
);
create table if not exists public.b2b_campaigns (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  published boolean not null default false,
  valid_until date
);
create table if not exists public.b2b_quote_replies (
  id uuid primary key default gen_random_uuid(),
  supplier_shop_id uuid not null,
  created_at timestamptz not null default now()
);

-- ── 3) TABLOLAR — canlı kolon DDL'i ──
create table public.profiles (
  id uuid not null,
  display_name text not null,
  account_type text not null,
  profession_badge text,
  city text,
  avatar_url text,
  email text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  profession_badge_code text,
  city_code text,
  firinnet_id text,
  is_bot boolean not null default false
);

create table public.user_entitlements (
  owner_id uuid not null,
  plan text not null default 'free'::text,
  trial_started_at timestamp with time zone,
  trial_ends_at timestamp with time zone,
  current_period_started_at timestamp with time zone,
  current_period_ends_at timestamp with time zone,
  source text not null default 'manual'::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table public.store_payment_events (
  id uuid not null default gen_random_uuid(),
  provider text not null default 'revenuecat'::text,
  provider_event_id text not null,
  event_type text,
  app_user_id uuid,
  product_id text,
  entitlement_id text,
  transaction_id text,
  original_transaction_id text,
  environment text,
  store text,
  raw_payload jsonb not null,
  processing_status text not null default 'received'::text,
  processing_error text,
  received_at timestamp with time zone not null default now(),
  processed_at timestamp with time zone
);

create table public.store_subscription_transactions (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  account_type text not null,
  plan text not null,
  product_id text not null,
  entitlement_id text,
  store text,
  environment text,
  transaction_id text,
  original_transaction_id text,
  status text not null,
  purchased_at timestamp with time zone,
  expires_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  last_event_id uuid,
  raw_payload jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table public.listing_payment_intents (
  id uuid not null default gen_random_uuid(),
  owner_id uuid not null,
  listing_kind text not null,
  listing_id uuid not null,
  product_id text not null default 'firinnet_listing_fee_50'::text,
  amount_cents integer not null default 5000,
  currency text not null default 'TRY'::text,
  status text not null default 'pending'::text,
  provider text not null default 'revenuecat'::text,
  provider_transaction_id text,
  provider_event_id uuid,
  created_at timestamp with time zone not null default now(),
  confirmed_at timestamp with time zone,
  expires_at timestamp with time zone,
  raw_payload jsonb
);

create table public.job_offer_posts (
  id uuid not null default gen_random_uuid(),
  owner_id uuid not null,
  bakery_id uuid,
  title text not null,
  role_title text not null,
  city text,
  district text,
  description text,
  salary_min numeric(12,2),
  salary_max numeric(12,2),
  shift_type text,
  experience_required text,
  is_active boolean not null default true,
  contact_preference text not null default 'in_app'::text,
  author_name text not null default ''::text,
  author_role text not null default ''::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  city_code text,
  district_code text,
  contact_phone text,
  role_code text,
  shift_code text,
  experience_code text,
  fee_required boolean not null default false,
  fee_amount_cents integer not null default 0,
  fee_currency text not null default 'TRY'::text,
  fee_status text not null default 'not_required'::text,
  paid_at timestamp with time zone,
  payment_reference text
);

create table public.market_listings (
  id uuid not null default gen_random_uuid(),
  owner_id uuid not null,
  title text not null,
  category text not null,
  listing_type text not null default 'equipment_sale'::text,
  condition text,
  description text,
  city text,
  district text,
  price numeric(14,2),
  unit text,
  contact_preference text not null default 'in_app'::text,
  is_active boolean not null default true,
  author_name text not null default ''::text,
  author_role text not null default ''::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  status text not null default 'active'::text,
  is_deleted boolean not null default false,
  equipment_category text,
  currency text not null default 'TRY'::text,
  negotiable boolean not null default false,
  brand text,
  model text,
  year integer,
  rent_price numeric,
  transfer_price numeric,
  equipment_included boolean,
  has_license boolean,
  area_m2 integer,
  contact_phone text,
  contact_whatsapp text,
  view_count integer not null default 0,
  country_code text not null default 'TR'::text,
  city_code text,
  district_code text,
  fee_required boolean not null default false,
  fee_amount_cents integer not null default 0,
  fee_currency text not null default 'TRY'::text,
  fee_status text not null default 'not_required'::text,
  paid_at timestamp with time zone,
  payment_reference text
);

create table public.recipe_calculations (
  id uuid not null default gen_random_uuid(),
  owner_id uuid not null,
  product_name text,
  flour_kg numeric(12,3) not null,
  water_percent numeric(8,3) not null,
  yeast_percent numeric(8,3) not null,
  salt_percent numeric(8,3) not null,
  unit_weight_gr numeric(12,2) not null,
  waste_percent numeric(8,3) not null default 0,
  water_kg numeric(12,3),
  yeast_kg numeric(12,3),
  salt_kg numeric(12,3),
  total_dough_kg numeric(12,3),
  net_dough_kg numeric(12,3),
  estimated_count integer,
  created_at timestamp with time zone not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  published_at timestamp with time zone
);

-- ── 4) CONSTRAINT'LER — canlı pg_get_constraintdef ──
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_firinnet_id_unique UNIQUE (firinnet_id);
alter table public.profiles add constraint profiles_account_type_check CHECK ((account_type = ANY (ARRAY['commercial'::text, 'individual'::text, 'wholesaler'::text])));
alter table public.profiles add constraint profiles_city_code_chk CHECK (((city_code IS NULL) OR (city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$'::text)));
alter table public.profiles add constraint profiles_firinnet_id_format_chk CHECK (((firinnet_id IS NULL) OR (firinnet_id ~ '^FN-[0-9]{4}-[0-9]{6}$'::text)));
alter table public.profiles add constraint profiles_profession_badge_code_chk CHECK (((profession_badge_code IS NULL) OR (profession_badge_code = ANY (ARRAY['usta_firinci'::text, 'firin_sahibi'::text, 'isletmeci'::text, 'mayaci'::text, 'hamurcu'::text, 'simitci'::text, 'pogacaci'::text, 'pasta_ustasi'::text, 'pideci'::text, 'cirak'::text, 'kalfa'::text, 'uncu'::text, 'susamci'::text, 'toptanci'::text, 'ekipman_satici'::text, 'sofor'::text, 'other'::text]))));
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.user_entitlements add constraint user_entitlements_pkey PRIMARY KEY (owner_id);
alter table public.user_entitlements add constraint user_entitlements_plan_check CHECK ((plan = ANY (ARRAY['free'::text, 'pro'::text, 'premium'::text])));
alter table public.user_entitlements add constraint user_entitlements_source_check CHECK ((source = ANY (ARRAY['manual'::text, 'backoffice'::text, 'iap'::text, 'system'::text])));
alter table public.user_entitlements add constraint user_entitlements_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.store_payment_events add constraint store_payment_events_pkey PRIMARY KEY (id);
alter table public.store_payment_events add constraint store_payment_events_provider_event_id_key UNIQUE (provider_event_id);

alter table public.store_subscription_transactions add constraint store_subscription_transactions_pkey PRIMARY KEY (id);
alter table public.store_subscription_transactions add constraint store_sub_user_product_uq UNIQUE (user_id, product_id);
alter table public.store_subscription_transactions add constraint store_sub_acct_chk CHECK ((account_type = ANY (ARRAY['commercial'::text, 'wholesaler'::text])));
alter table public.store_subscription_transactions add constraint store_sub_plan_chk CHECK ((plan = ANY (ARRAY['pro'::text, 'premium'::text])));
alter table public.store_subscription_transactions add constraint store_sub_status_chk CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text, 'refunded'::text, 'grace_period'::text, 'billing_issue'::text, 'unknown'::text])));
alter table public.store_subscription_transactions add constraint store_subscription_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.listing_payment_intents add constraint listing_payment_intents_pkey PRIMARY KEY (id);
alter table public.listing_payment_intents add constraint listing_payment_intents_provider_transaction_id_key UNIQUE (provider_transaction_id);
alter table public.listing_payment_intents add constraint lpi_amount_chk CHECK ((amount_cents = 5000));
alter table public.listing_payment_intents add constraint lpi_kind_chk CHECK ((listing_kind = ANY (ARRAY['job_offer'::text, 'market'::text])));
alter table public.listing_payment_intents add constraint lpi_product_chk CHECK ((product_id = 'firinnet_listing_fee_50'::text));
alter table public.listing_payment_intents add constraint lpi_status_chk CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'expired'::text, 'cancelled'::text, 'failed'::text, 'refunded'::text])));
alter table public.listing_payment_intents add constraint listing_payment_intents_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.job_offer_posts add constraint job_offer_posts_pkey PRIMARY KEY (id);
alter table public.job_offer_posts add constraint job_offer_posts_city_code_chk CHECK (((city_code IS NULL) OR (city_code ~ '^(0[1-9]|[1-7][0-9]|8[01])$'::text)));
alter table public.job_offer_posts add constraint job_offer_posts_contact_preference_check CHECK ((contact_preference = ANY (ARRAY['in_app'::text, 'phone'::text, 'whatsapp'::text])));
alter table public.job_offer_posts add constraint job_offer_posts_contact_preference_chk CHECK ((contact_preference = ANY (ARRAY['in_app'::text, 'phone'::text, 'whatsapp'::text])));
alter table public.job_offer_posts add constraint job_offer_posts_district_code_chk CHECK (((district_code IS NULL) OR ((city_code IS NOT NULL) AND (district_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text) AND (length(district_code) <= 40))));
alter table public.job_offer_posts add constraint job_offer_posts_experience_code_chk CHECK (((experience_code IS NULL) OR (experience_code = ANY (ARRAY['none'::text, '0_2'::text, '3_5'::text, '5_plus'::text]))));
alter table public.job_offer_posts add constraint job_offer_posts_fee_status_chk CHECK ((fee_status = ANY (ARRAY['not_required'::text, 'pending'::text, 'paid'::text, 'waived'::text, 'grandfathered'::text])));
alter table public.job_offer_posts add constraint job_offer_posts_role_code_chk CHECK (((role_code IS NULL) OR (role_code = ANY (ARRAY['usta_firinci'::text, 'firin_sahibi'::text, 'isletmeci'::text, 'mayaci'::text, 'hamurcu'::text, 'simitci'::text, 'pogacaci'::text, 'pasta_ustasi'::text, 'pideci'::text, 'cirak'::text, 'kalfa'::text, 'uncu'::text, 'susamci'::text, 'toptanci'::text, 'ekipman_satici'::text, 'sofor'::text, 'other'::text]))));
alter table public.job_offer_posts add constraint job_offer_posts_salary_max_check CHECK (((salary_max IS NULL) OR (salary_max >= (0)::numeric)));
alter table public.job_offer_posts add constraint job_offer_posts_salary_min_check CHECK (((salary_min IS NULL) OR (salary_min >= (0)::numeric)));
alter table public.job_offer_posts add constraint job_offer_posts_shift_code_chk CHECK (((shift_code IS NULL) OR (shift_code = ANY (ARRAY['gunduz'::text, 'gece'::text, 'vardiyali'::text, 'esnek'::text]))));
alter table public.job_offer_posts add constraint job_offer_posts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public.job_offer_posts add constraint job_offer_posts_bakery_id_fkey FOREIGN KEY (bakery_id) REFERENCES bakeries(id) ON DELETE SET NULL;

alter table public.market_listings add constraint market_listings_pkey PRIMARY KEY (id);
alter table public.market_listings add constraint market_listings_area_m2_check CHECK (((area_m2 IS NULL) OR (area_m2 > 0)));
alter table public.market_listings add constraint market_listings_category_check CHECK ((category = ANY (ARRAY['hammadde'::text, 'ekipman'::text, 'devren_firin'::text, 'ikinci_el'::text, 'ambalaj'::text, 'hizmet'::text, 'diger'::text])));
alter table public.market_listings add constraint market_listings_city_code_format_check CHECK (((city_code IS NULL) OR (city_code ~ '^[0-9]{2}$'::text)));
alter table public.market_listings add constraint market_listings_condition_check CHECK (((condition IS NULL) OR (condition = ANY (ARRAY['new'::text, 'used'::text, 'refurbished'::text]))));
alter table public.market_listings add constraint market_listings_contact_preference_check CHECK ((contact_preference = ANY (ARRAY['in_app'::text, 'phone'::text, 'whatsapp'::text])));
alter table public.market_listings add constraint market_listings_country_code_check CHECK ((country_code = 'TR'::text));
alter table public.market_listings add constraint market_listings_district_code_format_check CHECK (((district_code IS NULL) OR (district_code ~ '^[a-z0-9][a-z0-9-]*$'::text)));
alter table public.market_listings add constraint market_listings_district_requires_city_check CHECK (((district_code IS NULL) OR (city_code IS NOT NULL)));
alter table public.market_listings add constraint market_listings_fee_status_chk CHECK ((fee_status = ANY (ARRAY['not_required'::text, 'pending'::text, 'paid'::text, 'waived'::text, 'grandfathered'::text])));
alter table public.market_listings add constraint market_listings_listing_type_check CHECK ((listing_type = ANY (ARRAY['equipment_sale'::text, 'bakery_transfer'::text])));
alter table public.market_listings add constraint market_listings_price_check CHECK (((price IS NULL) OR (price >= (0)::numeric)));
alter table public.market_listings add constraint market_listings_rent_price_check CHECK (((rent_price IS NULL) OR (rent_price >= (0)::numeric)));
alter table public.market_listings add constraint market_listings_status_check CHECK ((status = ANY (ARRAY['active'::text, 'sold'::text, 'paused'::text])));
alter table public.market_listings add constraint market_listings_transfer_price_check CHECK (((transfer_price IS NULL) OR (transfer_price >= (0)::numeric)));
alter table public.market_listings add constraint market_listings_year_check CHECK (((year IS NULL) OR ((year >= 1900) AND (year <= 2100))));
alter table public.market_listings add constraint market_listings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table public.recipe_calculations add constraint recipe_calculations_pkey PRIMARY KEY (id);
alter table public.recipe_calculations add constraint recipe_calculations_flour_kg_check CHECK ((flour_kg > (0)::numeric));
alter table public.recipe_calculations add constraint recipe_calculations_salt_percent_check CHECK ((salt_percent >= (0)::numeric));
alter table public.recipe_calculations add constraint recipe_calculations_unit_weight_gr_check CHECK ((unit_weight_gr > (0)::numeric));
alter table public.recipe_calculations add constraint recipe_calculations_waste_percent_check CHECK (((waste_percent >= (0)::numeric) AND (waste_percent <= (100)::numeric)));
alter table public.recipe_calculations add constraint recipe_calculations_water_percent_check CHECK ((water_percent >= (0)::numeric));
alter table public.recipe_calculations add constraint recipe_calculations_yeast_percent_check CHECK ((yeast_percent >= (0)::numeric));
alter table public.recipe_calculations add constraint recipe_calculations_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── 5) INDEX'LER — canlı pg_get_indexdef ──
CREATE INDEX idx_job_offer_posts_active_created ON public.job_offer_posts USING btree (created_at DESC) WHERE (is_active = true);
CREATE INDEX idx_job_offer_posts_city ON public.job_offer_posts USING btree (city) WHERE (is_active = true);
CREATE INDEX idx_job_offer_posts_owner ON public.job_offer_posts USING btree (owner_id, created_at DESC);
CREATE INDEX lpi_owner_listing_idx ON public.listing_payment_intents USING btree (owner_id, listing_id, status);
CREATE INDEX idx_market_listings_active_created ON public.market_listings USING btree (created_at DESC) WHERE (is_active = true);
CREATE INDEX idx_market_listings_category ON public.market_listings USING btree (category) WHERE (is_active = true);
CREATE INDEX idx_market_listings_city ON public.market_listings USING btree (city) WHERE (is_active = true);
CREATE INDEX idx_market_listings_owner ON public.market_listings USING btree (owner_id, created_at DESC);
CREATE INDEX market_listings_city_district_idx ON public.market_listings USING btree (city_code, district_code) WHERE (is_deleted = false);
CREATE INDEX market_listings_owner_created_idx ON public.market_listings USING btree (owner_id, created_at DESC);
CREATE INDEX market_listings_status_deleted_created_idx ON public.market_listings USING btree (status, is_deleted, created_at DESC);
CREATE INDEX market_listings_type_city_code_idx ON public.market_listings USING btree (listing_type, city_code) WHERE (is_deleted = false);
CREATE INDEX idx_recipe_calculations_created_at ON public.recipe_calculations USING btree (created_at DESC);
CREATE INDEX idx_recipe_calculations_owner_id ON public.recipe_calculations USING btree (owner_id);
CREATE INDEX idx_recipe_calculations_public_created ON public.recipe_calculations USING btree (created_at DESC) WHERE (is_public = true);

-- ── 6) FONKSİYONLAR — canlı pg_get_functiondef (migration öncesi durum) ──
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.current_business_plan(p_owner_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when e.trial_ends_at is not null and e.trial_ends_at > now() then 'premium'
    else coalesce(e.plan, 'free')
  end
  from (select p_owner_id as id) x
  left join public.user_entitlements e on e.owner_id = x.id;
$function$;

CREATE OR REPLACE FUNCTION public.effective_supplier_plan(p_owner_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_plan text; v_trial timestamptz;
begin
  select plan, trial_ends_at into v_plan, v_trial from public.user_entitlements where owner_id = p_owner_id;
  if v_plan is null then return 'free'; end if;
  if v_plan = 'premium' then return 'premium'; end if;
  if v_trial is not null and v_trial > now() then return 'pro'; end if;
  return v_plan;
end;
$function$;

CREATE OR REPLACE FUNCTION public.supplier_product_limit(p_owner_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select case public.effective_supplier_plan(p_owner_id)
  when 'premium' then -1 when 'pro' then 5 else 1 end; $function$;

CREATE OR REPLACE FUNCTION public.supplier_campaign_limit(p_owner_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select case public.effective_supplier_plan(p_owner_id)
  when 'premium' then -1 when 'pro' then 3 else 0 end; $function$;

CREATE OR REPLACE FUNCTION public.supplier_monthly_reply_limit(p_owner_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select case public.effective_supplier_plan(p_owner_id)
  when 'premium' then -1 when 'pro' then 20 else 3 end; $function$;

CREATE OR REPLACE FUNCTION public.can_add_b2b_product(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_limit int; v_count int;
begin
  v_limit := public.supplier_product_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  select count(*) into v_count from public.b2b_products p
  join public.b2b_supplier_shops s on s.id = p.shop_id
  where s.owner_id = p_owner_id;
  return v_count < v_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_add_b2b_campaign(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_limit int; v_count int; v_today date;
begin
  v_limit := public.supplier_campaign_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  if v_limit = 0 then return false; end if;
  v_today := (now() at time zone 'Europe/Istanbul')::date;
  select count(*) into v_count from public.b2b_campaigns c
  join public.b2b_supplier_shops s on s.id = c.shop_id
  where s.owner_id = p_owner_id and c.published = true
    and (c.valid_until is null or c.valid_until >= v_today);
  return v_count < v_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_reply_b2b_quote(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_limit int; v_count int; v_month_start timestamptz;
begin
  v_limit := public.supplier_monthly_reply_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  v_month_start := (date_trunc('month', (now() at time zone 'Europe/Istanbul')))
    at time zone 'Europe/Istanbul';
  select count(*) into v_count from public.b2b_quote_replies r
  join public.b2b_supplier_shops s on s.id = r.supplier_shop_id
  where s.owner_id = p_owner_id and r.created_at >= v_month_start;
  return v_count < v_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.has_business_feature(p_owner_id uuid, p_feature text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_acct text; v_plan text;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  return case p_feature
    when 'branches' then v_plan = 'premium'
    when 'dealer_driver_ops' then v_plan = 'premium'
    when 'debt_expense' then v_plan in ('pro', 'premium')
    else false
  end;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_add_dealer(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_acct text; v_plan text;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then return true; end if;
  v_plan := public.current_business_plan(p_owner_id);
  return v_plan in ('pro', 'premium');
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_add_recipe(p_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_acct text; v_plan text; v_count int;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then return true; end if;
  v_plan := public.current_business_plan(p_owner_id);
  if v_plan = 'premium' then return true; end if;
  select count(*) into v_count from public.recipe_calculations
    where owner_id = p_owner_id;
  if v_plan = 'pro' then return v_count < 50; end if;
  return v_count < 5;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_my_entitlement()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := auth.uid(); v_acct text;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if exists (select 1 from public.user_entitlements where owner_id = v_uid) then
    return;
  end if;
  select account_type into v_acct from public.profiles where id = v_uid;
  if v_acct in ('commercial', 'wholesaler') then
    insert into public.user_entitlements
      (owner_id, plan, trial_started_at, trial_ends_at, source)
    values (v_uid, 'free', now(), now() + interval '30 days', 'system')
    on conflict (owner_id) do nothing;
  else
    insert into public.user_entitlements (owner_id, plan, source)
    values (v_uid, 'free', 'system')
    on conflict (owner_id) do nothing;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.my_entitlement()
 RETURNS TABLE(plan text, effective_plan text, is_trial_active boolean, trial_started_at timestamp with time zone, trial_ends_at timestamp with time zone, days_left integer, recipe_limit integer, dealer_limit integer, can_use_branches boolean, can_use_debt_expense boolean, can_use_dealer_driver_ops boolean, supplier_effective_plan text, supplier_product_limit integer, supplier_campaign_limit integer, supplier_monthly_reply_limit integer, supplier_can_add_product boolean, supplier_can_add_campaign boolean, supplier_can_reply_quote boolean, supplier_listing_fee_exempt boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with me as (
    select public.current_business_plan(auth.uid()) as eff,
      e.plan as actual, e.trial_started_at, e.trial_ends_at,
      p.account_type as acct
    from (select auth.uid() as id) x
    left join public.user_entitlements e on e.owner_id = x.id
    left join public.profiles p on p.id = x.id
  )
  select
    coalesce(me.actual, 'free'),
    me.eff,
    (me.trial_ends_at is not null and me.trial_ends_at > now()),
    me.trial_started_at, me.trial_ends_at,
    case when me.trial_ends_at is not null and me.trial_ends_at > now()
      then ceil(extract(epoch from (me.trial_ends_at - now())) / 86400.0)::int
      else 0 end,
    case me.eff when 'premium' then -1 when 'pro' then 50 else 5 end,
    case me.eff when 'free' then 0 else -1 end,
    public.has_business_feature(auth.uid(), 'branches'),
    public.has_business_feature(auth.uid(), 'debt_expense'),
    public.has_business_feature(auth.uid(), 'dealer_driver_ops'),
    public.effective_supplier_plan(auth.uid()),
    public.supplier_product_limit(auth.uid()),
    public.supplier_campaign_limit(auth.uid()),
    public.supplier_monthly_reply_limit(auth.uid()),
    public.can_add_b2b_product(auth.uid()),
    public.can_add_b2b_campaign(auth.uid()),
    public.can_reply_b2b_quote(auth.uid()),
    (me.acct = 'wholesaler'
      and public.effective_supplier_plan(auth.uid()) in ('pro', 'premium'))
  from me;
$function$;

CREATE OR REPLACE FUNCTION public.store_product_mapping(p_product_id text)
 RETURNS TABLE(account_type text, plan text, kind text)
 LANGUAGE sql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select m.account_type, m.plan, m.kind from (values
    ('firinnet_bakery_pro_monthly',      'commercial', 'pro',     'subscription'),
    ('firinnet_bakery_premium_monthly',  'commercial', 'premium', 'subscription'),
    ('firinnet_supplier_pro_monthly',    'wholesaler', 'pro',     'subscription'),
    ('firinnet_supplier_premium_monthly','wholesaler', 'premium', 'subscription'),
    ('firinnet_listing_fee_50',          null,         null,      'listing_fee')
  ) as m(product_id, account_type, plan, kind)
  where m.product_id = p_product_id;
$function$;

CREATE OR REPLACE FUNCTION public.apply_store_subscription(p_user_id uuid, p_product_id text, p_status text, p_store text DEFAULT NULL::text, p_environment text DEFAULT NULL::text, p_transaction_id text DEFAULT NULL::text, p_original_transaction_id text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_event_id uuid DEFAULT NULL::uuid, p_raw jsonb DEFAULT NULL::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_acct text; v_plan text; v_kind text; v_user_acct text; v_active boolean;
begin
  select account_type, plan, kind into v_acct, v_plan, v_kind from public.store_product_mapping(p_product_id);
  if v_kind is distinct from 'subscription' then return 'ignored_not_subscription'; end if;
  select account_type into v_user_acct from public.profiles where id = p_user_id;
  if v_user_acct is distinct from v_acct then return 'ignored_wrong_account_type'; end if;
  v_active := (p_status = 'active');
  insert into public.store_subscription_transactions
    (user_id, account_type, plan, product_id, store, environment, transaction_id,
     original_transaction_id, status, purchased_at, expires_at, cancelled_at, last_event_id, raw_payload)
  values (p_user_id, v_acct, v_plan, p_product_id, p_store, p_environment, p_transaction_id,
     p_original_transaction_id, p_status, case when v_active then now() else null end, p_expires_at,
     case when v_active then null else now() end, p_event_id, p_raw)
  on conflict (user_id, product_id) do update set
    status = excluded.status, plan = excluded.plan, expires_at = excluded.expires_at,
    transaction_id = coalesce(excluded.transaction_id, store_subscription_transactions.transaction_id),
    cancelled_at = case when excluded.status = 'active' then null else now() end,
    last_event_id = excluded.last_event_id,
    raw_payload = coalesce(excluded.raw_payload, store_subscription_transactions.raw_payload),
    updated_at = now();
  if v_active then
    update public.user_entitlements set plan = v_plan, source = 'iap',
      current_period_started_at = now(), current_period_ends_at = p_expires_at, updated_at = now()
    where owner_id = p_user_id;
    if not found then
      insert into public.user_entitlements (owner_id, plan, source, current_period_started_at, current_period_ends_at)
      values (p_user_id, v_plan, 'iap', now(), p_expires_at);
    end if;
    return 'applied_active_' || v_plan;
  else
    update public.user_entitlements set plan = 'free', source = 'iap',
      current_period_ends_at = p_expires_at, updated_at = now() where owner_id = p_user_id;
    return 'applied_downgrade_free';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_listing_fee_amount_cents(p_owner_id uuid, p_listing_type text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_acct text;
begin
  if p_listing_type = 'job_seek' then return 0; end if;
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct = 'commercial'
     and public.current_business_plan(p_owner_id) in ('pro', 'premium') then
    return 0;
  end if;
  if v_acct = 'wholesaler'
     and public.effective_supplier_plan(p_owner_id) in ('pro', 'premium') then
    return 0;
  end if;
  return 5000;
end;
$function$;

CREATE OR REPLACE FUNCTION public.normalize_listing_fee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_kind text; v_fee int;
begin
  if current_setting('app.listing_fee_admin', true) = 'on' then
    return new;
  end if;
  v_kind := case tg_table_name
    when 'job_offer_posts' then 'job_offer'
    when 'market_listings' then 'market'
    else 'market' end;
  if tg_op = 'INSERT' then
    v_fee := public.get_listing_fee_amount_cents(new.owner_id, v_kind);
    new.fee_currency := 'TRY';
    new.paid_at := null;
    new.payment_reference := null;
    if v_fee = 0 then
      new.fee_required := false;
      new.fee_amount_cents := 0;
      new.fee_status := 'not_required';
    else
      new.fee_required := true;
      new.fee_amount_cents := v_fee;
      new.fee_status := 'pending';
    end if;
    return new;
  end if;
  new.fee_required := old.fee_required;
  new.fee_amount_cents := old.fee_amount_cents;
  new.fee_currency := old.fee_currency;
  new.fee_status := old.fee_status;
  new.paid_at := old.paid_at;
  new.payment_reference := old.payment_reference;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_listing_fee_paid(p_listing_id uuid, p_payment_reference text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_done int := 0;
begin
  perform set_config('app.listing_fee_admin', 'on', true);
  update public.job_offer_posts
    set fee_status = 'paid', paid_at = now(),
        payment_reference = nullif(p_payment_reference, '')
    where id = p_listing_id and fee_status = 'pending';
  get diagnostics v_done = row_count;
  if v_done = 0 then
    update public.market_listings
      set fee_status = 'paid', paid_at = now(),
          payment_reference = nullif(p_payment_reference, '')
      where id = p_listing_id and fee_status = 'pending';
    get diagnostics v_done = row_count;
  end if;
  perform set_config('app.listing_fee_admin', 'off', true);
  return v_done > 0;
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_listing_fee_paid_from_store(p_intent_id uuid, p_transaction_id text, p_event_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid; v_kind text; v_listing uuid; v_status text; v_ok boolean;
begin
  select owner_id, listing_kind, listing_id, status into v_owner, v_kind, v_listing, v_status
  from public.listing_payment_intents where id = p_intent_id;
  if v_owner is null then return false; end if;
  if v_status = 'paid' then return true; end if;
  if v_status <> 'pending' then return false; end if;
  update public.listing_payment_intents set status = 'paid', provider_transaction_id = p_transaction_id,
    provider_event_id = p_event_id, confirmed_at = now() where id = p_intent_id and status = 'pending';
  v_ok := public.mark_listing_fee_paid(v_listing, 'store:' || coalesce(p_transaction_id, ''));
  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_listing_payment_intent(p_listing_kind text, p_listing_id uuid)
 RETURNS TABLE(intent_id uuid, product_id text, amount_cents integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := auth.uid(); v_owner uuid; v_fee_status text; v_existing uuid; v_new uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_listing_kind not in ('job_offer', 'market') then raise exception 'invalid listing kind'; end if;
  if p_listing_kind = 'job_offer' then
    select owner_id, fee_status into v_owner, v_fee_status from public.job_offer_posts where id = p_listing_id;
  else
    select owner_id, fee_status into v_owner, v_fee_status from public.market_listings where id = p_listing_id;
  end if;
  if v_owner is null then raise exception 'listing not found'; end if;
  if v_owner <> v_uid then raise exception 'not listing owner'; end if;
  if v_fee_status <> 'pending' then raise exception 'listing not awaiting payment'; end if;
  select id into v_existing from public.listing_payment_intents
  where owner_id = v_uid and listing_id = p_listing_id and status = 'pending' order by created_at desc limit 1;
  if v_existing is not null then
    return query select v_existing, 'firinnet_listing_fee_50'::text, 5000; return;
  end if;
  insert into public.listing_payment_intents (owner_id, listing_kind, listing_id)
  values (v_uid, p_listing_kind, p_listing_id) returning id into v_new;
  return query select v_new, 'firinnet_listing_fee_50'::text, 5000;
end;
$function$;

CREATE OR REPLACE FUNCTION public.has_role_locked_data(p_uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    exists (select 1 from public.dealers where owner_id = p_uid)
    or exists (select 1 from public.dealer_transactions where owner_id = p_uid)
    or exists (select 1 from public.dealer_deliveries where owner_id = p_uid)
    or exists (select 1 from public.dealer_prices where owner_id = p_uid)
    or exists (select 1 from public.dealer_notes where owner_id = p_uid)
    or exists (select 1 from public.debt_expense_entries where owner_id = p_uid);
$function$;

CREATE OR REPLACE FUNCTION public.guard_account_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.account_type is distinct from old.account_type then
    if public.has_role_locked_data(new.id) then
      raise exception 'role_data_lock: existing business records block account type change';
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.snapshot_job_offer_post_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_name text; v_badge text; v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account from public.profiles where id = new.owner_id;
  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet İşletmesi');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial' then 'Ticari'
      when 'wholesaler' then 'Toptancı'
      when 'individual' then 'Bireysel'
      else 'Üye'
    end);
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.snapshot_market_listing_author()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_name text; v_badge text; v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account from public.profiles where id = new.owner_id;
  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet Satıcı');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial' then 'Ticari'
      when 'wholesaler' then 'Toptancı'
      when 'individual' then 'Bireysel'
      else 'Üye'
    end);
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.calculate_recipe_calculation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$;

-- ── 7) TRIGGER'LAR — canlı pg_get_triggerdef ──
CREATE TRIGGER trg_profiles_set_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_guard_account_type_change BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION guard_account_type_change();
CREATE TRIGGER trg_user_entitlements_set_updated_at BEFORE UPDATE ON public.user_entitlements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_store_sub_updated BEFORE UPDATE ON public.store_subscription_transactions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_job_offer_posts_snapshot_author BEFORE INSERT ON public.job_offer_posts FOR EACH ROW EXECUTE FUNCTION snapshot_job_offer_post_author();
CREATE TRIGGER trg_job_offer_posts_updated_at BEFORE UPDATE ON public.job_offer_posts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_normalize_listing_fee BEFORE INSERT OR UPDATE ON public.job_offer_posts FOR EACH ROW EXECUTE FUNCTION normalize_listing_fee();
CREATE TRIGGER trg_market_listings_snapshot_author BEFORE INSERT ON public.market_listings FOR EACH ROW EXECUTE FUNCTION snapshot_market_listing_author();
CREATE TRIGGER trg_market_listings_updated_at BEFORE UPDATE ON public.market_listings FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_normalize_listing_fee BEFORE INSERT OR UPDATE ON public.market_listings FOR EACH ROW EXECUTE FUNCTION normalize_listing_fee();
CREATE TRIGGER trg_recipe_calculations_calculate BEFORE INSERT OR UPDATE ON public.recipe_calculations FOR EACH ROW EXECUTE FUNCTION calculate_recipe_calculation();

-- ── 8) RLS + POLICY'LER — canlı pg_policies ──
alter table public.profiles enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.store_payment_events enable row level security;
alter table public.store_subscription_transactions enable row level security;
alter table public.listing_payment_intents enable row level security;
alter table public.job_offer_posts enable row level security;
alter table public.market_listings enable row level security;
alter table public.recipe_calculations enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_delete_own on public.profiles for delete to authenticated using (id = auth.uid());

create policy user_entitlements_select_own on public.user_entitlements for select to authenticated using (owner_id = auth.uid());

create policy store_sub_select_own on public.store_subscription_transactions for select to authenticated using (user_id = auth.uid());

create policy lpi_select_own on public.listing_payment_intents for select to authenticated using (owner_id = auth.uid());

create policy job_offer_posts_select_active_or_own on public.job_offer_posts for select
  using (((is_active = true) and (fee_status <> 'pending'::text)) or (owner_id = auth.uid()));
create policy job_offer_posts_insert_own on public.job_offer_posts for insert to authenticated with check (owner_id = auth.uid());
create policy job_offer_posts_update_own on public.job_offer_posts for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy job_offer_posts_delete_own on public.job_offer_posts for delete to authenticated using (owner_id = auth.uid());

create policy market_listings_select_active_or_own on public.market_listings for select
  using (((status = 'active'::text) and (is_deleted = false) and (fee_status <> 'pending'::text)) or (owner_id = auth.uid()));
create policy market_listings_insert_own on public.market_listings for insert to authenticated with check (owner_id = auth.uid());
create policy market_listings_update_own on public.market_listings for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy market_listings_delete_own on public.market_listings for delete to authenticated using (owner_id = auth.uid());

create policy recipe_calculations_select_own on public.recipe_calculations for select to authenticated using (owner_id = auth.uid());
create policy recipe_calculations_select_public on public.recipe_calculations for select to authenticated using (is_public = true);
create policy recipe_calculations_insert_own on public.recipe_calculations for insert to authenticated with check ((owner_id = auth.uid()) and can_add_recipe(auth.uid()));
create policy recipe_calculations_update_own on public.recipe_calculations for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy recipe_calculations_delete_own on public.recipe_calculations for delete to authenticated using (owner_id = auth.uid());

-- ── 9) GRANT'LER — canlı role_table_grants + proacl ──
grant delete, insert, references, select, trigger, truncate, update on public.profiles to authenticated;
grant references, trigger, truncate on public.profiles to anon, service_role;
grant select on public.user_entitlements to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.user_entitlements to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.store_payment_events to service_role;
grant references, select, trigger, truncate on public.store_subscription_transactions to authenticated;
grant references, trigger, truncate on public.store_subscription_transactions to anon;
grant delete, insert, references, select, trigger, truncate, update on public.store_subscription_transactions to service_role;
grant references, select, trigger, truncate on public.listing_payment_intents to authenticated;
grant references, trigger, truncate on public.listing_payment_intents to anon;
grant delete, insert, references, select, trigger, truncate, update on public.listing_payment_intents to service_role;
grant delete, insert, references, select, trigger, truncate, update on public.job_offer_posts to authenticated;
grant references, trigger, truncate on public.job_offer_posts to anon, service_role;
grant delete, insert, references, select, trigger, truncate, update on public.market_listings to authenticated;
grant references, trigger, truncate on public.market_listings to anon, service_role;
grant delete, insert, references, select, trigger, truncate, update on public.recipe_calculations to authenticated;
grant references, trigger, truncate on public.recipe_calculations to anon, service_role;

-- Fonksiyon ACL'leri (canlı proacl; postgres=definer zaten owner).
revoke execute on function public.apply_store_subscription(uuid, text, text, text, text, text, text, timestamptz, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.apply_store_subscription(uuid, text, text, text, text, text, text, timestamptz, uuid, jsonb) to service_role;
revoke execute on function public.mark_listing_fee_paid(uuid, text) from public, anon, authenticated;
grant execute on function public.mark_listing_fee_paid(uuid, text) to service_role;
revoke execute on function public.mark_listing_fee_paid_from_store(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.mark_listing_fee_paid_from_store(uuid, text, uuid) to service_role;
revoke execute on function public.create_listing_payment_intent(text, uuid) from public, anon;
grant execute on function public.create_listing_payment_intent(text, uuid) to authenticated;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;
revoke execute on function public.ensure_my_entitlement() from public, anon;
grant execute on function public.ensure_my_entitlement() to authenticated;
revoke execute on function public.current_business_plan(uuid) from public, anon;
grant execute on function public.current_business_plan(uuid) to authenticated;
revoke execute on function public.effective_supplier_plan(uuid) from public, anon;
grant execute on function public.effective_supplier_plan(uuid) to authenticated;
revoke execute on function public.get_listing_fee_amount_cents(uuid, text) from public, anon;
grant execute on function public.get_listing_fee_amount_cents(uuid, text) to authenticated;
revoke execute on function public.can_add_recipe(uuid) from public, anon;
grant execute on function public.can_add_recipe(uuid) to authenticated;
revoke execute on function public.store_product_mapping(text) from public, anon;
grant execute on function public.store_product_mapping(text) to authenticated, service_role;
revoke execute on function public.normalize_listing_fee() from public, anon, authenticated;

-- ── 10) Test kullanıcıları + sonuç panosu ──
-- Bildirim tablosu (canlı DDL aynası — supplier launch hatırlatma testleri).
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

insert into auth.users (id) values
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003'),
  ('00000000-0000-4000-8000-000000000004'),
  ('00000000-0000-4000-8000-000000000005'),
  ('00000000-0000-4000-8000-000000000006'),
  ('00000000-0000-4000-8000-000000000007'),
  ('00000000-0000-4000-8000-000000000008'),
  ('00000000-0000-4000-8000-000000000009'),
  ('00000000-0000-4000-8000-000000000010')
on conflict do nothing;

insert into public.profiles (id, display_name, account_type) values
  ('00000000-0000-4000-8000-000000000001', 'Test Bir', 'commercial'),
  ('00000000-0000-4000-8000-000000000002', 'Test İki', 'commercial'),
  ('00000000-0000-4000-8000-000000000003', 'Test Üç', 'commercial'),
  ('00000000-0000-4000-8000-000000000004', 'Test Dört', 'commercial'),
  ('00000000-0000-4000-8000-000000000005', 'Test Beş', 'commercial'),
  ('00000000-0000-4000-8000-000000000006', 'Test Altı', 'commercial'),
  ('00000000-0000-4000-8000-000000000007', 'Eski App Ticari', 'commercial'),
  ('00000000-0000-4000-8000-000000000008', 'Ziyaretçi', 'individual'),
  ('00000000-0000-4000-8000-000000000009', 'Toptancı Dokuz', 'wholesaler'),
  ('00000000-0000-4000-8000-000000000010', 'Bireysel On', 'individual')
on conflict do nothing;

create table if not exists public.test_results (
  label text not null,
  a text,
  b text,
  c text,
  recorded_at timestamptz not null default now()
);
grant select, insert on public.test_results to public;
