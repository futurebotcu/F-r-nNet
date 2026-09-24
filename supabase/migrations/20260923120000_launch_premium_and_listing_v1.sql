-- FırınNet Launch Premium + Listing Lifecycle V1 (ADDITIVE).
--
-- Production verisini silmez. Eski store transaction/product id geçmişi korunur.
-- Yeni iş modeli:
--   * Premium promo otomatik başlamaz; authenticated kullanıcı CTA ile başlatır.
--   * Promo server-side 3 takvim ayıdır, tek seferlik ve idempotenttir.
--   * Yeni satış ürünleri sade Premium aylık/yıllık ürünleridir.
--   * İlan ödemeleri lansman döneminde server-side kapalıdır; 50 TL altyapı kalır.
--   * Yeni ilanlar maksimum 30 gün görünür; sorgu/RLS seviyesinde expires_at korunur.

-- 1) Merkezi runtime config.
create table if not exists public.app_runtime_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_runtime_config enable row level security;
revoke all on public.app_runtime_config from anon, authenticated;
grant select, insert, update, delete on public.app_runtime_config to service_role;

insert into public.app_runtime_config (key, value) values
  ('premium_promo_months', '3'::jsonb),
  ('listing_payments_enabled', 'false'::jsonb),
  ('listing_free_until', '"2027-09-23T00:00:00Z"'::jsonb),
  ('listing_max_active_days', '30'::jsonb)
on conflict (key) do update set value = excluded.value, updated_at = now();

create or replace function public.app_config_int(p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (value #>> '{}')::integer
     from public.app_runtime_config where key = p_key),
    p_default
  );
$$;
revoke execute on function public.app_config_int(text, integer) from public, anon;
grant execute on function public.app_config_int(text, integer) to authenticated, service_role;

create or replace function public.app_config_bool(p_key text, p_default boolean)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (value #>> '{}')::boolean
     from public.app_runtime_config where key = p_key),
    p_default
  );
$$;
revoke execute on function public.app_config_bool(text, boolean) from public, anon;
grant execute on function public.app_config_bool(text, boolean) to authenticated, service_role;

create or replace function public.app_config_timestamptz(
  p_key text,
  p_default timestamptz
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (value #>> '{}')::timestamptz
     from public.app_runtime_config where key = p_key),
    p_default
  );
$$;
revoke execute on function public.app_config_timestamptz(text, timestamptz)
  from public, anon;
grant execute on function public.app_config_timestamptz(text, timestamptz)
  to authenticated, service_role;

-- 2) user_entitlements: eski trial kolonları kalır, yeni promo kolonları eklenir.
alter table public.user_entitlements
  add column if not exists promo_started_at timestamptz,
  add column if not exists promo_expires_at timestamptz,
  add column if not exists promo_status text not null default 'not_started';

alter table public.store_payment_events
  add column if not exists event_timestamp_ms bigint,
  add column if not exists processing_attempts integer not null default 0,
  add column if not exists locked_at timestamptz;

alter table public.store_subscription_transactions
  add column if not exists last_event_timestamp_ms bigint;

alter table public.user_entitlements
  drop constraint if exists user_entitlements_promo_status_chk;
alter table public.user_entitlements
  add constraint user_entitlements_promo_status_chk
  check (promo_status in ('not_started', 'active', 'expired', 'used'));

create index if not exists user_entitlements_promo_active_idx
  on public.user_entitlements (promo_status, promo_expires_at)
  where promo_status = 'active';

create index if not exists store_payment_events_processing_idx
  on public.store_payment_events (processing_status, locked_at);

