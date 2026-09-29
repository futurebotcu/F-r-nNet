-- İş kuyruğu: dedupe, lease, devralma, sınırlı retry, dead, kullanım sayacı.
set role service_role;
do $$
declare
  v_id bigint;
  v_null bigint;
  j record;
  n int;
  v bigint;
begin
  -- Dedupe: aynı anahtar ikinci kez kuyruklanmaz.
  v_id := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k1', 2);
  if v_id is null then raise exception 'Q1a: ilk enqueue null'; end if;
  v_null := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k1', 2);
  if v_null is not null then raise exception 'Q1b: dedupe delinmiş'; end if;
  select count(*) into n from public.academy_jobs
    where dedupe_key = 'dedupe-k1';
  if n <> 1 then raise exception 'Q1c: dedupe satır sayısı %', n; end if;

  -- Claim: w1 alır (running, attempts 1); w2 boş döner (lease).
  select * into j from public.academy_claim_jobs('w1', 5, 60);
  if j.id is distinct from v_id or j.attempts <> 1
     or j.status <> 'running' then
    raise exception 'Q2a: claim yanlış: %', j;
  end if;
  select count(*) into n from public.academy_claim_jobs('w2', 5, 60);
  if n <> 0 then raise exception 'Q2b: lease altındaki iş ikinci kez alındı';
  end if;

  -- Süresi geçen lease → w2 devralır (attempts 2).
  update public.academy_jobs set lease_until = now() - interval '1 second'
    where id = v_id;
  select * into j from public.academy_claim_jobs('w2', 5, 60);
  if j.id is distinct from v_id or j.attempts <> 2 then
    raise exception 'Q2c: bayat lease devralınamadı: %', j;
  end if;

  -- attempts(2) >= max_attempts(2) → failed artık DEAD (kaybolmaz).
  if public.academy_complete_job(v_id, 'failed', 'boom', 60, 'w2')
     <> 'dead' then
    raise exception 'Q3a: max attempt sonrası dead olmadı';
  end if;
  select count(*) into n from public.academy_job_runs where job_id = v_id;
  if n < 1 then raise exception 'Q3b: job_runs kaydı yok'; end if;

  -- Retry yolu: yeni iş, failed → queued + ileri run_after (backoff).
  v_id := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k2', 5);
  perform public.academy_claim_jobs('w1', 1, 60);
  if public.academy_complete_job(v_id, 'failed', 'geçici', 120, 'w1')
     <> 'queued' then
    raise exception 'Q3c: retry kuyruğa dönmedi';
  end if;
  select * into j from public.academy_jobs where id = v_id;
  if j.run_after <= now() then
    raise exception 'Q3d: backoff run_after ileri değil';
  end if;
  -- run_after gelmeden claim edilemez.
  select count(*) into n from public.academy_claim_jobs('w1', 5, 60);
  if n <> 0 then raise exception 'Q3e: backoff beklemeden claim edildi'; end if;

  -- Başarı yolu.
  update public.academy_jobs set run_after = now() where id = v_id;
  perform public.academy_claim_jobs('w1', 1, 60);
  if public.academy_complete_job(v_id, 'succeeded', null, 60, 'w1')
     <> 'succeeded' then
    raise exception 'Q3f: succeeded yolu bozuk';
  end if;

  -- Kullanım sayacı: artırımlar toplanır.
  perform public.academy_incr_usage('llm_requests', 2);
  v := public.academy_incr_usage('llm_requests', 3);
  if v <> 5 then raise exception 'Q4a: usage sayacı % (5)', v; end if;

  -- Q5: BAYAT WORKER devralınan işi complete EDEMEZ.
  v_id := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k3', 5);
  perform public.academy_claim_jobs('w-old', 1, 60);
  update public.academy_jobs set lease_until = now() - interval '1 second'
    where id = v_id;
  perform public.academy_claim_jobs('w-new', 1, 60); -- devralma
  if public.academy_complete_job(v_id, 'succeeded', null, 60, 'w-old')
     <> 'stale_worker' then
    raise exception 'Q5a: bayat worker complete edebildi';
  end if;
  select * into j from public.academy_jobs where id = v_id;
  if j.status <> 'running' or j.locked_by <> 'w-new' then
    raise exception 'Q5b: bayat complete işi bozdu: %', j;
  end if;
  if public.academy_complete_job(v_id, 'succeeded', null, 60, 'w-new')
     <> 'succeeded' then
    raise exception 'Q5c: sahip worker complete edemedi';
  end if;

  -- Q6: PARTIAL dedupe — tamamlanan iş aynı anahtarla YENİDEN kuyruklanır
  -- (dry-run→canlı, ertesi gün, anahtar-sonrası toparlanma senaryoları).
  v := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k3', 5);
  if v is null then
    raise exception 'Q6a: tamamlanan iş dedupe anahtarını kilitledi';
  end if;
  -- ama kuyruktayken hâlâ dedupe.
  if public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'dedupe-k3', 5) is not null then
    raise exception 'Q6b: kuyruktaki iş dedupe delindi';
  end if;

  -- Q7: lease heartbeat yalnız sahibine.
  perform public.academy_claim_jobs('w-hb', 1, 30);
  if not public.academy_extend_lease(v, 'w-hb', 300) then
    raise exception 'Q7a: sahip lease uzatamadı';
  end if;
  if public.academy_extend_lease(v, 'w-other', 300) then
    raise exception 'Q7b: yabancı worker lease uzatabildi';
  end if;
  perform public.academy_complete_job(v, 'succeeded', null, 60, 'w-hb');

  -- Q8 (bug #5): sınırdaki süresi-dolmuş iş DEVRALINMAZ → dead + neden.
  v := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
    'crashloop-k1', 2);
  perform public.academy_claim_jobs('w-c1', 1, 30);   -- attempts 1
  update public.academy_jobs set lease_until = now() - interval '1 second'
    where id = v;
  perform public.academy_claim_jobs('w-c2', 1, 30);   -- attempts 2 (max)
  update public.academy_jobs set lease_until = now() - interval '1 second'
    where id = v;
  select count(*) into n from public.academy_claim_jobs('w-c3', 5, 30);
  if n <> 0 then
    raise exception 'Q8a: sınır dolmuş iş yine devralındı';
  end if;
  select * into j from public.academy_jobs where id = v;
  if j.status <> 'dead'
     or j.last_error not like '%lease_expired_max_attempts%' then
    raise exception 'Q8b: çökme döngüsü dead+nedenle durmadı: %', j;
  end if;

  -- Q9 (bug #5): giderilebilir yapılandırma engeli — config_blocked işi
  -- kaybetmez, attempts sıfırlar, uzun aralıkla kuyrukta tutar.
  v := public.academy_enqueue_job('draft', '{}'::jsonb, now(), 100,
    'cfg-k1', 3);
  perform public.academy_claim_jobs('w-cfg', 1, 30);
  if public.academy_complete_job(v, 'config_blocked', 'no_llm_key', 7200,
     'w-cfg') <> 'config_blocked' then
    raise exception 'Q9a: config_blocked yolu yok';
  end if;
  select * into j from public.academy_jobs where id = v;
  if j.status <> 'queued' or j.attempts <> 0 or j.run_after <= now() then
    raise exception 'Q9b: config_blocked toparlanma durumu yanlış: %', j;
  end if;
  -- "Anahtar tanımlandı" simülasyonu: bekleme kaldır → iş işlenebilir.
  update public.academy_jobs set run_after = now() where id = v;
  select count(*) into n from public.academy_claim_jobs('w-cfg', 1, 30);
  if n <> 1 then raise exception 'Q9c: anahtar sonrası claim edilemedi';
  end if;
  perform public.academy_complete_job(v, 'succeeded', null, 60, 'w-cfg');

  -- Q10 (bug #6): cooldown — başarıdan sonra aynı anahtar yeniden üretilmez.
  v := public.academy_enqueue_job('archive_scan', '{}'::jsonb, now(), 100,
    'cool-k1', 3, 3600);
  perform public.academy_claim_jobs('w-cd', 1, 30);
  perform public.academy_complete_job(v, 'succeeded', null, 60, 'w-cd');
  if public.academy_enqueue_job('archive_scan', '{}'::jsonb, now(), 100,
     'cool-k1', 3, 3600) is not null then
    raise exception 'Q10a: cooldown delindi (haftalık iş çoğaldı)';
  end if;
  -- cooldown=0 ile (partial dedupe davranışı) yeniden üretilebilir.
  if public.academy_enqueue_job('archive_scan', '{}'::jsonb, now(), 100,
     'cool-k1', 3, 0) is null then
    raise exception 'Q10b: cooldown=0 yolu bozuldu';
  end if;

  -- Q11 (bug #5): dead-döngü koruması — 3 dead sonrası aynı anahtar
  -- yeniden kuyruklanamaz (sınır dolanılamaz).
  for n in 1..3 loop
    v := public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
      'deadloop-k1', 1);
    perform public.academy_claim_jobs('w-dl', 1, 30);
    perform public.academy_complete_job(v, 'failed', 'kalıcı hata', 60,
      'w-dl');
  end loop;
  if public.academy_enqueue_job('maintenance', '{}'::jsonb, now(), 100,
     'deadloop-k1', 1) is not null then
    raise exception 'Q11a: dead-döngü koruması yok';
  end if;

  raise notice 'PASS 03 kuyruk (lease/stale/dedupe/hb/crash/config/cooldown)';
end
$$;
reset role;
