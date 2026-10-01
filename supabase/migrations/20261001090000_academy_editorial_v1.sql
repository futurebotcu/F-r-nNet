-- =============================================================================
-- Akademi editoryal katman V1 — içerik türü, opsiyonel görsel, editoryal not,
-- kalite kaydı + yayın RPC'sinde zaman penceresi / aralık / çeşitlilik.
-- Additif: mevcut satırlar değişmez; needs_visual varsayılanı TRUE olduğundan
-- eski taslaklar eskisi gibi medya şartına tabidir.
-- =============================================================================
alter table public.academy_drafts
  add column if not exists content_type text,
  add column if not exists needs_visual boolean not null default true,
  add column if not exists editorial_note text not null default '',
  add column if not exists quality jsonb not null default '{}'::jsonb;

alter table public.academy_drafts
  drop constraint if exists academy_drafts_content_type_check;
alter table public.academy_drafts
  add constraint academy_drafts_content_type_check
  check (content_type is null or content_type in (
    'news','technical_explainer','business','research','ingredient',
    'hygiene','craft','quick_note'));

insert into public.app_runtime_config (key, value) values
  ('academy_publish_window_start',    '"08:00"'::jsonb),
  ('academy_publish_window_end',      '"21:30"'::jsonb),
  ('academy_publish_min_gap_minutes', '90'::jsonb),
  ('academy_publish_diversity',       'true'::jsonb)
on conflict (key) do nothing;

-- Yayın penceresi (Europe/Istanbul, [start, end)). Pencere içindeyse p_ts,
-- değilse bir sonraki pencere açılışı döner.
create or replace function public.academy_next_publish_slot(p_ts timestamptz)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start time := coalesce((select value #>> '{}' from public.app_runtime_config
                            where key = 'academy_publish_window_start'),
                           '08:00')::time;
  v_end time := coalesce((select value #>> '{}' from public.app_runtime_config
                          where key = 'academy_publish_window_end'),
                         '21:30')::time;
  v_local timestamp := p_ts at time zone 'Europe/Istanbul';
  v_t time := v_local::time;
begin
  -- '24:00' bitişi tüm günü kapsar (time tipinde 24:00:00 geçerlidir).
  if v_t >= v_start and (v_t < v_end or v_end = '24:00'::time) then
    return p_ts;
  end if;
  if v_t < v_start then
    return (v_local::date + v_start) at time zone 'Europe/Istanbul';
  end if;
  return ((v_local::date + 1) + v_start) at time zone 'Europe/Istanbul';
end;
$$;
revoke execute on function public.academy_next_publish_slot(timestamptz)
  from public, anon, authenticated;
grant execute on function public.academy_next_publish_slot(timestamptz)
  to service_role;

