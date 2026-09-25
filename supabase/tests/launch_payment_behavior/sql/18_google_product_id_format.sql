-- Google Play 'productId:basePlanId' formatı: mapping + apply_store_subscription
-- her iki formatı AYNI ürüne çözer; guard'lar format karışımında da çalışır.

-- Taze test kullanıcıları (21 ticari, 22 toptancı, 23 ticari).
do $$
begin
  insert into auth.users (id) values
    ('00000000-0000-4000-8000-000000000021'),
    ('00000000-0000-4000-8000-000000000022'),
    ('00000000-0000-4000-8000-000000000023')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type) values
      ('00000000-0000-4000-8000-000000000021', 'Ticari Yirmibir', 'commercial'),
      ('00000000-0000-4000-8000-000000000022', 'Toptancı Yirmiiki', 'wholesaler'),
      ('00000000-0000-4000-8000-000000000023', 'Ticari Yirmiüç', 'commercial')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type) values
      ('00000000-0000-4000-8000-000000000021', 'commercial'),
      ('00000000-0000-4000-8000-000000000022', 'wholesaler'),
      ('00000000-0000-4000-8000-000000000023', 'commercial')
    on conflict do nothing;
  end;
end
$$;

set role service_role;

-- G1) Mapping: suffix'li, plain ve legacy id'ler doğru çözülür;
--     listing fee bozulmadı.
do $$
declare
  v_plan text;
  v_kind text;
begin
  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_premium_monthly:monthly');
  if v_plan is distinct from 'premium'
     or v_kind is distinct from 'subscription' then
    raise exception 'G1a: suffix''li premium monthly çözülmedi (%/%)',
      v_plan, v_kind;
  end if;

  -- Yıllık ürünün aktif base planı "annual" (eski "yearly" devre dışı);
  -- normalizasyon base plan kimliğinden bağımsızdır, ikisi de çözülür.
  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_premium_yearly:annual');
  if v_plan is distinct from 'premium'
     or v_kind is distinct from 'subscription' then
    raise exception 'G1b: suffix''li premium yearly (annual) çözülmedi';
  end if;

  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_premium_yearly:yearly');
  if v_plan is distinct from 'premium'
     or v_kind is distinct from 'subscription' then
    raise exception 'G1b2: eski yearly base plan kimliği çözülmedi';
  end if;

  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_premium_monthly');
  if v_plan is distinct from 'premium'
     or v_kind is distinct from 'subscription' then
    raise exception 'G1c: plain premium monthly bozuldu';
  end if;

  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_supplier_pro_monthly');
  if v_plan is distinct from 'premium'
     or v_kind is distinct from 'subscription' then
    raise exception 'G1d: legacy supplier id bozuldu';
  end if;

  select plan, kind into v_plan, v_kind
  from public.store_product_mapping('firinnet_listing_fee_50');
  if v_kind is distinct from 'listing_fee' then
    raise exception 'G1e: listing fee mapping bozuldu (%)', v_kind;
  end if;

  if exists (select 1 from public.store_product_mapping('unknown:monthly')) then
    raise exception 'G1f: bilinmeyen ürün eşleşti';
  end if;
  raise notice 'PASS 18-G1 mapping her iki format';
end
$$;

-- G2) Suffix'li id ile Premium açılır; satır NORMALİZE kimlikle yazılır;
--     plain id ile gelen eski olay AYNI satırın stale guard'ına takılır.
do $$
declare
  v_u uuid := '00000000-0000-4000-8000-000000000021';
  v_res text;
  v_cnt int;
begin
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-T1', 'G-T1', now() + interval '30 days', 1000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G2a: % (applied_active_premium bekleniyordu)', v_res;
  end if;
  if public.current_business_plan(v_u) <> 'premium' then
    raise exception 'G2b: suffix''li satın alma premium açmadı';
  end if;

  select count(*) into v_cnt
  from public.store_subscription_transactions
  where user_id = v_u and product_id = 'firinnet_premium_monthly';
  if v_cnt <> 1 then
    raise exception 'G2c: satır normalize kimlikle yazılmadı (cnt=%)', v_cnt;
  end if;
  if exists (select 1 from public.store_subscription_transactions
             where user_id = v_u and position(':' in product_id) > 0) then
    raise exception 'G2d: suffix''li product_id satırı oluştu';
  end if;

  -- Plain formatlı ESKİ olay → aynı satır, stale guard.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly', 'active', 'play_store', 'production',
    'G-T1', 'G-T1', now() + interval '30 days', 500, null, null);
  if v_res <> 'ignored_stale_subscription_event' then
    raise exception 'G2e: % (format karışımında stale guard çalışmadı)', v_res;
  end if;

  select count(*) into v_cnt
  from public.store_subscription_transactions
  where user_id = v_u
    and public.store_normalize_product_id(product_id)
        = 'firinnet_premium_monthly';
  if v_cnt <> 1 then
    raise exception 'G2f: ürün başına tekillik bozuldu (cnt=%)', v_cnt;
  end if;
  raise notice 'PASS 18-G2 suffix''li açılış + format karışımı tekillik';
end
$$;

-- G3) Refund (plain id) suffix'li açılan dönemi kapatır; suffix'li replay
--     dönemi yeniden AÇAMAZ; tx'siz sync snapshot da açamaz.
do $$
declare
  v_u uuid := '00000000-0000-4000-8000-000000000021';
  v_res text;
