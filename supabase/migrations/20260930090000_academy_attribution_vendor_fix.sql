-- =============================================================================
-- Atıf düzeltmesi: ' (üretici içeriği)' etiketi YALNIZ vendor (üretici)
-- kaynaklar için. is_commercial "ticari kuruluş" işaretidir; ticari bir
-- SEKTÖR YAYINI (news/association/edu) üretici etiketi almamalıdır
-- (dry-run bulgusu: World Bakers haberi 'üretici içeriği' etiketlendi).
-- academy_publish_draft gövdesi 20260929090000 sürümüyle BİREBİR; tek
-- fark v_src_commercial → v_src_type ve etiket koşulu.
-- =============================================================================
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

  if not exists (select 1 from public.academy_media
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

  v_text := v_draft.title || E'\n\n' || v_draft.body ||
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

  update public.academy_drafts set status = 'published', post_id = v_post,
    status_reason = null, updated_at = now() where id = p_draft_id;
  if v_draft.content_item_id is not null then
    update public.academy_content_items set status = 'drafted',
      updated_at = now() where id = v_draft.content_item_id
      and status <> 'drafted';
  end if;
  return query select 'published'::text, v_post;
end;
$$;
