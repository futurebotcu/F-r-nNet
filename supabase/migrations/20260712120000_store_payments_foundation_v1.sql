-- RevenueCat + Store Billing Payment Foundation V1 (ADDITIVE).
--
-- Resmi ödeme modeli: iOS App Store IAP + Android Play Billing, orkestrasyon
-- RevenueCat, backend RevenueCat webhook + Supabase. Havale/EFT/İyzico/Stripe
-- YOK; manuel/sahte ödeme YOK. Bu migration ÖDEME ALTYAPISINI kurar; canlı
-- işlem RevenueCat secret'ları set edilince başlar (external setup pending).
--
-- Kaynak-of-truth: user_entitlements (plan) — RevenueCat entitlement adları
-- değişse bile product_id mapping burada sabittir.
--
-- Güvenlik: subscription/listing ödemesi YALNIZ service_role tarafından
-- uygulanır (webhook / doğrulanmış sync edge function). Client transaction_id'ye
-- GÜVENİLMEZ → client-facing "confirm" RPC'si YOK. Listing self-pay bypass
-- kapalı (mark yalnız service_role).
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. TABLOLAR
-- ────────────────────────────────────────────────────────────────────────

-- 1a. Webhook event log (idempotent).
create table if not exists public.store_payment_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'revenuecat',
  provider_event_id text not null unique,
  event_type text,
  app_user_id uuid,
  product_id text,
  entitlement_id text,
  transaction_id text,
  original_transaction_id text,
  environment text,
  store text,
  raw_payload jsonb not null,
  processing_status text not null default 'received',
  processing_error text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

-- 1b. Subscription durum izleme.
create table if not exists public.store_subscription_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_type text not null,
  plan text not null,
  product_id text not null,
  entitlement_id text,
  store text,
  environment text,
  transaction_id text,
  original_transaction_id text,
  status text not null,
  purchased_at timestamptz,
  expires_at timestamptz,
  cancelled_at timestamptz,
  last_event_id uuid,
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint store_sub_plan_chk check (plan in ('pro', 'premium')),
  constraint store_sub_acct_chk
    check (account_type in ('commercial', 'wholesaler')),
  constraint store_sub_status_chk check (status in (
    'active', 'expired', 'cancelled', 'refunded',
    'grace_period', 'billing_issue', 'unknown')),
  constraint store_sub_user_product_uq unique (user_id, product_id)
);

-- 1c. Ücretli ilan (50 TL) ödeme niyeti — purchase ↔ listing güvenli eşleme.
create table if not exists public.listing_payment_intents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  listing_kind text not null,
  listing_id uuid not null,
  product_id text not null default 'firinnet_listing_fee_50',
  amount_cents integer not null default 5000,
  currency text not null default 'TRY',
  status text not null default 'pending',
  provider text not null default 'revenuecat',
  provider_transaction_id text unique,
  provider_event_id uuid,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  expires_at timestamptz,
  raw_payload jsonb,
  constraint lpi_amount_chk check (amount_cents = 5000),
  constraint lpi_product_chk check (product_id = 'firinnet_listing_fee_50'),
  constraint lpi_kind_chk check (listing_kind in ('job_offer', 'market')),
  constraint lpi_status_chk check (status in (
    'pending', 'paid', 'expired', 'cancelled', 'failed', 'refunded'))
);
create index if not exists lpi_owner_listing_idx
  on public.listing_payment_intents (owner_id, listing_id, status);

drop trigger if exists trg_lpi_updated on public.listing_payment_intents;
drop trigger if exists trg_store_sub_updated
  on public.store_subscription_transactions;
create trigger trg_store_sub_updated
before update on public.store_subscription_transactions
for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────────────────
-- 2. RLS + GRANTS — client yalnız kendi geçmişini OKUR; yazma service_role.
-- ────────────────────────────────────────────────────────────────────────

alter table public.store_payment_events enable row level security;
alter table public.store_subscription_transactions enable row level security;
alter table public.listing_payment_intents enable row level security;

-- Webhook event log: client erişimi YOK (yazma policy de yok).
revoke all on public.store_payment_events from anon, authenticated;
grant select, insert, update, delete
  on public.store_payment_events to service_role;

