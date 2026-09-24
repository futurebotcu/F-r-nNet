-- apply_store_subscription sıralama/refund/çoklu ürün davranış testleri.
set role service_role;

-- R1+R2) Refund sonrası: gecikmiş eski active olayı erişimi AÇMAZ; gerçek
-- yeni satın alma (yeni tx + yeni timestamp) erişimi AÇAR.
do $$
declare
  v_u2 uuid := '00000000-0000-4000-8000-000000000002';
  v_res text;
begin
  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'T1', 'T1', now() + interval '30 days', 1000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R1a: % (applied_active_premium bekleniyordu)', v_res;
  end if;

  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'refunded', 'play_store', 'production',
    'T1', 'T1', now(), 2000, null, null);
  if v_res <> 'applied_downgrade_free' then
    raise exception 'R1b: % (applied_downgrade_free bekleniyordu)', v_res;
  end if;
  if public.current_business_plan(v_u2) <> 'free' then
    raise exception 'R1c: refund sonrası plan free değil';
  end if;

  -- Gecikmiş ESKİ active (timestamp eski) → stale.
  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'T1', 'T1', now() + interval '30 days', 1000, null, null);
  if v_res <> 'ignored_stale_subscription_event' then
    raise exception 'R1d: % (ignored_stale bekleniyordu)', v_res;
  end if;

  -- Aynı tx'in daha YENİ timestamp ile replay'i → refunded tx guard.
  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'T1', 'T1', now() + interval '30 days', 3000, null, null);
  if v_res <> 'ignored_refunded_transaction' then
    raise exception 'R1e: % (ignored_refunded_transaction bekleniyordu)',
      v_res;
  end if;
  if public.current_business_plan(v_u2) <> 'free' then
    raise exception 'R1f: refund edilen dönem yeniden açıldı';
  end if;

  -- Gerçek yeni satın alma: yeni tx + yeni timestamp → açılır.
  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'T2', 'T2', now() + interval '60 days', 4000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R2a: % (yeni satın alma açılmadı)', v_res;
  end if;
  if public.current_business_plan(v_u2) <> 'premium' then
    raise exception 'R2b: yeni satın alma sonrası plan premium değil';
  end if;
  raise notice 'PASS 12-R1/R2 refund + yeni satın alma';
end
$$;

-- R3) Yenileme sonrası gecikmiş eski expiration → yeni dönem korunur.
do $$
declare
  v_u2 uuid := '00000000-0000-4000-8000-000000000002';
  v_res text;
  v_ends timestamptz;
begin
  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'T3', 'T3', now() + interval '90 days', 6000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R3a: renewal uygulanamadı: %', v_res;
  end if;
  select current_period_ends_at into v_ends
  from public.user_entitlements where owner_id = v_u2;

  v_res := public.apply_store_subscription(
    v_u2, 'firinnet_premium_monthly', 'expired', 'play_store', 'production',
    null, null, now() - interval '1 day', 5000, null, null);
  if v_res <> 'ignored_stale_subscription_event' then
    raise exception 'R3b: eski expiration stale sayılmadı: %', v_res;
  end if;
  if public.current_business_plan(v_u2) <> 'premium'
     or (select current_period_ends_at from public.user_entitlements
         where owner_id = v_u2) is distinct from v_ends then
    raise exception 'R3c: eski expiration yeni dönemi bozdu';
  end if;
  raise notice 'PASS 12-R3 renewal + eski expiration';
end
$$;

-- R4) Aylık↔yıllık: eski ürünün active olayı dönemi KISALTMAZ; aylık kapanırken
-- yıllık abonelik korunur (ignored_other_active_subscription + heal).
do $$
declare
  v_u3 uuid := '00000000-0000-4000-8000-000000000003';
  v_res text;
  v_m_exp timestamptz := now() + interval '30 days';
  v_y_exp timestamptz := now() + interval '365 days';
  v_ends timestamptz;
