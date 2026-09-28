-- Mizah diyalog akışları (B: yorum cevabı, C: DM cevabı, E: izinli
-- kendiliğinden DM) — gönderim-anı yeniden doğrulama + idempotency.
set role service_role;
do $$
declare
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
  v_u2 uuid := '00000000-0000-4000-8000-000000000002';
  v_mizah uuid := 'ab010000-0000-4000-8000-000000000011';
  v_botpost uuid; v_c1 uuid; v_c2 uuid; v_conv uuid;
  r record; n int;
begin
  -- Zemin: mizah botunun bir postu + u1'in üst yorumu + u2'nin cevabı.
  insert into public.feed_posts (owner_id, type, text)
    values (v_mizah, 'announcement', 'Sabah 4 alarmı') returning id
    into v_botpost;
  insert into public.feed_comments (post_id, owner_id, text)
    values (v_botpost, v_u1, 'Harika :)') returning id into v_c1;
  insert into public.feed_comments (post_id, owner_id, text,
    parent_comment_id)
    values (v_botpost, v_u2, 'Katılıyorum', v_c1) returning id into v_c2;

  -- B1) Dry-run: yorum cevabı YAZILMAZ.
  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_dry_run';
  select * into r from public.academy_humor_publish_reply(
    v_c1, 'Sağ ol usta!', 'rep-dry');
  if r.result <> 'dry_run_done' then
    raise exception 'B1a: reply dry-run: %', r.result;
  end if;
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_dry_run';

  -- B2) Üst yoruma cevap yayımlanır; tek-seviye korunur.
  select * into r from public.academy_humor_publish_reply(
    v_c1, 'Sağ ol usta!', 'rep-1');
  if r.result <> 'published' then
    raise exception 'B2a: reply: %', r.result;
  end if;
  if not exists (select 1 from public.feed_comments
      where id = r.comment_id and owner_id = v_mizah
        and parent_comment_id = v_c1) then
    raise exception 'B2b: cevap yanlış yoruma bağlandı';
  end if;

  -- B3) CEVABA cevap → üst yoruma bağlanır (tek-seviye kuralı).
  select * into r from public.academy_humor_publish_reply(
    v_c2, 'Sen de sağ ol!', 'rep-2');
  if r.result <> 'published' then
    raise exception 'B3a: %', r.result;
  end if;
  if not exists (select 1 from public.feed_comments
      where id = r.comment_id and parent_comment_id = v_c1) then
    raise exception 'B3b: cevap üst yoruma bağlanmadı';
  end if;

  -- B4) Aynı olaya ikinci cevap YOK; silinen yoruma cevap YOK.
  select * into r from public.academy_humor_publish_reply(
    v_c1, 'tekrar', 'rep-1');
  if r.result <> 'duplicate_event' then
    raise exception 'B4a: %', r.result;
  end if;
  update public.feed_comments set is_deleted = true where id = v_c1;
  select * into r from public.academy_humor_publish_reply(
    v_c1, 'geç', 'rep-3');
  if r.result <> 'comment_gone' then
    raise exception 'B4b: silinen yoruma cevap: %', r.result;
  end if;
  update public.feed_comments set is_deleted = false where id = v_c1;

  -- B5) Engel varken cevap YOK (gönderim-anı yeniden doğrulama).
  insert into public.user_blocks (blocker_id, blocked_user_id)
    values (v_u1, v_mizah);
  select * into r from public.academy_humor_publish_reply(
    v_c1, 'engelliyken', 'rep-4');
  if r.result <> 'blocked_blocked' then
    raise exception 'B5a: %', r.result;
  end if;
  delete from public.user_blocks
    where blocker_id = v_u1 and blocked_user_id = v_mizah;

  -- C) DM cevabı: kullanıcı konuşmayı başlatır, bot cevap verir.
  insert into public.conversations (type, context_type, created_by)
    values ('direct', 'profile_direct', v_u1) returning id into v_conv;
  insert into public.conversation_participants (conversation_id, user_id,
    role) values (v_conv, v_u1, 'owner'), (v_conv, v_mizah, 'member');

  -- C1) Kullanıcı mesajı YOKKEN cevap yok (boşuna takip mesajı engeli).
  select * into r from public.academy_humor_send_dm(
    v_conv, 'Merhaba!', 'dm-0', false);
  if r.result <> 'no_pending_user_message' then
    raise exception 'C1a: %', r.result;
  end if;

  insert into public.messages (conversation_id, sender_id, content)
    values (v_conv, v_u1, 'Fırın espirisi var mı?');
  select * into r from public.academy_humor_send_dm(
    v_conv, 'Var tabii: hamur beklemeyi sevmez, fırıncı bekletmeyi.',
    'dm-1', false);
  if r.result <> 'published' or r.message_id is null then
    raise exception 'C2a: DM cevabı: %', r.result;
  end if;
  if not exists (select 1 from public.messages
      where id = r.message_id and sender_id = v_mizah) then
    raise exception 'C2b: mesaj sahibi bot değil';
  end if;

  -- C3) Kullanıcı yeni mesaj yazmadan İKİNCİ cevap yok.
  select * into r from public.academy_humor_send_dm(
    v_conv, 'bir daha', 'dm-2', false);
  if r.result <> 'no_pending_user_message' then
    raise exception 'C3a: peş peşe takip mesajı: %', r.result;
  end if;

  -- E) Kendiliğinden DM: izin YOKSA red; izinle yayınlanır; izin geri
  -- çekilince durur.
  select * into r from public.academy_humor_send_dm(
    v_conv, 'kendiliğinden', 'dm-3', true);
  if r.result <> 'blocked_dm_not_opted_in' then
    raise exception 'E1a: izinsiz proaktif DM: %', r.result;
  end if;
  insert into public.academy_engagement_prefs (user_id, allow_humor_dm)
    values (v_u1, true)
    on conflict (user_id) do update set allow_humor_dm = true;
  select * into r from public.academy_humor_send_dm(
    v_conv, 'Bugün fırın nasıldı? :)', 'dm-4', true);
  if r.result <> 'published' then
    raise exception 'E2a: izinli proaktif DM: %', r.result;
  end if;
  update public.academy_engagement_prefs set allow_humor_dm = false
    where user_id = v_u1;
  select * into r from public.academy_humor_send_dm(
    v_conv, 'yine ben', 'dm-5', true);
  if r.result <> 'blocked_dm_not_opted_in' then
    raise exception 'E3a: izin geri çekildi ama DM gitti: %', r.result;
  end if;

  -- Katılımcısı olmadığı konuşmaya yazamaz.
  insert into public.conversations (type, context_type, created_by)
    values ('direct', 'profile_direct', v_u1) returning id into v_conv;
  insert into public.conversation_participants (conversation_id, user_id,
    role) values (v_conv, v_u1, 'owner'), (v_conv, v_u2, 'member');
  select * into r from public.academy_humor_send_dm(
    v_conv, 'davetsiz', 'dm-6', false);
  if r.result <> 'not_participant' then
    raise exception 'C4a: %', r.result;
  end if;

  raise notice 'PASS 09 mizah diyalogları (B/C/E)';
end
$$;
reset role;