begin
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly', 'refunded', 'play_store', 'production',
    'G-T1', 'G-T1', now() + interval '30 days', 2000, null, null);
  if v_res <> 'applied_downgrade_free' then
    raise exception 'G3a: % (refund kapatmadı)', v_res;
  end if;
  if public.current_business_plan(v_u) <> 'free' then
    raise exception 'G3b: refund sonrası plan free değil';
  end if;

  -- Aynı tx'in suffix'li active replay'i → refunded guard.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-T1', 'G-T1', now() + interval '30 days', 3000, null, null);
  if v_res <> 'ignored_refunded_transaction' then
    raise exception 'G3c: % (suffix''li replay refund dönemini açtı!)', v_res;
  end if;

  -- Sync snapshot (tx/timestamp yok, aynı expires, suffix'li) → açılmaz.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', null, null, now() + interval '30 days', null, null, null);
  if v_res <> 'ignored_refunded_transaction' then
    raise exception 'G3d: % (suffix''li snapshot refund dönemini açtı!)', v_res;
  end if;
  if public.current_business_plan(v_u) <> 'free' then
    raise exception 'G3e: refund sonrası erişim yeniden açıldı';
  end if;

  -- Gerçek yeni satın alma (yeni tx + yeni ts, suffix'li) → açılır.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-T2', 'G-T2', now() + interval '60 days', 4000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G3f: % (yeni satın alma açılmadı)', v_res;
  end if;
  raise notice 'PASS 18-G3 refund + replay/snapshot koruması';
end
$$;

-- G4) Aylık↔yıllık format karışımıyla: yıllık plain, aylık suffix'li;
--     eski aylık active dönemi kısaltamaz, aylık kapanınca yıllık korunur.
do $$
declare
  v_u uuid := '00000000-0000-4000-8000-000000000023';
  v_res text;
  v_m_exp timestamptz := now() + interval '30 days';
  v_y_exp timestamptz := now() + interval '365 days';
  v_ends timestamptz;
begin
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-M1', 'G-M1', v_m_exp, 1000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G4a: %', v_res;
  end if;

  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_yearly', 'active', 'play_store', 'production',
    'G-Y1', 'G-Y1', v_y_exp, 2000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G4b: %', v_res;
  end if;
  select current_period_ends_at into v_ends
  from public.user_entitlements where owner_id = v_u;
  if v_ends is distinct from v_y_exp then
    raise exception 'G4c: yıllık sonrası dönem sonu yıllık değil (%)', v_ends;
  end if;

  -- Aylığın suffix'li daha yeni active olayı dönemi KISALTAMAZ.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-M1', 'G-M1', v_m_exp, 3000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G4d: %', v_res;
  end if;
  select current_period_ends_at into v_ends
  from public.user_entitlements where owner_id = v_u;
  if v_ends is distinct from v_y_exp then
    raise exception 'G4e: aylık suffix''li olay dönemi kısalttı (%)', v_ends;
  end if;

  -- Aylık (suffix'li) süresinde kapanır → yıllık (plain satır) korunur.
  v_res := public.apply_store_subscription(
    v_u, 'firinnet_premium_monthly:monthly', 'expired', 'play_store',
    'production', null, null, v_m_exp, 4000, null, null);
  if v_res <> 'ignored_other_active_subscription' then
    raise exception 'G4f: % (ignored_other_active bekleniyordu)', v_res;
  end if;
  if public.current_business_plan(v_u) <> 'premium'
     or (select current_period_ends_at from public.user_entitlements
         where owner_id = v_u) is distinct from v_y_exp then
    raise exception 'G4g: aylık kapanınca yıllık erişim bozuldu';
  end if;
  raise notice 'PASS 18-G4 aylık↔yıllık format karışımı';
end
$$;

-- G5) Hesap tipi kuralları suffix'li id'lerde de aynen çalışır:
--     toptancı bakery ürününü alamaz, ticari supplier ürününü alamaz;
--     toptancı kendi (suffix'li) ürünüyle premium açar; listing fee
--     subscription olarak uygulanmaz.
do $$
declare
  v_w uuid := '00000000-0000-4000-8000-000000000022';
  v_c uuid := '00000000-0000-4000-8000-000000000021';
  v_res text;
begin
  v_res := public.apply_store_subscription(
    v_w, 'firinnet_bakery_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-W1', 'G-W1', now() + interval '30 days', 1000, null, null);
  if v_res <> 'ignored_wrong_account_type' then
    raise exception 'G5a: % (toptancı bakery ürününü aldı!)', v_res;
  end if;

  v_res := public.apply_store_subscription(
    v_c, 'firinnet_supplier_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-W2', 'G-W2', now() + interval '30 days', 1000, null, null);
  if v_res <> 'ignored_wrong_account_type' then
    raise exception 'G5b: % (ticari supplier ürününü aldı!)', v_res;
  end if;

  v_res := public.apply_store_subscription(
    v_w, 'firinnet_supplier_premium_monthly:monthly', 'active', 'play_store',
    'production', 'G-W3', 'G-W3', now() + interval '30 days', 2000, null, null);
  if v_res <> 'applied_active_premium' then
    raise exception 'G5c: % (toptancı kendi ürünüyle açamadı)', v_res;
  end if;
  if public.current_business_plan(v_w) <> 'premium' then
    raise exception 'G5d: toptancı premium açılmadı';
  end if;

  v_res := public.apply_store_subscription(
    v_c, 'firinnet_listing_fee_50', 'active', 'play_store', 'production',
    'G-L1', 'G-L1', null, 5000, null, null);
  if v_res <> 'ignored_not_subscription' then
    raise exception 'G5e: % (listing fee subscription sanıldı)', v_res;
  end if;
  raise notice 'PASS 18-G5 hesap tipi + listing fee kuralları';
end
$$;

reset role;
