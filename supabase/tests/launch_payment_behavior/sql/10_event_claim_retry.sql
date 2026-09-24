-- Webhook event claim/complete davranış testleri (service_role bakışıyla).
-- Başarısızlık = exception (runner ON_ERROR_STOP=1 ile koşar).
set role service_role;

-- A) Apply hatası sonrası aynı event id'nin retry'ı tek başarılı uygulamayla
--    sonuçlanır; applied olduktan sonraki teslimler yeniden işlenmez.
do $$
declare
  r record;
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
  v_started timestamptz;
  v_started2 timestamptz;
begin
  select * into r from public.claim_store_payment_event(
    'ev-retry-1', 'INITIAL_PURCHASE', v_u1, 'firinnet_premium_monthly',
    null, 'tx-r1', 'otx-r1', 'production', 'play_store', 1000,
    '{}'::jsonb, true);
  if r.should_process is distinct from true then
    raise exception 'A1: ilk claim should_process=true bekleniyordu, %',
      r.should_process;
  end if;

  -- apply patladı varsayımı → failed.
  perform public.complete_store_payment_event(
    'ev-retry-1', 'failed', 'apply:boom');

  select * into r from public.claim_store_payment_event(
    'ev-retry-1', 'INITIAL_PURCHASE', v_u1, 'firinnet_premium_monthly',
    null, 'tx-r1', 'otx-r1', 'production', 'play_store', 1000,
    '{}'::jsonb, true);
  if r.should_process is distinct from true then
    raise exception 'A2: failed sonrası retry claim reddedildi';
  end if;

  if public.apply_store_subscription(
       v_u1, 'firinnet_premium_monthly', 'active', 'play_store',
       'production', 'tx-r1', 'otx-r1', now() + interval '30 days',
       1000, null, null) <> 'applied_active_premium' then
    raise exception 'A3: apply applied_active_premium dönmedi';
  end if;
  perform public.complete_store_payment_event('ev-retry-1', 'applied');

  select current_period_started_at into v_started
  from public.user_entitlements where owner_id = v_u1;

  -- Başarılı event tekrar teslim edilirse yeniden işlenmez.
  select * into r from public.claim_store_payment_event(
    'ev-retry-1', 'INITIAL_PURCHASE', v_u1, 'firinnet_premium_monthly',
    null, 'tx-r1', 'otx-r1', 'production', 'play_store', 1000,
    '{}'::jsonb, true);
  if r.should_process then
    raise exception 'A4: applied event yeniden işleme alındı';
  end if;
  if r.current_status <> 'applied' then
    raise exception 'A5: duplicate claim status=% (applied bekleniyordu)',
      r.current_status;
  end if;

  select current_period_started_at into v_started2
  from public.user_entitlements where owner_id = v_u1;
  if v_started2 is distinct from v_started then
    raise exception 'A6: duplicate teslim ikinci yan etki üretti';
  end if;

  if (select processing_attempts from public.store_payment_events
      where provider_event_id = 'ev-retry-1') <> 2 then
    raise exception 'A7: processing_attempts 2 bekleniyordu';
  end if;
  raise notice 'PASS 10-A retry + idempotent tekrar';
end
$$;

-- B) skipped_no_secret FINAL DEĞİL: secret yapılandırılınca aynı event id
--    yeniden işlenebilir.
do $$
declare
  r record;
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
begin
  select * into r from public.claim_store_payment_event(
    'ev-nosecret-1', 'INITIAL_PURCHASE', v_u1, 'firinnet_premium_monthly',
    null, 'tx-n1', null, 'production', 'play_store', 2000,
    '{}'::jsonb, false);
  if r.should_process then
    raise exception 'B1: can_process=false iken işleme alındı';
  end if;
  if (select processing_status from public.store_payment_events
      where provider_event_id = 'ev-nosecret-1') <> 'skipped_no_secret' then
    raise exception 'B2: skipped_no_secret beklenıyordu';
  end if;

  select * into r from public.claim_store_payment_event(
    'ev-nosecret-1', 'INITIAL_PURCHASE', v_u1, 'firinnet_premium_monthly',
    null, 'tx-n1', null, 'production', 'play_store', 2000,
    '{}'::jsonb, true);
  if r.should_process is distinct from true then
    raise exception 'B3: secret geldikten sonra retry işlenemedi';
  end if;
  perform public.complete_store_payment_event('ev-nosecret-1', 'applied');
  raise notice 'PASS 10-B skipped_no_secret reclaim';
end
$$;

-- C) Taze processing kilidi başka teslimi reddeder; bayat kilit (>5 dk)
--    devralınır.
do $$
declare
  r record;
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
begin
  select * into r from public.claim_store_payment_event(
    'ev-lock-1', 'RENEWAL', v_u1, 'firinnet_premium_monthly',
    null, 'tx-l1', null, 'production', 'play_store', 3000,
    '{}'::jsonb, true);
  if r.should_process is distinct from true then
    raise exception 'C1: ilk claim başarısız';
  end if;

  select * into r from public.claim_store_payment_event(
    'ev-lock-1', 'RENEWAL', v_u1, 'firinnet_premium_monthly',
    null, 'tx-l1', null, 'production', 'play_store', 3000,
    '{}'::jsonb, true);
  if r.should_process then
    raise exception 'C2: taze kilitli event ikinci kez işleme alındı';
  end if;

  update public.store_payment_events
    set locked_at = now() - interval '6 minutes'
    where provider_event_id = 'ev-lock-1';

  select * into r from public.claim_store_payment_event(
    'ev-lock-1', 'RENEWAL', v_u1, 'firinnet_premium_monthly',
    null, 'tx-l1', null, 'production', 'play_store', 3000,
    '{}'::jsonb, true);
  if r.should_process is distinct from true then
    raise exception 'C3: bayat kilit devralınamadı';
  end if;
  if (select processing_attempts from public.store_payment_events
      where provider_event_id = 'ev-lock-1') <> 2 then
    raise exception 'C4: bayat kilit sonrası attempts=2 bekleniyordu';
  end if;
  perform public.complete_store_payment_event('ev-lock-1', 'applied');
  raise notice 'PASS 10-C kilit tazeliği + bayat kilit devralma';
end
$$;

reset role;
