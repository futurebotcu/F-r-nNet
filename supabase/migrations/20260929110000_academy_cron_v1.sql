-- =============================================================================
-- Akademi cron tetiği — pg_cron → academy_cron_tick() → edge worker.
-- =============================================================================
-- push-dispatch deseniyle aynı: worker URL + bearer Vault'tan
-- (academy_worker_url / academy_worker_key). Vault secret yoksa veya
-- academy_enabled=false ise SESSİZ no-op — kurulum tamamlanmadan hiçbir
-- canlı çağrı/yayın olmaz. Kullanıcının mobil uygulaması açık olmadan
-- işletim bu zamanlayıcıyla sürer.

create or replace function public.academy_cron_tick()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_key text;
begin
  if not public.app_config_bool('academy_enabled', false) then
    return 'disabled';
  end if;
  begin
    select decrypted_secret into v_url
      from vault.decrypted_secrets where name = 'academy_worker_url';
    select decrypted_secret into v_key
      from vault.decrypted_secrets where name = 'academy_worker_key';
  exception when others then
    return 'no_vault';
  end;
  if v_url is null or v_key is null then
    return 'no_vault_secrets';
  end if;
  begin
    -- 1) Orkestrasyon (işleri kuyruklar), 2) bir parti iş tüket.
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object('Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key),
      body := jsonb_build_object('action', 'tick'));
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object('Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key),
      body := jsonb_build_object('max_jobs', 8));
  exception when others then
    return 'http_error';
  end;
  return 'triggered';
end;
$$;
revoke execute on function public.academy_cron_tick()
  from public, anon, authenticated;
grant execute on function public.academy_cron_tick() to service_role;

-- pg_cron mevcutsa 30 dakikada bir tetikle (izole test ortamında yok →
-- sessiz geç). Aynı adla yeniden schedule idempotent olsun diye önce sil.
do $$
begin
  perform cron.unschedule('academy-worker-tick');
exception when others then null;
end
$$;
do $$
begin
  perform cron.schedule('academy-worker-tick', '*/30 * * * *',
    $cron$select public.academy_cron_tick();$cron$);
exception when others then
  raise notice 'pg_cron yok (test ortamı) — schedule atlandı';
end
$$;
