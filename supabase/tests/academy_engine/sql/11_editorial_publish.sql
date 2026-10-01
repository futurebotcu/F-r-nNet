-- Editoryal yayın kuralları: gece penceresi, görselsiz yayın, editoryal not
-- ayrımı, kaynak atfının korunması, 90 dk aralık, çeşitlilik, günlük tavan.
set role service_role;

create or replace function pg_temp.mk_ed(
  p_bot text, p_key text, p_visual boolean, p_type text,
  p_media boolean default false, p_note text default '',
  p_item uuid default null)
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.academy_drafts
    (content_item_id, bot_key, kind, content_type, title, body,
     editorial_note, needs_visual, tags, publishable, status,
     idempotency_key)
  values (p_item, p_bot, 'evergreen', p_type, 'Başlık ' || p_key,
          'Kaynaktaki gerçek: hamur sıcaklığı fermantasyonu hızlandırır.',
          p_note, p_visual, array['akademi'], true, 'media_ready', p_key)
  returning id into v_id;
  if p_media then
    insert into public.academy_media (draft_id, provider, storage_path,
      width, height, alt_text)
    values (v_id, 'info_card', 'test/' || p_key || '/card.png', 1200, 675,
      'kart');
  end if;
  return v_id;
end;
$$;

do $$
declare
  r record; v_text text; v_src uuid; v_item uuid; d uuid; d2 uuid; d3 uuid;
  v_slot timestamptz; v_next timestamptz; n_today int; v_local time;
  v_start text; v_end text;