begin
  v_res := public.apply_store_subscription(
    v_u3, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'M1', 'M1', v_m_exp, 1000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R4a: %', v_res;
  end if;

  v_res := public.apply_store_subscription(
    v_u3, 'firinnet_premium_yearly', 'active', 'play_store', 'production',
    'Y1', 'Y1', v_y_exp, 2000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R4b: %', v_res;
  end if;
  select current_period_ends_at into v_ends
  from public.user_entitlements where owner_id = v_u3;
  if v_ends is distinct from v_y_exp then
    raise exception 'R4c: yıllık sonrası dönem sonu yıllık değil (%)', v_ends;
  end if;

  -- PRODUCT_CHANGE benzeri: aylık ürünün daha yeni active olayı gelse bile
  -- entitlement dönemi yıllığın altına inemez.
  v_res := public.apply_store_subscription(
    v_u3, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'M1', 'M1', v_m_exp, 3000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R4d: %', v_res;
  end if;
  select current_period_ends_at into v_ends
  from public.user_entitlements where owner_id = v_u3;
  if v_ends is distinct from v_y_exp then
    raise exception
      'R4e: aylık active olayı dönemi kısalttı (% / beklenen %)',
      v_ends, v_y_exp;
  end if;

  -- Aylık gerçek süresinde kapanır → yıllık geçerli abonelik korunur.
  v_res := public.apply_store_subscription(
    v_u3, 'firinnet_premium_monthly', 'expired', 'play_store', 'production',
    null, null, v_m_exp, 4000, null, null);
  if v_res <> 'ignored_other_active_subscription' then
    raise exception 'R4f: % (ignored_other_active bekleniyordu)', v_res;
  end if;
  if public.current_business_plan(v_u3) <> 'premium'
     or (select current_period_ends_at from public.user_entitlements
         where owner_id = v_u3) is distinct from v_y_exp then
    raise exception 'R4g: aylık kapanınca yıllık erişim bozuldu';
  end if;
  raise notice 'PASS 12-R4 aylık↔yıllık koruması';
end
$$;

-- R5) REST snapshot (tx id'siz / timestamp'siz sync yolu) refund edilmiş
-- dönemi yeniden AÇAMAZ; gerçek repurchase snapshot'ı (daha ileri expires)
-- açar.
do $$
declare
  v_u4 uuid := '00000000-0000-4000-8000-000000000004';
  v_res text;
  v_exp timestamptz := now() + interval '30 days';
begin
  v_res := public.apply_store_subscription(
    v_u4, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'S1', 'S1', v_exp, 1000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R5a: %', v_res;
  end if;
  v_res := public.apply_store_subscription(
    v_u4, 'firinnet_premium_monthly', 'refunded', 'play_store', 'production',
    'S1', 'S1', v_exp, 2000, null, null);
  if v_res <> 'applied_downgrade_free' then
    raise exception 'R5b: %', v_res;
  end if;

  -- Sync yarışı: refund'dan önce alınmış REST snapshot (tx/timestamp yok,
  -- expires aynı) → dönem yeniden açılmaz.
  v_res := public.apply_store_subscription(
    v_u4, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    null, null, v_exp, null, null, null);
  if v_res <> 'ignored_refunded_transaction' then
    raise exception 'R5c: % (snapshot refund dönemini açtı!)', v_res;
  end if;
  v_res := public.apply_store_subscription(
    v_u4, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    null, null, v_exp - interval '20 days', null, null, null);
  if v_res <> 'ignored_refunded_transaction' then
    raise exception 'R5d: % (daha eski snapshot dönemi açtı!)', v_res;
  end if;
  if public.current_business_plan(v_u4) <> 'free' then
    raise exception 'R5e: snapshot refund sonrası erişim açtı';
  end if;

  -- Gerçek repurchase sonrası snapshot: daha İLERİ expires → açılır.
  v_res := public.apply_store_subscription(
    v_u4, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    null, null, v_exp + interval '15 days', null, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'R5f: % (gerçek repurchase snapshot açılmadı)', v_res;
  end if;
  raise notice 'PASS 12-R5 sync snapshot refund yarışı';
end
$$;

reset role;