-- Yayın RPC'si. 20260930090000 gövdesi korunur; eklenenler işaretli:
--  [PENCERE] gece yayını yok, sıradaki pencereye ertelenir
--  [GÖRSEL]  medya yalnız needs_visual taslakta zorunlu
--  [ARALIK]  son yayından en az academy_publish_min_gap_minutes
--  [ÇEŞİT]   art arda aynı persona / iki araştırma — alternatif varsa ertele
--  [NOT]     editorial_note "FırınNet notu:" etiketiyle kaynak gerçeğinden ayrı
create or replace function public.academy_publish_draft(p_draft_id uuid)
returns table (result text, post_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_draft public.academy_drafts;
  v_bot public.academy_bot_profiles;
  v_today_start timestamptz;
  v_bot_today int;
  v_cap int;
  v_post uuid;
  v_media record;
  v_text text;
  v_slot timestamptz;
  v_gap interval;
  v_last record;
begin
  select * into v_draft from public.academy_drafts
    where id = p_draft_id for update;
  if not found then return query select 'not_found'::text, null::uuid; return;
  end if;
  if v_draft.post_id is not null then
    return query select 'already_published'::text, v_draft.post_id; return;
  end if;
  if v_draft.status in ('published','rejected','failed') then
    return query select ('ignored_status_' || v_draft.status)::text,
      null::uuid; return;
  end if;
  if not v_draft.publishable then
    update public.academy_drafts set status = 'rejected',
      status_reason = 'not_publishable', updated_at = now()
      where id = p_draft_id;
    return query select 'rejected_not_publishable'::text, null::uuid; return;
  end if;

  select * into v_bot from public.academy_bot_profiles
    where bot_key = v_draft.bot_key;
  if not found or not v_bot.is_active or not v_bot.posting_enabled then
    return query select 'bot_disabled'::text, null::uuid; return;
  end if;

  if not public.app_config_bool('academy_enabled', false) then
    return query select 'blocked_academy_disabled'::text, null::uuid; return;
  end if;
  if public.app_config_bool('academy_dry_run', true) then
    update public.academy_drafts set status = 'dry_run_done',
      status_reason = 'dry_run', updated_at = now() where id = p_draft_id;
    return query select 'dry_run_done'::text, null::uuid; return;
  end if;

  -- [PENCERE]
  v_slot := public.academy_next_publish_slot(now());
  if v_slot > now() then
    update public.academy_drafts set status = 'scheduled',
      status_reason = 'quiet_hours', scheduled_for = v_slot,
      updated_at = now() where id = p_draft_id;
    return query select 'deferred_quiet_hours'::text, null::uuid; return;
  end if;

  -- [GÖRSEL] Görsel gereken taslak kartsız yayımlanmaz (sessiz görselsiz
  -- yayın açığı yok); görsel gerekmeyen taslak metin olarak yayımlanır.
  if v_draft.needs_visual and not exists (
       select 1 from public.academy_media
        where draft_id = p_draft_id and status = 'ready') then
    update public.academy_drafts set status = 'checked',
      status_reason = 'media_missing', updated_at = now()
      where id = p_draft_id;
    return query select 'blocked_media_missing'::text, null::uuid; return;
  end if;

  v_today_start := date_trunc('day',
    now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
  perform pg_advisory_xact_lock(hashtextextended(
    'academy_publish:' || v_draft.bot_key || ':' || v_today_start::date, 0));
  select count(*) into v_bot_today from public.academy_drafts d
   where d.bot_key = v_draft.bot_key and d.status = 'published'
     and d.updated_at >= v_today_start;
  v_cap := case when v_bot.is_humor
    then public.app_config_int('academy_humor_daily_post_cap', 1)
    else least(v_bot.daily_post_limit,
               public.app_config_int('academy_bot_daily_post_cap', 2)) end;
  if v_bot.daily_post_limit <= 0 and not v_bot.is_humor then
    v_cap := public.app_config_int('academy_bot_daily_post_cap', 2);
  end if;
  if v_bot_today >= v_cap then
    update public.academy_drafts set status = 'scheduled',
      status_reason = 'daily_cap_reached',
      scheduled_for = v_today_start + interval '1 day',
      updated_at = now()
      where id = p_draft_id;
    return query select 'deferred_daily_cap'::text, null::uuid; return;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'academy_publish_global:' || v_today_start::date, 0));
  if (select count(*) from public.academy_drafts d
       where d.status = 'published' and d.updated_at >= v_today_start)
     >= public.app_config_int('academy_daily_post_hard_cap', 10) then
    update public.academy_drafts set status = 'scheduled',
      status_reason = 'global_cap_reached',
      scheduled_for = v_today_start + interval '1 day',
      updated_at = now()
      where id = p_draft_id;
    return query select 'deferred_global_cap'::text, null::uuid; return;
  end if;

  select d.updated_at, d.bot_key, d.content_type into v_last
    from public.academy_drafts d where d.status = 'published'
   order by d.updated_at desc limit 1;

  -- [ARALIK]
  v_gap := make_interval(
    mins => public.app_config_int('academy_publish_min_gap_minutes', 90));
  if v_gap > interval '0 minutes' and v_last.updated_at is not null
     and v_last.updated_at + v_gap > clock_timestamp() then
    update public.academy_drafts set status = 'scheduled',
      status_reason = 'min_gap',
      scheduled_for = v_last.updated_at + v_gap, updated_at = now()
      where id = p_draft_id;
    return query select 'deferred_spacing'::text, null::uuid; return;
  end if;

  -- [ÇEŞİT] Yalnız ÇAKIŞMAYAN bir alternatif hazırsa ertelenir; aksi hâlde
  -- yayın kilitlenmez.
  if public.app_config_bool('academy_publish_diversity', true)
     and v_last.bot_key is not null
     and (v_last.bot_key = v_draft.bot_key
          or (v_last.content_type = 'research'
              and v_draft.content_type = 'research'))
     and exists (
       select 1 from public.academy_drafts o
        where o.id <> p_draft_id and o.publishable
          and o.status in ('media_ready','scheduled','dry_run_done')
          and (o.scheduled_for is null or o.scheduled_for <= now())
          and o.bot_key <> v_last.bot_key
          and not (v_last.content_type = 'research'
                   and o.content_type = 'research')) then
    update public.academy_drafts set status = 'scheduled',
      status_reason = 'diversity', scheduled_for = now() + v_gap,
      updated_at = now() where id = p_draft_id;
    return query select 'deferred_diversity'::text, null::uuid; return;
  end if;

  v_text := v_draft.title || E'\n\n' || v_draft.body ||
    -- [NOT]
    case when coalesce(v_draft.editorial_note, '') <> ''
      then E'\n\n' || 'FırınNet notu: ' || v_draft.editorial_note
      else '' end ||
    case when v_draft.practical_notes <> ''
      then E'\n\n' || v_draft.practical_notes else '' end;
  if v_draft.content_item_id is not null then
    declare
      v_src_name text;
      v_src_type text;
      v_item_url text;
      v_item_published timestamptz;
    begin
      select s.name, s.source_type, i.canonical_url, i.published_at
        into v_src_name, v_src_type, v_item_url, v_item_published
        from public.academy_content_items i
        join public.academy_sources s on s.id = i.source_id
       where i.id = v_draft.content_item_id;
      if v_src_name is not null then
        v_text := v_text || E'\n\n' || 'Kaynak: ' || v_src_name ||
          case when v_src_type = 'vendor'
            then ' (üretici içeriği)' else '' end ||
          case when v_item_url is not null and v_item_url <> ''
            then E'\n' || v_item_url else '' end;
        if v_draft.kind = 'news' then
          v_text := v_text || E'\n' || 'Tarih: ' ||
            coalesce(nullif(v_draft.date_context, ''),
              coalesce(to_char(v_item_published, 'DD.MM.YYYY'),
                'kaynakta belirtilmemiş'));
        end if;
      end if;
    end;
  end if;
  insert into public.feed_posts (owner_id, type, text, tags)
  values (v_bot.profile_id, 'announcement', v_text, v_draft.tags)
  returning id into v_post;

  for v_media in
    select * from public.academy_media
     where draft_id = p_draft_id and status = 'ready'
  loop
    insert into public.feed_media
      (post_id, owner_id, media_type, storage_path, width, height, size_bytes)
    values (v_post, v_bot.profile_id, 'image', v_media.storage_path,
            v_media.width, v_media.height, v_media.size_bytes);
  end loop;

  -- clock_timestamp: aynı transaction'daki ardışık yayınlar da sıralanabilir
  -- kalır ("son yayın" aralık ve çeşitlilik kurallarının dayanağıdır).
  update public.academy_drafts set status = 'published', post_id = v_post,
    status_reason = null, updated_at = clock_timestamp()
    where id = p_draft_id;
  if v_draft.content_item_id is not null then
    update public.academy_content_items set status = 'drafted',
      updated_at = now() where id = v_draft.content_item_id
      and status <> 'drafted';
  end if;
  return query select 'published'::text, v_post;
end;
$$;
