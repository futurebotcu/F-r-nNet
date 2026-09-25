-- Eşzamanlılık oturumlarının (conc_*.sql) sonuç doğrulaması.
do $$
declare
  n_rows int;
  n_true int;
  v_attempts int;
  v_status text;
begin
  -- Claim: iki teslimden tam olarak BİRİ işleme alınır.
  select count(*), count(*) filter (where a = 'true')
  into n_rows, n_true
  from public.test_results where label like 'conc_claim_%';
  if n_rows <> 2 or n_true <> 1 then
    raise exception
      'CONC1: claim satır=% işlenen=% (2/1 bekleniyordu)', n_rows, n_true;
  end if;
  select processing_attempts into v_attempts
  from public.store_payment_events where provider_event_id = 'ev-conc-1';
  if v_attempts <> 1 then
    raise exception
      'CONC2: eşzamanlı teslimde attempts=% (1 bekleniyordu)', v_attempts;
  end if;

  -- Promo (ticari lansman modeli): CTA ticari hesapta yeni promo BAŞLATMAZ —
  -- eşzamanlı iki deneme de activated=false döner ve DB'ye yazmaz.
  select count(*), count(*) filter (where a = 'true')
  into n_rows, n_true
  from public.test_results where label like 'conc_promo_%';
  if n_rows <> 2 or n_true <> 0 then
    raise exception
      'CONC3: promo satır=% activated=% (2/0 bekleniyordu)', n_rows, n_true;
  end if;
  select coalesce(
    (select e.promo_status from public.user_entitlements e
     where e.owner_id = '00000000-0000-4000-8000-000000000006'),
    'not_started')
  into v_status;
  if v_status <> 'not_started' then
    raise exception 'CONC5: ticari CTA promo alanı yazdı: %', v_status;
  end if;
  raise notice 'PASS 14 eşzamanlı claim + ticari promo engeli';
end
$$;
