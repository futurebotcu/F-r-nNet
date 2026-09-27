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

  raise notice 'PASS 03 kuyruk + lease + retry + sayaç';
end
$$;
reset role;
