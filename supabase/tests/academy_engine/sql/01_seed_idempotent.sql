-- Seed idempotency + bot metadata sözleşmeleri.
-- NOT: runner engine migration'ını İKİ KEZ uygulamıştır — sayılar teklidir.
do $$
declare n int;
begin
  select count(*) into n from public.academy_bot_profiles;
  if n <> 11 then raise exception 'A1a: bot sayısı % (11 bekleniyordu)', n;
  end if;
  select count(*) into n from auth.users
    where email like 'bot+%@firinnet.system';
  if n <> 11 then raise exception 'A1b: bot auth hesabı % (11)', n; end if;
  select count(*) into n from public.profiles where is_bot;
  if n <> 11 then raise exception 'A1c: is_bot profil % (11)', n; end if;
  select count(*) into n from public.academy_bot_settings;
  if n <> 11 then raise exception 'A1d: bot settings % (11)', n; end if;

  -- Mizah bayrakları + limitler
  if not exists (select 1 from public.academy_bot_profiles
      where bot_key = 'mizah' and is_humor and allow_dm
        and allow_self_comment and daily_post_limit = 1) then
    raise exception 'A1e: mizah bot bayrakları yanlış';
  end if;
  select count(*) into n from public.academy_bot_profiles
    where not is_humor and (allow_dm or allow_self_comment);
  if n <> 0 then
    raise exception 'A1f: akademi botunda DM/self-comment açık (%)', n;
  end if;
  select count(*) into n from public.academy_bot_profiles
    where array_length(subtopics, 1) < 2 or subtopics is null;
  if n <> 0 then raise exception 'A1g: alt konu <2 olan bot var (%)', n;
  end if;

  -- Giriş-kapalı sistem hesabı: parola/eposta token'ları boş.
  select count(*) into n from auth.users
    where email like 'bot+%@firinnet.system'
      and (coalesce(confirmation_token,'x') <> ''
           or coalesce(recovery_token,'x') <> '');
  if n <> 0 then raise exception 'A1h: bot token kolonları boş değil'; end if;

  -- Varsayılan config: kapalı + dry-run.
  if public.app_config_bool('academy_enabled', true) then
    raise exception 'A1i: academy_enabled varsayılanı true görünüyor';
  end if;
  if not public.app_config_bool('academy_dry_run', false) then
    raise exception 'A1j: academy_dry_run varsayılanı false görünüyor';
  end if;
  raise notice 'PASS 01 seed idempotent + metadata';
end
$$;
