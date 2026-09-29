-- Cron tetiği: kapalıyken no-op; vault yokken sessiz no-op (fail-soft).
set role service_role;
do $$
declare r text;
begin
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_enabled';
  r := public.academy_cron_tick();
  if r <> 'disabled' then
    raise exception 'C1a: kapalıyken tick % (disabled)', r;
  end if;
  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_enabled';
  r := public.academy_cron_tick();
  if r not in ('no_vault', 'no_vault_secrets') then
    raise exception 'C1b: vault''suz tick % (no_vault*)', r;
  end if;
  raise notice 'PASS 08 cron tick fail-soft';
end
$$;
reset role;
