-- Mizah kendiliğinden yorum guard'ları: dry-run, idempotency, tercih, engel,
-- bot-bot, 72 saat, günlük sınır, silinen gönderi.
set role service_role;

-- Ek test kullanıcıları (u3, u4) — günlük sınır senaryosu için.
insert into auth.users (id, email, confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token) values
  ('00000000-0000-4000-8000-000000000003', 'u3@test.local',
   '','','','','','','',''),
  ('00000000-0000-4000-8000-000000000004', 'u4@test.local',
   '','','','','','','','')
on conflict do nothing;
insert into public.profiles (id, display_name) values
  ('00000000-0000-4000-8000-000000000003', 'Kullanıcı Üç'),
  ('00000000-0000-4000-8000-000000000004', 'Kullanıcı Dört')
on conflict do nothing;

do $$
declare
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
  v_u2 uuid := '00000000-0000-4000-8000-000000000002';
  v_mizah uuid := 'ab010000-0000-4000-8000-000000000011';
  v_bot_post_owner uuid := 'ab010000-0000-4000-8000-000000000002';
  p1 uuid; p2 uuid; pb uuid;
  r record; n int;
begin
  insert into public.feed_posts (owner_id, type, text)
    values (v_u1, 'production', 'Bugün 300 simit') returning id into p1;
  insert into public.feed_posts (owner_id, type, text)
    values (v_u2, 'production', 'Yeni vitrin') returning id into p2;
  insert into public.feed_posts (owner_id, type, text)
    values (v_bot_post_owner, 'announcement', 'Bot postu')
    returning id into pb;

  -- Dry-run: yorum da etkileşim kaydı da YOK.
  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_dry_run';
  select * into r from public.academy_humor_publish_comment(
    p1, 'Simitler taze mi? :)', 'ev-dry');
  if r.result <> 'dry_run_done' then
    raise exception 'H1a: dry-run: %', r.result;
  end if;
  select count(*) into n from public.feed_comments;
  if n <> 0 then raise exception 'H1b: dry-run yorum yazdı'; end if;
  select count(*) into n from public.academy_humor_interactions;
  if n <> 0 then raise exception 'H1c: dry-run etkileşim kaydetti'; end if;

  -- Canlı: yayınla + günlüğe yaz.
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_dry_run';
  select * into r from public.academy_humor_publish_comment(
    p1, 'Fırının sıcağına selam olsun.', 'ev-1');
  if r.result <> 'published' or r.comment_id is null then
    raise exception 'H2a: canlı yorum: %', r;
  end if;
  if not exists (select 1 from public.feed_comments
      where id = r.comment_id and owner_id = v_mizah) then
    raise exception 'H2b: yorum sahibi mizah botu değil';
  end if;

  -- Aynı olaya İKİNCİ cevap yok (webhook/tekrar koruması).
  select * into r from public.academy_humor_publish_comment(
    p1, 'tekrar', 'ev-1');
  if r.result <> 'duplicate_event' then
    raise exception 'H3a: duplicate event: %', r.result;
  end if;

  -- Aynı kullanıcıya 72 saat kuralı (yeni olay olsa bile).
  select * into r from public.academy_humor_publish_comment(
    p1, 'yine ben', 'ev-2');
  if r.result <> 'blocked_user_gap' then
    raise exception 'H3b: 72 saat kuralı: %', r.result;
  end if;

  -- Kullanıcı tercihi: kapattıysa yorum yok.
  insert into public.academy_engagement_prefs
    (user_id, allow_humor_comments) values (v_u2, false)
  on conflict (user_id) do update set allow_humor_comments = false;
  select * into r from public.academy_humor_publish_comment(
    p2, 'vitrin güzel', 'ev-3');
  if r.result <> 'blocked_user_opted_out' then
    raise exception 'H4a: tercih guard: %', r.result;
  end if;
  delete from public.academy_engagement_prefs where user_id = v_u2;

  -- Engel: kullanıcı botu engellediyse yorum yok.
  insert into public.user_blocks (blocker_id, blocked_user_id)
    values (v_u2, v_mizah);
  select * into r from public.academy_humor_publish_comment(
    p2, 'vitrin güzel', 'ev-4');
  if r.result <> 'blocked_blocked' then
    raise exception 'H4b: engel guard: %', r.result;
  end if;
  delete from public.user_blocks
    where blocker_id = v_u2 and blocked_user_id = v_mizah;

  -- Bot-bot döngüsü: hedef bot postu ise yorum yok.
  select * into r from public.academy_humor_publish_comment(
    pb, 'bot bota selam', 'ev-5');
  if r.result <> 'blocked_target_is_bot' then
    raise exception 'H5a: bot-bot guard: %', r.result;
  end if;

  -- Günlük sınır (3): bugün 1 gerçek + 2 sentetik → 4. deneme reddedilir.
  insert into public.academy_humor_interactions
    (kind, target_user_id, event_key) values
    ('comment', '00000000-0000-4000-8000-000000000003', 'ev-syn-1'),
    ('comment', '00000000-0000-4000-8000-000000000004', 'ev-syn-2');
  select * into r from public.academy_humor_publish_comment(
    p2, 'vitrin güzel', 'ev-6');
  if r.result <> 'blocked_daily_cap' then
    raise exception 'H6a: günlük sınır: %', r.result;
  end if;

  -- Silinen gönderiye yorum yok (gönderim ANINDA yeniden kontrol).
  update public.feed_posts set is_deleted = true where id = p2;
  delete from public.academy_humor_interactions
    where event_key in ('ev-syn-1', 'ev-syn-2');
  select * into r from public.academy_humor_publish_comment(
    p2, 'geç kaldım', 'ev-7');
  if r.result <> 'post_gone' then
    raise exception 'H7a: silinen gönderi guard: %', r.result;
  end if;

  raise notice 'PASS 05 mizah guard zinciri';
end
$$;
reset role;
