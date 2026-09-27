-- RLS/yetki: normal kullanıcı bot adına yazamaz; motor tabloları/RPC'leri
-- client'a kapalı; tercihler yalnız kendi satırı.
begin;
select set_config('request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001', true);
set local role authenticated;
do $$
declare n int;
begin
  -- Görünür bot listesi client'a açık (11 satır).
  select count(*) into n from public.academy_bot_profiles;
  if n <> 11 then raise exception 'A2a: client bot listesi % (11)', n; end if;

  -- Motor tabloları: SELECT dahi yok.
  begin
    perform 1 from public.academy_sources limit 1;
    raise exception 'A2b: client academy_sources okuyabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.academy_bot_settings limit 1;
    raise exception 'A2c: client bot_settings (üslup promptu) okuyabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.academy_jobs limit 1;
    raise exception 'A2d: client iş kuyruğunu okuyabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.academy_drafts (bot_key, title, body, idempotency_key)
    values ('mizah', 'x', 'y', 'client-try');
    raise exception 'A2e: client taslak yazabildi';
  exception when insufficient_privilege then null;
  end;

  -- Motor RPC'leri: execute yok.
  begin
    perform public.academy_publish_draft(gen_random_uuid());
    raise exception 'A2f: client publish RPC çağırabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.academy_enqueue_job('maintenance');
    raise exception 'A2g: client enqueue RPC çağırabildi';
  exception when insufficient_privilege then null;
  end;

  -- Bot adına feed postu: RLS reddeder.
  begin
    insert into public.feed_posts (owner_id, type, text)
    values ('ab010000-0000-4000-8000-000000000011', 'announcement', 'sahte');
    raise exception 'A2h: kullanıcı bot adına post atabildi!';
  exception when insufficient_privilege then null;
  end;

  -- Tercihler: kendi satırı OK, başkası adına RED.
  insert into public.academy_engagement_prefs (user_id, allow_humor_comments)
  values ('00000000-0000-4000-8000-000000000001', false)
  on conflict (user_id) do update set allow_humor_comments = false;
  update public.academy_engagement_prefs set allow_humor_comments = true
    where user_id = '00000000-0000-4000-8000-000000000001';
  begin
    insert into public.academy_engagement_prefs (user_id)
    values ('00000000-0000-4000-8000-000000000002');
    raise exception 'A2i: başkası adına tercih yazılabildi';
  exception when insufficient_privilege then null;
  end;
  select count(*) into n from public.academy_engagement_prefs;
  if n <> 1 then raise exception 'A2j: tercih görünürlüğü % (1)', n; end if;

  raise notice 'PASS 02 RLS + yetki';
end
$$;
commit;