create or replace function public.claim_store_payment_event(
  p_provider_event_id text,
  p_event_type text,
  p_app_user_id uuid,
  p_product_id text,
  p_entitlement_id text,
  p_transaction_id text,
  p_original_transaction_id text,
  p_environment text,
  p_store text,
  p_event_timestamp_ms bigint,
  p_raw_payload jsonb,
  p_can_process boolean
)
returns table (event_id uuid, should_process boolean, current_status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.store_payment_events%rowtype;
begin
  insert into public.store_payment_events
    (provider_event_id, event_type, app_user_id, product_id, entitlement_id,
     transaction_id, original_transaction_id, environment, store, raw_payload,
     event_timestamp_ms, processing_status, processing_attempts, locked_at)
  values
    (p_provider_event_id, p_event_type, p_app_user_id, p_product_id,
     p_entitlement_id, p_transaction_id, p_original_transaction_id,
     p_environment, p_store, p_raw_payload, p_event_timestamp_ms,
     case when p_can_process then 'processing' else 'skipped_no_secret' end,
     case when p_can_process then 1 else 0 end,
     case when p_can_process then now() else null end)
  on conflict (provider_event_id) do nothing
  returning * into v_row;

  if found then
    return query select v_row.id, p_can_process, v_row.processing_status;
    return;
  end if;

  select * into v_row
  from public.store_payment_events
  where provider_event_id = p_provider_event_id
  for update;

  if not found then
    raise exception 'store payment event claim failed';
  end if;

  if not p_can_process then
    if v_row.processing_status <> 'skipped_no_secret' then
      update public.store_payment_events
        set processing_status = 'skipped_no_secret',
            processing_error = null,
            processed_at = now(),
            locked_at = null,
            raw_payload = coalesce(p_raw_payload, raw_payload),
            event_timestamp_ms = coalesce(
              p_event_timestamp_ms,
              event_timestamp_ms
            )
      where id = v_row.id
      returning * into v_row;
    end if;
    return query select v_row.id, false, v_row.processing_status;
    return;
  end if;

  if v_row.processing_status in (
    'applied',
    'recorded_listing_fee_needs_confirm',
    'skipped_no_secret'
  ) or v_row.processing_status like 'ignored_%' then
    return query select v_row.id, false, v_row.processing_status;
    return;
  end if;

  if v_row.processing_status = 'processing'
     and v_row.locked_at is not null
     and v_row.locked_at > now() - interval '5 minutes' then
    return query select v_row.id, false, v_row.processing_status;
    return;
  end if;

  update public.store_payment_events
    set processing_status = 'processing',
        processing_error = null,
        processing_attempts = processing_attempts + 1,
        locked_at = now(),
        raw_payload = coalesce(p_raw_payload, raw_payload),
        event_timestamp_ms = coalesce(p_event_timestamp_ms, event_timestamp_ms)
  where id = v_row.id
  returning * into v_row;

  return query select v_row.id, true, v_row.processing_status;
end;
$$;
revoke execute on function public.claim_store_payment_event(
  text, text, uuid, text, text, text, text, text, text, bigint, jsonb, boolean
) from public, anon, authenticated;
grant execute on function public.claim_store_payment_event(
  text, text, uuid, text, text, text, text, text, text, bigint, jsonb, boolean
) to service_role;

create or replace function public.complete_store_payment_event(
  p_provider_event_id text,
  p_processing_status text,
  p_processing_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.store_payment_events
    set processing_status = p_processing_status,
        processing_error = p_processing_error,
        processed_at = case
          when p_processing_status = 'failed' then processed_at else now() end,
        locked_at = null
  where provider_event_id = p_provider_event_id;

  if not found then
    raise exception 'store payment event not found';
  end if;
end;
$$;
revoke execute on function public.complete_store_payment_event(text, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_store_payment_event(text, text, text)
  to service_role;

create or replace function public.is_launch_promo_active(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_entitlements e
    where e.owner_id = p_owner_id
      and e.promo_status = 'active'
      and e.promo_expires_at > now()
  );
$$;
revoke execute on function public.is_launch_promo_active(uuid)
  from public, anon;
grant execute on function public.is_launch_promo_active(uuid)
  to authenticated, service_role;

-- Paid Premium veya aktif launch promo Premium açar. Eski trial artık effective
-- plan üretmez; geçmiş kolonlar korunur ama yeni mantığın kaynağı değildir.
create or replace function public.current_business_plan(p_owner_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(e.plan, 'free') in ('premium', 'pro')
      and (e.current_period_ends_at is null or e.current_period_ends_at > now())
      then 'premium'
    when e.promo_status = 'active' and e.promo_expires_at > now()
      then 'premium'
    else 'free'
  end
  from (select p_owner_id as id) x
  left join public.user_entitlements e on e.owner_id = x.id;
$$;
revoke execute on function public.current_business_plan(uuid) from public, anon;
grant execute on function public.current_business_plan(uuid)
  to authenticated, service_role;

create or replace function public.effective_supplier_plan(p_owner_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_business_plan(p_owner_id);
$$;
revoke execute on function public.effective_supplier_plan(uuid)
  from public, anon;
grant execute on function public.effective_supplier_plan(uuid)
  to authenticated, service_role;

-- Yeni satır garantisi promo başlatmaz.
create or replace function public.ensure_my_entitlement()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'auth required'; end if;
  insert into public.user_entitlements (owner_id, plan, source)
  values (v_uid, 'free', 'system')
  on conflict (owner_id) do nothing;
end;
$$;
revoke execute on function public.ensure_my_entitlement() from public, anon;
grant execute on function public.ensure_my_entitlement() to authenticated;

-- CTA endpoint'i: tek seferlik, idempotent, server saatli.
create or replace function public.activate_launch_premium_promo()
returns table (
  promo_status text,
  promo_started_at timestamptz,
  promo_expires_at timestamptz,
  days_left integer,
  activated boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_months int;
  v_started timestamptz;
  v_expires timestamptz;
  v_status text;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  perform public.ensure_my_entitlement();
  v_months := public.app_config_int('premium_promo_months', 3);

  select e.promo_status, e.promo_started_at, e.promo_expires_at
  into v_status, v_started, v_expires
  from public.user_entitlements e
  where e.owner_id = v_uid
  for update;

  if v_status = 'active' and v_expires > now() then
    return query select
      v_status, v_started, v_expires,
      ceil(extract(epoch from (v_expires - now())) / 86400.0)::int,
      false;
    return;
  end if;

  if v_status in ('active', 'used') or v_started is not null then
    update public.user_entitlements e
      set promo_status = case
          when e.promo_expires_at is not null and e.promo_expires_at <= now()
          then 'expired' else e.promo_status end,
          updated_at = now()
      where e.owner_id = v_uid;
    select e.promo_status, e.promo_started_at, e.promo_expires_at
      into v_status, v_started, v_expires
      from public.user_entitlements e
      where e.owner_id = v_uid;
    return query select v_status, v_started, v_expires, 0, false;
    return;
  end if;

  v_started := now();
  v_expires := v_started + make_interval(months => v_months);

  update public.user_entitlements e
    set promo_status = 'active',
        promo_started_at = v_started,
        promo_expires_at = v_expires,
        source = 'system',
        updated_at = now()
    where e.owner_id = v_uid
      and e.promo_status = 'not_started'
      and e.promo_started_at is null;

  return query select
    'active'::text,
    v_started,
    v_expires,
    ceil(extract(epoch from (v_expires - now())) / 86400.0)::int,
    true;
end;
$$;
revoke execute on function public.activate_launch_premium_promo()
  from public, anon;
grant execute on function public.activate_launch_premium_promo()
  to authenticated;

-- Gates: yeni iş modeli tüm ücretli iş özelliklerini Premium yapar. Eski Pro
-- transactionları kayıtta kalır ve geriye dönük uyumluluk için Premium açar.
create or replace function public.has_business_feature(
  p_owner_id uuid,
  p_feature text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_plan text;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  return case p_feature
    when 'branches' then v_plan = 'premium'
    when 'dealer_driver_ops' then v_plan = 'premium'
    when 'debt_expense' then v_plan = 'premium'
    else false
  end;
end;
$$;
revoke execute on function public.has_business_feature(uuid, text)
  from public, anon;
grant execute on function public.has_business_feature(uuid, text)
  to authenticated, service_role;

create or replace function public.can_add_dealer(p_owner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then return true; end if;
  return public.current_business_plan(p_owner_id) = 'premium';
end;
$$;
revoke execute on function public.can_add_dealer(uuid) from public, anon;
grant execute on function public.can_add_dealer(uuid)
  to authenticated, service_role;

create or replace function public.can_add_recipe(p_owner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_count int;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then return true; end if;
  if public.current_business_plan(p_owner_id) = 'premium' then return true; end if;
  select count(*) into v_count
    from public.recipe_calculations where owner_id = p_owner_id;
  return v_count < 5;
end;
$$;
revoke execute on function public.can_add_recipe(uuid) from public, anon;
grant execute on function public.can_add_recipe(uuid)
  to authenticated, service_role;

create or replace function public.supplier_product_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 else 1 end;
$$;
revoke execute on function public.supplier_product_limit(uuid)
  from public, anon;
grant execute on function public.supplier_product_limit(uuid)
  to authenticated, service_role;

create or replace function public.supplier_campaign_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 else 0 end;
$$;
revoke execute on function public.supplier_campaign_limit(uuid)
  from public, anon;
grant execute on function public.supplier_campaign_limit(uuid)
  to authenticated, service_role;

create or replace function public.supplier_monthly_reply_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 else 3 end;
$$;
revoke execute on function public.supplier_monthly_reply_limit(uuid)
  from public, anon;
grant execute on function public.supplier_monthly_reply_limit(uuid)
  to authenticated, service_role;

drop function if exists public.my_entitlement();
create function public.my_entitlement()
returns table (
  plan text,
  effective_plan text,
  is_trial_active boolean,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  days_left int,
  recipe_limit int,
  dealer_limit int,
  can_use_branches boolean,
  can_use_debt_expense boolean,
  can_use_dealer_driver_ops boolean,
  supplier_effective_plan text,
  supplier_product_limit int,
  supplier_campaign_limit int,
  supplier_monthly_reply_limit int,
  supplier_can_add_product boolean,
  supplier_can_add_campaign boolean,
  supplier_can_reply_quote boolean,
  supplier_listing_fee_exempt boolean,
  promo_status text,
  promo_started_at timestamptz,
  promo_expires_at timestamptz,
  can_start_promo boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select
      public.current_business_plan(auth.uid()) as eff,
      e.plan as actual,
      e.promo_status,
      e.promo_started_at,
      e.promo_expires_at,
      p.account_type as acct
    from (select auth.uid() as id) x
    left join public.user_entitlements e on e.owner_id = x.id
    left join public.profiles p on p.id = x.id
  )
  select
    coalesce(me.actual, 'free'),
    me.eff,
    (me.promo_status = 'active' and me.promo_expires_at > now()),
    me.promo_started_at,
    me.promo_expires_at,
    case when me.promo_status = 'active' and me.promo_expires_at > now()
      then ceil(extract(epoch from (me.promo_expires_at - now())) / 86400.0)::int
      else 0 end,
    case me.eff when 'premium' then -1 else 5 end,
    case me.eff when 'premium' then -1 else 0 end,
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
      and public.effective_supplier_plan(auth.uid()) = 'premium'),
    coalesce(me.promo_status, 'not_started'),
    me.promo_started_at,
    me.promo_expires_at,
    coalesce(me.promo_status, 'not_started') = 'not_started'
      and me.promo_started_at is null
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;

-- Yeni sade Premium ürünleri + eski ID backward compatibility.
create or replace function public.store_product_mapping(p_product_id text)
returns table (account_type text, plan text, kind text)
language sql
immutable
security definer
set search_path = ''
as $$
  select m.account_type, m.plan, m.kind from (values
    ('firinnet_premium_monthly',          null,         'premium', 'subscription'),
    ('firinnet_premium_yearly',           null,         'premium', 'subscription'),
    ('firinnet_bakery_pro_monthly',       'commercial', 'premium', 'subscription'),
    ('firinnet_bakery_premium_monthly',   'commercial', 'premium', 'subscription'),
    ('firinnet_supplier_pro_monthly',     'wholesaler', 'premium', 'subscription'),
    ('firinnet_supplier_premium_monthly', 'wholesaler', 'premium', 'subscription'),
    ('firinnet_listing_fee_50',           null,         null,      'listing_fee')
  ) as m(product_id, account_type, plan, kind)
  where m.product_id = p_product_id;
$$;
revoke execute on function public.store_product_mapping(text) from public, anon;
grant execute on function public.store_product_mapping(text)
  to authenticated, service_role;

-- apply_store_subscription: yeni null account_type product tüm commercial/
-- wholesaler hesaplarda çalışır; individual için subscription yok.
drop function if exists public.apply_store_subscription(
  uuid, text, text, text, text, text, text, timestamptz, uuid, jsonb
);
create or replace function public.apply_store_subscription(
  p_user_id uuid,
  p_product_id text,
  p_status text,
  p_store text default null,
  p_environment text default null,
  p_transaction_id text default null,
  p_original_transaction_id text default null,
  p_expires_at timestamptz default null,
  p_event_timestamp_ms bigint default null,
  p_event_id uuid default null,
  p_raw jsonb default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_plan text;
  v_kind text;
  v_user_acct text;
  v_effective_acct text;
  v_active boolean;
  v_existing_status text;
  v_existing_expires_at timestamptz;
  v_existing_transaction_id text;
  v_existing_event_timestamp_ms bigint;
begin
  select account_type, plan, kind into v_acct, v_plan, v_kind
  from public.store_product_mapping(p_product_id);
  if v_kind is distinct from 'subscription' then
    return 'ignored_not_subscription';
  end if;

  select account_type into v_user_acct from public.profiles where id = p_user_id;
  if v_user_acct not in ('commercial', 'wholesaler') then
    return 'ignored_not_business_account';
  end if;
  if v_acct is not null and v_user_acct is distinct from v_acct then
    return 'ignored_wrong_account_type';
  end if;
  v_effective_acct := coalesce(v_acct, v_user_acct);
  v_active := (p_status = 'active');

  select status, expires_at, transaction_id, last_event_timestamp_ms
    into
      v_existing_status,
      v_existing_expires_at,
      v_existing_transaction_id,
      v_existing_event_timestamp_ms
  from public.store_subscription_transactions
  where user_id = p_user_id and product_id = p_product_id;

  -- RevenueCat webhook events can arrive more than once or out of order.
  -- Official event_timestamp_ms plus transaction id prevents old active events
  -- from reopening refunded periods while allowing a newer transaction to open.
  if p_event_timestamp_ms is not null
     and v_existing_event_timestamp_ms is not null
     and p_event_timestamp_ms < v_existing_event_timestamp_ms then
    return 'ignored_stale_subscription_event';
  end if;

  if v_existing_status = 'refunded'
     and p_status = 'active'
     and p_transaction_id is not null
     and p_transaction_id = v_existing_transaction_id then
    return 'ignored_refunded_transaction';
  end if;

  -- Also protect against an old expiration/refund for a previous period closing
  -- a newer active period if provider timestamps are unavailable.
  if v_existing_status = 'active'
     and v_existing_expires_at is not null
     and p_expires_at is not null
     and v_existing_expires_at > p_expires_at
     and v_existing_expires_at > now() then
    return 'ignored_stale_subscription_event';
  end if;

  insert into public.store_subscription_transactions
    (user_id, account_type, plan, product_id, store, environment,
     transaction_id, original_transaction_id, status, purchased_at,
     expires_at, cancelled_at, last_event_id, last_event_timestamp_ms,
     raw_payload)
  values (p_user_id, v_effective_acct, v_plan, p_product_id, p_store,
     p_environment, p_transaction_id, p_original_transaction_id, p_status,
     case when v_active then now() else null end, p_expires_at,
     case when v_active then null else now() end, p_event_id,
     p_event_timestamp_ms, p_raw)
  on conflict (user_id, product_id) do update set
    status = excluded.status,
    plan = excluded.plan,
    expires_at = excluded.expires_at,
    transaction_id = coalesce(excluded.transaction_id,
      store_subscription_transactions.transaction_id),
    cancelled_at = case when excluded.status = 'active' then null else now() end,
    last_event_id = excluded.last_event_id,
    last_event_timestamp_ms = coalesce(excluded.last_event_timestamp_ms,
      store_subscription_transactions.last_event_timestamp_ms),
    raw_payload = coalesce(excluded.raw_payload,
      store_subscription_transactions.raw_payload),
    updated_at = now();

  if v_active then
    update public.user_entitlements set
      plan = v_plan, source = 'iap',
      current_period_started_at = now(),
      current_period_ends_at = p_expires_at,
      updated_at = now()
    where owner_id = p_user_id;
    if not found then
      insert into public.user_entitlements
        (owner_id, plan, source, current_period_started_at,
         current_period_ends_at)
      values (p_user_id, v_plan, 'iap', now(), p_expires_at);
    end if;
    return 'applied_active_' || v_plan;
  end if;

  if exists (
    select 1 from public.store_subscription_transactions s
    where s.user_id = p_user_id
      and s.product_id <> p_product_id
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    return 'ignored_other_active_subscription';
  end if;

  update public.user_entitlements set
    plan = 'free', source = 'iap',
    current_period_ends_at = p_expires_at, updated_at = now()
  where owner_id = p_user_id;
  return 'applied_downgrade_free';
end;
$$;
revoke execute on function public.apply_store_subscription(
  uuid, text, text, text, text, text, text, timestamptz, bigint, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_store_subscription(
  uuid, text, text, text, text, text, text, timestamptz, bigint, uuid, jsonb)
  to service_role;

-- 3) Listing free launch + expiry lifecycle.
alter table public.job_offer_posts
  add column if not exists expires_at timestamptz;
alter table public.market_listings
  add column if not exists expires_at timestamptz;

create index if not exists job_offer_posts_active_expiry_idx
  on public.job_offer_posts (expires_at, created_at desc)
  where is_active = true;
create index if not exists market_listings_active_expiry_idx
  on public.market_listings (expires_at, created_at desc)
  where status = 'active' and is_deleted = false;

alter table public.market_listings
  drop constraint if exists market_listings_status_check;
alter table public.market_listings
  drop constraint if exists market_listings_status_chk;
alter table public.market_listings
  add constraint market_listings_status_chk
  check (status in ('active', 'sold', 'paused', 'expired'));

create or replace function public.is_listing_payment_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.app_config_bool('listing_payments_enabled', false)
    and now() >= public.app_config_timestamptz(
      'listing_free_until',
      'infinity'::timestamptz
    );
$$;
revoke execute on function public.is_listing_payment_enabled()
  from public, anon;
grant execute on function public.is_listing_payment_enabled()
  to authenticated, service_role;

create or replace function public.get_listing_fee_amount_cents(
  p_owner_id uuid,
  p_listing_type text
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_listing_type = 'job_seek' then return 0; end if;
  if not public.is_listing_payment_enabled() then return 0; end if;
  return 5000;
end;
$$;
revoke execute on function public.get_listing_fee_amount_cents(uuid, text)
  from public, anon;
grant execute on function public.get_listing_fee_amount_cents(uuid, text)
  to authenticated, service_role;

create or replace function public.normalize_listing_fee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
  v_fee int;
  v_days int;
begin
  if current_setting('app.listing_fee_admin', true) = 'on' then
    return new;
  end if;

  v_kind := case tg_table_name
    when 'job_offer_posts' then 'job_offer'
    when 'market_listings' then 'market'
    else 'market'
  end;
  v_days := public.app_config_int('listing_max_active_days', 30);

  if tg_op = 'INSERT' then
    v_fee := public.get_listing_fee_amount_cents(new.owner_id, v_kind);
    -- Client expires_at degeri guvenilmez; yeni ilanin suresini server belirler.
    new.expires_at := now() + make_interval(days => v_days);
    new.fee_currency := 'TRY';
    new.paid_at := null;
    new.payment_reference := null;
    if v_fee = 0 then
      new.fee_required := false;
      new.fee_amount_cents := 0;
      new.fee_status := case
        when public.is_listing_payment_enabled() then 'not_required'
        else 'waived'
      end;
    else
      new.fee_required := true;
      new.fee_amount_cents := v_fee;
      new.fee_status := 'pending';
    end if;
    return new;
  end if;

  new.expires_at := old.expires_at;
  new.fee_required := old.fee_required;
  new.fee_amount_cents := old.fee_amount_cents;
  new.fee_currency := old.fee_currency;
  new.fee_status := old.fee_status;
  new.paid_at := old.paid_at;
  new.payment_reference := old.payment_reference;
  return new;
end;
$$;
revoke execute on function public.normalize_listing_fee()
  from public, anon, authenticated;

drop trigger if exists trg_normalize_listing_fee on public.job_offer_posts;
create trigger trg_normalize_listing_fee
before insert or update on public.job_offer_posts
for each row execute function public.normalize_listing_fee();

drop trigger if exists trg_normalize_listing_fee on public.market_listings;
create trigger trg_normalize_listing_fee
before insert or update on public.market_listings
for each row execute function public.normalize_listing_fee();

drop policy if exists job_offer_posts_select_active_or_own
  on public.job_offer_posts;
create policy job_offer_posts_select_active_or_own on public.job_offer_posts
  for select
  using (
    ((is_active = true)
      and (fee_status <> 'pending')
      and (expires_at is null or expires_at > now()))
    or (owner_id = auth.uid())
  );

drop policy if exists market_listings_select_active_or_own
  on public.market_listings;
create policy market_listings_select_active_or_own on public.market_listings
  for select
  using (
    ((status = 'active')
      and (is_deleted = false)
      and (fee_status <> 'pending')
      and (expires_at is null or expires_at > now()))
    or (owner_id = auth.uid())
  );

create or replace function public.expire_old_listings()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done int := 0;
  v_part int := 0;
begin
  perform set_config('app.listing_fee_admin', 'on', true);
  update public.job_offer_posts
    set is_active = false, updated_at = now()
    where is_active = true
      and expires_at is not null
      and expires_at <= now();
  get diagnostics v_part = row_count;
  v_done := v_done + v_part;

  update public.market_listings
    set status = 'expired', updated_at = now()
    where status = 'active'
      and is_deleted = false
      and expires_at is not null
      and expires_at <= now();
  get diagnostics v_part = row_count;
  v_done := v_done + v_part;
  perform set_config('app.listing_fee_admin', 'off', true);
  return v_done;
end;
$$;
revoke execute on function public.expire_old_listings()
  from public, anon, authenticated;
grant execute on function public.expire_old_listings() to service_role;

create or replace function public.republish_listing(
  p_listing_kind text,
  p_listing_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_days int := public.app_config_int('listing_max_active_days', 30);
  v_done int := 0;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  perform set_config('app.listing_fee_admin', 'on', true);
  if p_listing_kind = 'job_offer' then
    update public.job_offer_posts
      set is_active = true,
          expires_at = now() + make_interval(days => v_days),
          updated_at = now()
      where id = p_listing_id and owner_id = v_uid;
  elsif p_listing_kind = 'market' then
    update public.market_listings
      set status = 'active',
          is_deleted = false,
          expires_at = now() + make_interval(days => v_days),
          updated_at = now()
      where id = p_listing_id and owner_id = v_uid;
  else
    raise exception 'invalid listing kind';
  end if;
  get diagnostics v_done = row_count;
  perform set_config('app.listing_fee_admin', 'off', true);
  return v_done > 0;
end;
$$;
revoke execute on function public.republish_listing(text, uuid)
  from public, anon;
grant execute on function public.republish_listing(text, uuid)
  to authenticated;

-- Existing visible listings get an expiry value for deterministic future
-- behavior, but old creation dates are not used to retroactively hide them.
select set_config('app.listing_fee_admin', 'on', true);
update public.job_offer_posts
  set expires_at = coalesce(expires_at, now() + interval '30 days')
  where expires_at is null;
update public.market_listings
  set expires_at = coalesce(expires_at, now() + interval '30 days')
  where expires_at is null;
select set_config('app.listing_fee_admin', 'off', true);