begin
  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_enabled';
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_dry_run';
  update public.app_runtime_config set value = '100'::jsonb
    where key = 'academy_daily_post_hard_cap';
  update public.app_runtime_config set value = '5'::jsonb
    where key = 'academy_bot_daily_post_cap';
  update public.academy_bot_profiles set daily_post_limit = 5
    where not is_humor;

  -- E1 pencere fonksiyonu (08:00-21:30 İstanbul) — deterministik saatler.
  update public.app_runtime_config set value = '"08:00"'::jsonb
    where key = 'academy_publish_window_start';
  update public.app_runtime_config set value = '"21:30"'::jsonb
    where key = 'academy_publish_window_end';
  if public.academy_next_publish_slot('2026-10-01T00:00:00Z')
     <> '2026-10-01T05:00:00Z'::timestamptz then
    raise exception 'E1a: 03:00 İst. 08:00''e ertelenmeli: %',
      public.academy_next_publish_slot('2026-10-01T00:00:00Z');
  end if;
  if public.academy_next_publish_slot('2026-10-01T07:00:00Z')
     <> '2026-10-01T07:00:00Z'::timestamptz then
    raise exception 'E1b: 10:00 İst. pencere içinde kalmalı';
  end if;
  if public.academy_next_publish_slot('2026-10-01T05:00:00Z')
     <> '2026-10-01T05:00:00Z'::timestamptz then
    raise exception 'E1c: 08:00 tam sınır yayınlanabilir olmalı';
  end if;
  if public.academy_next_publish_slot('2026-10-01T18:45:00Z')
     <> '2026-10-02T05:00:00Z'::timestamptz then
    raise exception 'E1d: 21:45 İst. ertesi gün 08:00''e ertelenmeli';
  end if;

  -- E2 gece: pencereyi "şu an"ın 2 saat sonrasına kaydır → RPC yayımlamaz.
  v_local := (now() at time zone 'Europe/Istanbul')::time;
  v_start := to_char(v_local + interval '2 hours', 'HH24:MI');
  v_end := to_char(v_local + interval '3 hours', 'HH24:MI');
  update public.app_runtime_config set value = to_jsonb(v_start)
    where key = 'academy_publish_window_start';
  update public.app_runtime_config set value = to_jsonb(v_end)
    where key = 'academy_publish_window_end';
  d := pg_temp.mk_ed('firin_teknoloji', 'e-night', false, 'quick_note');
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'deferred_quiet_hours' then
    raise exception 'E2a: pencere dışında yayın: %', r.result;
  end if;
  select scheduled_for into v_slot from public.academy_drafts where id = d;
  if v_slot is null or v_slot <= now() then
    raise exception 'E2b: bir sonraki pencereye planlanmalıydı: %', v_slot;
  end if;
  if exists (select 1 from public.feed_posts
             where text like 'Başlık e-night%') then
    raise exception 'E2c: pencere dışında feed''e yazıldı';
  end if;

  -- Bundan sonrası: tüm gün açık, aralık 0, çeşitlilik kapalı.
  update public.app_runtime_config set value = '"00:00"'::jsonb
    where key = 'academy_publish_window_start';
  update public.app_runtime_config set value = '"24:00"'::jsonb
    where key = 'academy_publish_window_end';
  update public.app_runtime_config set value = '0'::jsonb
    where key = 'academy_publish_min_gap_minutes';
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_publish_diversity';

  -- E3 görselsiz taslak METİN olarak yayımlanır + kaynak atfı korunur +
  -- editoryal not etiketli ve kaynaktan ayrı.
  insert into public.academy_sources (slug, name, domain, is_commercial,
    source_type, topics, status)
  values ('ed_src', 'Ed Haber Kaynağı', 'ed-src.example', false, 'news',
    array['firin_teknoloji'], 'active')
  returning id into v_src;
  insert into public.academy_content_items (source_id, canonical_url, url,
    title, published_at, content_kind, status, full_text)
  values (v_src, 'https://ed-src.example/h-1', 'https://ed-src.example/h-1',
    'Haber', now(), 'news', 'assigned', 'metin')
  returning id into v_item;
  d := pg_temp.mk_ed('firin_teknoloji', 'e-text', false, 'news', false,
    'Kış aylarında su sıcaklığı daha sık ayarlanmak zorunda kalınabilir.',
    v_item);
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'published' then
    raise exception 'E3a: görselsiz taslak yayımlanmalı: %', r.result;
  end if;
  if exists (select 1 from public.feed_media where post_id = r.post_id) then
    raise exception 'E3b: görselsiz postta medya olmamalı';
  end if;
  select text into v_text from public.feed_posts where id = r.post_id;
  if v_text not like '%Kaynak: Ed Haber Kaynağı%https://ed-src.example/h-1%' then
    raise exception 'E3c: kaynak atfı görselsiz postta kayboldu: %', v_text;
  end if;
  if v_text not like
     '%Kaynaktaki gerçek%FırınNet notu: Kış aylarında%Kaynak: Ed Haber%' then
    raise exception 'E3d: editoryal not etiketli ve kaynaktan ayrı değil: %',
      v_text;
  end if;

  -- E4 görsel GEREKEN taslak kartsız yayımlanmaz (sessiz görselsiz açık yok).
  d := pg_temp.mk_ed('hijyen_kalite', 'e-needvis', true,
    'technical_explainer', false);
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'blocked_media_missing' then
    raise exception 'E4: görsel gereken taslak kartsız: %', r.result;
  end if;

  -- E5 aralık: son yayından 90 dk geçmeden ikinci yayın ertelenir.
  update public.app_runtime_config set value = '90'::jsonb
    where key = 'academy_publish_min_gap_minutes';
  d := pg_temp.mk_ed('isletme', 'e-gap', false, 'business');
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'deferred_spacing' then
    raise exception 'E5a: 90 dk aralık uygulanmadı: %', r.result;
  end if;
  select scheduled_for into v_next from public.academy_drafts where id = d;
  if v_next < now() + interval '85 minutes' then
    raise exception 'E5b: aralık sonrası planlanmalıydı: %', v_next;
  end if;
  update public.app_runtime_config set value = '0'::jsonb
    where key = 'academy_publish_min_gap_minutes';

  -- E6 çeşitlilik: son yayın firin_teknoloji; aynı persona, alternatif
  -- varken ertelenir; alternatif yayımlanır.
  update public.app_runtime_config set value = 'true'::jsonb
    where key = 'academy_publish_diversity';
  d := pg_temp.mk_ed('firin_teknoloji', 'e-div-same', false, 'quick_note');
  d2 := pg_temp.mk_ed('ustalik_dunya', 'e-div-alt', false, 'craft');
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'deferred_diversity' then
    raise exception 'E6a: art arda aynı persona: %', r.result;
  end if;
  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'published' then
    raise exception 'E6b: alternatif yayımlanmalı: %', r.result;
  end if;

  -- E7 iki araştırma art arda gelmez; alternatif yoksa yayın kilitlenmez.
  update public.academy_drafts set status = 'rejected'
    where status in ('media_ready','scheduled') and idempotency_key like 'e-%';
  d := pg_temp.mk_ed('bilim_arge', 'e-res-1', false, 'research');
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'published' then
    raise exception 'E7a: ilk araştırma: %', r.result;
  end if;
  d2 := pg_temp.mk_ed('pastacilik', 'e-res-2', false, 'research');
  d3 := pg_temp.mk_ed('isletme', 'e-res-alt', false, 'business');
  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'deferred_diversity' then
    raise exception 'E7b: iki araştırma art arda: %', r.result;
  end if;
  update public.academy_drafts set status = 'rejected' where id = d3;
  update public.academy_drafts set status = 'media_ready',
    scheduled_for = null where id = d2;
  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'published' then
    raise exception 'E7c: alternatif yokken kilitlenmemeli: %', r.result;
  end if;

  -- E8 günlük tavan: bugünkü sayı + 2 → üçüncüsü ertelenir.
  update public.app_runtime_config set value = 'false'::jsonb
    where key = 'academy_publish_diversity';
  select count(*) into n_today from public.academy_drafts
   where status = 'published' and updated_at >= date_trunc('day',
     now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
  update public.app_runtime_config set value = to_jsonb(n_today + 2)
    where key = 'academy_daily_post_hard_cap';
  d := pg_temp.mk_ed('firin_teknoloji', 'e-cap-1', false, 'quick_note');
  d2 := pg_temp.mk_ed('hijyen_kalite', 'e-cap-2', false, 'hygiene');
  d3 := pg_temp.mk_ed('isletme', 'e-cap-3', false, 'business');
  select * into r from public.academy_publish_draft(d);
  if r.result <> 'published' then raise exception 'E8a: %', r.result; end if;
  select * into r from public.academy_publish_draft(d2);
  if r.result <> 'published' then raise exception 'E8b: %', r.result; end if;
  select * into r from public.academy_publish_draft(d3);
  if r.result <> 'deferred_global_cap' then
    raise exception 'E8c: günlük tavan aşıldı: %', r.result;
  end if;

  raise notice 'PASS 11 editoryal yayın (pencere/görselsiz/not/atıf/aralık/çeşitlilik/tavan)';
end
$$;
reset role;
