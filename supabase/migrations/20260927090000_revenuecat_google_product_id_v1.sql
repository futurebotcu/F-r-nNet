-- =============================================================================
-- RevenueCat Google Play product id normalizasyonu — V1
-- =============================================================================
-- RevenueCat, Şubat 2023 sonrasında eklenen Google Play abonelik ürünlerini
-- '<subscription_id>:<base_plan_id>' formatında raporlar (webhook
-- event.product_id ve SDK StoreProduct.identifier için dokümante; REST v1
-- subscriber.subscriptions anahtar formatı dokümanda açıkça belirtilmiyor).
-- Backend eşlemesi bu yüzden ':' öncesini normalize eder: her iki format da
-- (örn. 'firinnet_premium_monthly' ve 'firinnet_premium_monthly:monthly')
-- AYNI ürüne çözülür ve store_subscription_transactions'ta AYNI satıra yazar
-- ki (user_id, product_id) tekilliği ile stale/refund/sıralama korumaları
-- format karışımında da çalışsın.
--
-- Legacy id'ler (':' içermez) ve firinnet_listing_fee_50 (consumable; Google
-- one-time ürünlerde base plan yok) değişmeden çalışır.

-- 1) Normalizasyon: ilk ':' öncesi. ':' yoksa kimlik aynen döner.
create or replace function public.store_normalize_product_id(p_product_id text)
returns text
language sql
immutable
set search_path = ''
as $$
  select split_part(p_product_id, ':', 1);
$$;
revoke execute on function public.store_normalize_product_id(text)
  from public, anon;
grant execute on function public.store_normalize_product_id(text)
  to authenticated, service_role;

-- 2) store_product_mapping: normalize edilmiş kimlikle eşler.
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
  where m.product_id = public.store_normalize_product_id(p_product_id);
$$;
revoke execute on function public.store_product_mapping(text) from public, anon;
grant execute on function public.store_product_mapping(text)
  to authenticated, service_role;

-- 3) Olası suffix'li mevcut satırları normalize et (yalnız hedef satır yoksa;
--    canlıda satın alma henüz yok, bu backfill savunmacıdır).
update public.store_subscription_transactions t
set product_id = public.store_normalize_product_id(t.product_id),
    updated_at = now()
where position(':' in t.product_id) > 0
  and not exists (
    select 1 from public.store_subscription_transactions o
    where o.user_id = t.user_id
      and o.product_id = public.store_normalize_product_id(t.product_id)
  );

-- 4) apply_store_subscription: satır anahtarı normalize edilmiş kimlik.
--    Gövde 20260923120000 sürümüyle birebir; tek fark v_product_id
--    normalizasyonu (lookup + insert + diğer-ürün karşılaştırmaları).
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
  v_product_id text := public.store_normalize_product_id(p_product_id);
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
  v_has_open_period boolean;
  v_period_ends_at timestamptz;
begin
  select account_type, plan, kind into v_acct, v_plan, v_kind
  from public.store_product_mapping(v_product_id);
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
  where user_id = p_user_id and product_id = v_product_id;

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

  -- REST snapshot (sync) çağrıları transaction id taşımayabilir. Refund
  -- sonrası, yeni dönemi KANITLAMAYAN (tx id'siz ve süresi refund edilen
  -- döneme eşit/daha kısa) bir active snapshot aynı dönemi yeniden açamaz.
  -- Gerçek yeni satın alma daha ileri bir expires_at ile gelir ve geçer.
  if v_existing_status = 'refunded'
     and p_status = 'active'
     and p_transaction_id is null
     and (p_expires_at is null
          or (v_existing_expires_at is not null
              and p_expires_at <= v_existing_expires_at)) then
    return 'ignored_refunded_transaction';
  end if;

  -- Also protect against an old expiration/refund for a previous period closing
  -- a newer active period if provider timestamps are unavailable. Yalnız
  -- timestamp'siz (REST snapshot) çağrılar için: resmi event_timestamp_ms
  -- varsa sıralamayı yukarıdaki guard belirler — daha YENİ bir REFUND/
  -- EXPIRATION olayı dönemi meşru şekilde kısaltabilmelidir.
  if (p_event_timestamp_ms is null or v_existing_event_timestamp_ms is null)
     and v_existing_status = 'active'
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
  values (p_user_id, v_effective_acct, v_plan, v_product_id, p_store,
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
    -- Aylık↔yıllık geçişte (PRODUCT_CHANGE vb.) eski ürünün active olayı
    -- entitlement dönemini KISALTAMAZ: dönem sonu, kullanıcının tüm geçerli
    -- aboneliklerinin en geniş expires_at değeridir.
    select
      bool_or(s.expires_at is null),
      max(s.expires_at)
    into v_has_open_period, v_period_ends_at
    from public.store_subscription_transactions s
    where s.user_id = p_user_id
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now());
    if coalesce(v_has_open_period, false) then
      v_period_ends_at := null;
    else
      v_period_ends_at := coalesce(v_period_ends_at, p_expires_at);
    end if;

    update public.user_entitlements set
      plan = v_plan, source = 'iap',
      current_period_started_at = now(),
      current_period_ends_at = v_period_ends_at,
      updated_at = now()
    where owner_id = p_user_id;
    if not found then
      insert into public.user_entitlements
        (owner_id, plan, source, current_period_started_at,
         current_period_ends_at)
      values (p_user_id, v_plan, 'iap', now(), v_period_ends_at);
    end if;
    return 'applied_active_' || v_plan;
  end if;

  if exists (
    select 1 from public.store_subscription_transactions s
    where s.user_id = p_user_id
      and s.product_id <> v_product_id
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    -- Diğer geçerli aboneliğin dönemini entitlement'a geri yaz (heal):
    -- entitlement daha önce yanlışlıkla kısalmışsa burada düzelir.
    select
      bool_or(s.expires_at is null),
      max(s.expires_at)
    into v_has_open_period, v_period_ends_at
    from public.store_subscription_transactions s
    where s.user_id = p_user_id
      and s.product_id <> v_product_id
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now());
    update public.user_entitlements set
      plan = 'premium', source = 'iap',
      current_period_ends_at = case
        when coalesce(v_has_open_period, false) then null
        else v_period_ends_at end,
      updated_at = now()
    where owner_id = p_user_id;
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
