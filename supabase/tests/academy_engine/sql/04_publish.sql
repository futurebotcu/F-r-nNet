-- İdempotent yayın: dry-run guard (server-side), kill-switch, günlük sınır,
-- feed_posts+feed_media tutarlılığı, author snapshot.
set role service_role;

-- Yardımcı: taslak üret.
create or replace function pg_temp.mk_draft(
  p_bot text, p_key text, p_publishable boolean default true)
returns uuid language sql as $$
  insert into public.academy_drafts
    (bot_key, kind, title, body, tags, publishable, status, idempotency_key)
  values (p_bot, 'evergreen', 'Başlık ' || p_key, 'Gövde metni.',
          array['akademi'], p_publishable, 'media_ready', p_key)
  returning id;
$$;

do $$
declare
  d1 uuid; d2 uuid; d3 uuid; d4 uuid; dm uuid; dm2 uuid; dr uuid;
  r record; n int; v_post uuid;
begin
  d1 := pg_temp.mk_draft('ekmek_fermantasyon', 'p-d1');

  -- Kill-switch: academy_enabled=false (varsayılan) → yazma YOK.
  select * into r from public.academy_publish_draft(d1);
  if r.result <> 'blocked_academy_disabled' then
    raise exception 'P1a: kill-switch çalışmadı: %', r.result;
  end if;

  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_enabled';

  -- Dry-run (varsayılan true): kullanıcı-görünür post OLUŞMAZ.
  select * into r from public.academy_publish_draft(d1);
  if r.result <> 'dry_run_done' or r.post_id is not null then
    raise exception 'P1b: dry-run yayın yaptı: %', r;
  end if;
  select count(*) into n from public.feed_posts;
  if n <> 0 then raise exception 'P1c: dry-run feed_posts yazdı'; end if;

  -- Canlı kip.
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_dry_run';

  d2 := pg_temp.mk_draft('ekmek_fermantasyon', 'p-d2');
  insert into public.academy_media (draft_id, provider, storage_path,
    width, height, alt_text)
  values (d2, 'info_card',
    'ab010000-0000-4000-8000-000000000001/academy/' || d2 || '/card.png',
    1200, 675, 'Bilgi kartı');

  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'published' or r.post_id is null then
    raise exception 'P2a: yayın başarısız: %', r;
  end if;
  v_post := r.post_id;
  -- Author snapshot bot display_name'inden dolar; owner bot uid.
  if not exists (select 1 from public.feed_posts
      where id = v_post
        and owner_id = 'ab010000-0000-4000-8000-000000000001'
        and author_name = 'FırınNet Ekmek ve Fermantasyon'
        and type = 'announcement') then
    raise exception 'P2b: post alanları/snapshot yanlış';
  end if;
  select count(*) into n from public.feed_media where post_id = v_post;
  if n <> 1 then raise exception 'P2c: medya bağlanmadı (%)', n; end if;

  -- İdempotency: yeniden yürütme İKİNCİ post oluşturmaz.
  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'already_published' or r.post_id is distinct from v_post then
    raise exception 'P3a: idempotent değil: %', r;
  end if;
  select count(*) into n from public.feed_posts;
  if n <> 1 then raise exception 'P3b: post sayısı % (1)', n; end if;

  -- Günlük bot sınırı (cap 2): 2. yayın OK, 3. deferred.
  d3 := pg_temp.mk_draft('ekmek_fermantasyon', 'p-d3');
  select * into r from public.academy_publish_draft(d3);
  if r.result <> 'published' then
    raise exception 'P4a: 2. yayın engellendi: %', r.result;
  end if;
  d4 := pg_temp.mk_draft('ekmek_fermantasyon', 'p-d4');
  select * into r from public.academy_publish_draft(d4);
  if r.result <> 'deferred_daily_cap' then
    raise exception 'P4b: günlük sınır çalışmadı: %', r.result;
  end if;
  if not exists (select 1 from public.academy_drafts
      where id = d4 and status = 'scheduled'
        and scheduled_for is not null) then
    raise exception 'P4c: ertelenen taslak planlanmadı';
  end if;

  -- Mizah günlük sınırı 1.
  dm := pg_temp.mk_draft('mizah', 'p-m1');
  select * into r from public.academy_publish_draft(dm);
  if r.result <> 'published' then
    raise exception 'P5a: mizah yayını: %', r.result;
  end if;
  dm2 := pg_temp.mk_draft('mizah', 'p-m2');
  select * into r from public.academy_publish_draft(dm2);
  if r.result <> 'deferred_daily_cap' then
    raise exception 'P5b: mizah sınırı çalışmadı: %', r.result;
  end if;

  -- Yayına uygun değil → rejected.
  dr := pg_temp.mk_draft('un_tahil', 'p-dr', false);
  select * into r from public.academy_publish_draft(dr);
  if r.result <> 'rejected_not_publishable' then
    raise exception 'P6a: publishable guard: %', r.result;
  end if;

  raise notice 'PASS 04 yayın (dry-run/kill-switch/idempotent/sınırlar)';
end
$$;

-- P7: kullanıcı-görünür KAYNAK atfı — ad + doğrulanmış URL + ticari not +
-- haberde tarih; URL sicilden gelir (taslak gövdesinden değil).
do $$
declare
  v_src uuid; v_item uuid; v_draft uuid; r record; v_text text;
begin
  insert into public.academy_sources (slug, name, domain, is_commercial,
    topics, status)
  values ('attr_test', 'Atıf Testi Kurumu', 'attr-test.example',
    true, array['un_tahil'], 'active')
  returning id into v_src;
  insert into public.academy_content_items (source_id, canonical_url, url,
    title, published_at, content_kind, status, full_text)
  values (v_src, 'https://attr-test.example/makale-1',
    'https://attr-test.example/makale-1', 'Makale',
    '2026-09-20T08:00:00Z', 'news', 'assigned', 'metin')
  returning id into v_item;
  insert into public.academy_drafts (content_item_id, bot_key, kind, title,
    body, publishable, status, idempotency_key, date_context)
  values (v_item, 'un_tahil', 'news', 'Atıf başlığı', 'Gövde metni burada.',
    true, 'media_ready', 'p-attr', '20 Eylül 2026')
  returning id into v_draft;

  select * into r from public.academy_publish_draft(v_draft);
  if r.result <> 'published' then
    raise exception 'P7a: atıf yayını: %', r.result;
  end if;
  select text into v_text from public.feed_posts where id = r.post_id;
  if v_text not like '%Kaynak: Atıf Testi Kurumu (üretici içeriği)%' then
    raise exception 'P7b: kaynak adı/ticari not yok: %', v_text;
  end if;
  if v_text not like '%https://attr-test.example/makale-1%' then
    raise exception 'P7c: doğrulanmış kaynak URL yok';
  end if;
  if v_text not like '%Tarih: 20 Eylül 2026%' then
    raise exception 'P7d: haber tarih bağlamı yok';
  end if;
  raise notice 'PASS 04-P7 kaynak atfı';
end
$$;
reset role;