-- Subscription geçmişi: owner SELECT; client yazma yok.
drop policy if exists store_sub_select_own
  on public.store_subscription_transactions;
create policy store_sub_select_own on public.store_subscription_transactions
  for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete
  on public.store_subscription_transactions from anon, authenticated;
grant select on public.store_subscription_transactions to authenticated;
grant select, insert, update, delete
  on public.store_subscription_transactions to service_role;

-- Listing intent: owner SELECT; client direct yazma YOK (RPC ile).
drop policy if exists lpi_select_own on public.listing_payment_intents;
create policy lpi_select_own on public.listing_payment_intents
  for select to authenticated using (owner_id = auth.uid());
revoke insert, update, delete
  on public.listing_payment_intents from anon, authenticated;
grant select on public.listing_payment_intents to authenticated;
grant select, insert, update, delete
  on public.listing_payment_intents to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 3. PRODUCT MAPPING — tek kaynak (edge + RPC paylaşır).
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.store_product_mapping(p_product_id text)
returns table (account_type text, plan text, kind text)
language sql
immutable
security definer
set search_path = ''
as $$
  select m.account_type, m.plan, m.kind from (values
    ('firinnet_bakery_pro_monthly',      'commercial', 'pro',     'subscription'),
    ('firinnet_bakery_premium_monthly',  'commercial', 'premium', 'subscription'),
    ('firinnet_supplier_pro_monthly',    'wholesaler', 'pro',     'subscription'),
    ('firinnet_supplier_premium_monthly','wholesaler', 'premium', 'subscription'),
    ('firinnet_listing_fee_50',          null,         null,      'listing_fee')
  ) as m(product_id, account_type, plan, kind)
  where m.product_id = p_product_id;
$$;
revoke execute on function public.store_product_mapping(text) from public, anon;
grant execute on function public.store_product_mapping(text)
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 4. effective_supplier_plan FIX — paid subscription trial'dan ÜSTÜN.
--    Trial aktifken paid Premium supplier Pro'ya DÜŞMESİN (prompt kuralı).
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.effective_supplier_plan(p_owner_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_trial timestamptz;
begin
  select plan, trial_ends_at into v_plan, v_trial
  from public.user_entitlements where owner_id = p_owner_id;
  if v_plan is null then
    return 'free';
  end if;
  -- Paid Premium her zaman kazanır (trial'da bile).
  if v_plan = 'premium' then
    return 'premium';
  end if;
  -- Trial aktif (ve plan free/pro) → Pro-benzeri.
  if v_trial is not null and v_trial > now() then
    return 'pro';
  end if;
  return v_plan;
end;
$$;
revoke execute on function public.effective_supplier_plan(uuid) from public, anon;
grant execute on function public.effective_supplier_plan(uuid) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 5. RPC — listing ödeme niyeti (AUTHENTICATED, owner + pending doğrular).
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.create_listing_payment_intent(
  p_listing_kind text,
  p_listing_id uuid
)
returns table (intent_id uuid, product_id text, amount_cents integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_fee_status text;
  v_existing uuid;
  v_new uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_listing_kind not in ('job_offer', 'market') then
    raise exception 'invalid listing kind';
  end if;

  -- İlan sahibi + fee_status doğrula (yalnız kendi pending ilanı).
  if p_listing_kind = 'job_offer' then
    select owner_id, fee_status into v_owner, v_fee_status
    from public.job_offer_posts where id = p_listing_id;
  else
    select owner_id, fee_status into v_owner, v_fee_status
    from public.market_listings where id = p_listing_id;
  end if;

  if v_owner is null then raise exception 'listing not found'; end if;
  if v_owner <> v_uid then raise exception 'not listing owner'; end if;
  if v_fee_status <> 'pending' then
    raise exception 'listing not awaiting payment';
  end if;

  -- Aktif pending intent varsa onu döndür (mükerrer açma yok).
  select id into v_existing from public.listing_payment_intents
  where owner_id = v_uid and listing_id = p_listing_id and status = 'pending'
  order by created_at desc limit 1;

  if v_existing is not null then
    return query select v_existing, 'firinnet_listing_fee_50'::text, 5000;
    return;
  end if;

  insert into public.listing_payment_intents
    (owner_id, listing_kind, listing_id)
  values (v_uid, p_listing_kind, p_listing_id)
  returning id into v_new;

  return query select v_new, 'firinnet_listing_fee_50'::text, 5000;
end;
$$;
revoke execute on function
  public.create_listing_payment_intent(text, uuid) from public, anon;
grant execute on function
  public.create_listing_payment_intent(text, uuid) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 6. SERVICE-ROLE — subscription uygula (webhook/sync edge çağırır).
--    Wrong account_type → entitlement DEĞİŞMEZ (ignored).
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.apply_store_subscription(
  p_user_id uuid,
  p_product_id text,
  p_status text,
  p_store text default null,
  p_environment text default null,
  p_transaction_id text default null,
  p_original_transaction_id text default null,
  p_expires_at timestamptz default null,
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
  v_active boolean;
begin
  select account_type, plan, kind into v_acct, v_plan, v_kind
  from public.store_product_mapping(p_product_id);
  if v_kind is distinct from 'subscription' then
    return 'ignored_not_subscription';
  end if;

  select account_type into v_user_acct from public.profiles
  where id = p_user_id;
  -- Yanlış account_type ürünü → entitlement değişmez.
  if v_user_acct is distinct from v_acct then
    return 'ignored_wrong_account_type';
  end if;

  v_active := (p_status = 'active');

  -- Subscription durum izleme (upsert).
  insert into public.store_subscription_transactions
    (user_id, account_type, plan, product_id, store, environment,
     transaction_id, original_transaction_id, status, purchased_at,
     expires_at, cancelled_at, last_event_id, raw_payload)
  values (p_user_id, v_acct, v_plan, p_product_id, p_store, p_environment,
     p_transaction_id, p_original_transaction_id, p_status,
     case when v_active then now() else null end, p_expires_at,
     case when v_active then null else now() end, p_event_id, p_raw)
  on conflict (user_id, product_id) do update set
    status = excluded.status,
    plan = excluded.plan,
    expires_at = excluded.expires_at,
    transaction_id = coalesce(excluded.transaction_id,
      store_subscription_transactions.transaction_id),
    cancelled_at = case when excluded.status = 'active' then null
      else now() end,
    last_event_id = excluded.last_event_id,
    raw_payload = coalesce(excluded.raw_payload,
      store_subscription_transactions.raw_payload),
    updated_at = now();

  -- Entitlement uygula. Aktif → paid plan; terminal → free (trial yeniden
  -- verilmez — trial alanlarına dokunulmaz).
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
  else
    update public.user_entitlements set
      plan = 'free', source = 'iap',
      current_period_ends_at = p_expires_at, updated_at = now()
    where owner_id = p_user_id;
    return 'applied_downgrade_free';
  end if;
end;
$$;
revoke execute on function public.apply_store_subscription(
  uuid, text, text, text, text, text, text, timestamptz, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_store_subscription(
  uuid, text, text, text, text, text, text, timestamptz, uuid, jsonb)
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 7. SERVICE-ROLE — listing ödemesini uygula (idempotent, intent üzerinden).
--    mark_listing_fee_paid mantığını reuse eder; self-pay bypass kapalı.
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.mark_listing_fee_paid_from_store(
  p_intent_id uuid,
  p_transaction_id text,
  p_event_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_kind text;
  v_listing uuid;
  v_status text;
  v_ok boolean;
begin
  select owner_id, listing_kind, listing_id, status
  into v_owner, v_kind, v_listing, v_status
  from public.listing_payment_intents where id = p_intent_id;
  if v_owner is null then return false; end if;
  -- Idempotent: zaten ödenmişse başarı say (tekrar publish yok).
  if v_status = 'paid' then return true; end if;
  if v_status <> 'pending' then return false; end if;

  update public.listing_payment_intents set
    status = 'paid', provider_transaction_id = p_transaction_id,
    provider_event_id = p_event_id, confirmed_at = now()
  where id = p_intent_id and status = 'pending';

  -- İlanı public/paid yap (mevcut service-role mark mantığı).
  v_ok := public.mark_listing_fee_paid(v_listing,
    'store:' || coalesce(p_transaction_id, ''));
  return true;
end;
$$;
revoke execute on function public.mark_listing_fee_paid_from_store(
  uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.mark_listing_fee_paid_from_store(
  uuid, text, uuid) to service_role;
