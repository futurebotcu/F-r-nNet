-- =============================================================================
-- FırınNet Akademi + Mizah — İçerik Motoru V1 (veri modeli + RLS + RPC + seed)
-- =============================================================================
-- A1 (20260713 academy_bot_profiles_v1) temeli üzerine additive genişleme:
--   1) Bot metadata genişletme (alt konular, mizah/DM bayrakları) + yeni konu
--      anahtarları (eski 11 anahtar CHECK'te korunur; canlıda satır yoktu).
--   2) Kaynak sicili + bot-kaynak eşleştirme + içerik adayı + taslak + medya +
--      kalıcı iş kuyruğu (+çalıştırma kaydı) + günlük kullanım sayaçları +
--      kullanıcı etkileşim tercihleri.
--   3) service_role RPC'leri: iş kuyruğu (lease/idempotent), İDEMPOTENT yayın
--      (dry-run guard SERVER-SIDE), mizah yorum/DM guard'ları.
--   4) find_or_create_direct_conversation: bota DM yalnız allow_dm=true bot
--      için (Mizah istisnası) — diğer davranış BİREBİR korunur.
--   5) 11 bot idempotent seed (sabit UUID; on conflict do nothing). Eski
--      bot_seed_plan.md "migration'da seed yok" diyordu; bu V1'de bilinçli
--      olarak deterministik+idempotent seed'e çevrildi (izole PG'de test
--      edilir; giriş-kapalı sistem hesapları, parola yok, token kolonları '').
--
-- GÜVENLİK SÖZLEŞMELERİ (değişmez):
--   - Bot postu/yorumu YALNIZ service_role RPC'leriyle yazılır;
--     feed_posts_insert_self / feed_comments_insert_self DEĞİŞMEZ.
--   - Yeni motor tabloları client'a KAPALI (RLS deny + grant yok);
--     istisnalar: academy_engagement_prefs (kullanıcı kendi tercihi) ve
--     academy_sources'a sınırlı public SELECT YOK (kaynak sicili dahili).
--   - academy_dry_run=true iken hiçbir RPC kullanıcı-görünür feed_posts /
--     feed_comments / mesaj YAZMAZ (UI değil, server guard).

-- ────────────────────────────────────────────────────────────────────────
-- 0) Konfigürasyon anahtarları (mevcut app_runtime_config deseni;
--    on conflict do nothing → canlıda elle değiştirilen değer korunur).
-- ────────────────────────────────────────────────────────────────────────
insert into public.app_runtime_config (key, value) values
  ('academy_enabled',                     'false'::jsonb),
  ('academy_dry_run',                     'true'::jsonb),
  ('academy_daily_post_target',           '6'::jsonb),
  ('academy_bot_daily_post_cap',          '2'::jsonb),
  ('academy_humor_daily_post_cap',        '1'::jsonb),
  ('academy_humor_daily_comment_cap',     '3'::jsonb),
  ('academy_humor_comment_user_gap_hours','72'::jsonb),
  ('academy_scan_interval_minutes',       '480'::jsonb),
  ('academy_daily_llm_request_cap',       '200'::jsonb),
  ('academy_daily_llm_token_cap',         '400000'::jsonb),
  ('academy_daily_cost_cap_usd_cents',    '300'::jsonb),
  ('academy_daily_fetch_cap',             '2000'::jsonb),
  ('academy_daily_image_cap',             '12'::jsonb),
  ('academy_max_active_sources',          'null'::jsonb)
on conflict (key) do nothing;

-- ────────────────────────────────────────────────────────────────────────
-- 1) academy_bot_profiles genişletme + konu CHECK additive.
-- ────────────────────────────────────────────────────────────────────────
alter table public.academy_bot_profiles
  add column if not exists subtopics text[] not null default '{}',
  add column if not exists is_humor boolean not null default false,
  add column if not exists allow_dm boolean not null default false,
  add column if not exists allow_self_comment boolean not null default false,
  add column if not exists display_order int not null default 100;

alter table public.academy_bot_profiles
  drop constraint if exists academy_topic_chk;
alter table public.academy_bot_profiles
  add constraint academy_topic_chk check (topic in (
    -- eski anahtarlar (geriye uyum; canlıda satır yoktu)
    'akademi','haber','makine','un','hammadde','usta','tarif',
    'maliyet','trend','hijyen','fuar_sektor',
    -- V1 kanonik konular (prompt taksonomisi)
    'ekmek_fermantasyon','un_tahil','turk_urunleri','pastacilik',
    'firin_teknoloji','hijyen_kalite','isletme','sektor_gundemi',
    'bilim_arge','ustalik_dunya','mizah'));

-- Dahili bot ayarları (üslup prompt'u client'a SIZDIRILMAZ → ayrı tablo).
create table if not exists public.academy_bot_settings (
  bot_key text primary key
    references public.academy_bot_profiles(bot_key) on delete cascade,
  style_prompt text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.academy_bot_settings enable row level security;
revoke all on public.academy_bot_settings from public, anon, authenticated;
grant select, insert, update, delete on public.academy_bot_settings
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 2) Kaynak sicili + bot-kaynak eşleştirme (dahili; client erişimi yok).
-- ────────────────────────────────────────────────────────────────────────
create table if not exists public.academy_sources (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  domain text not null,
  country text not null default '',
  lang text not null default 'en',
  topics text[] not null default '{}',
  source_type text not null default 'other'
    check (source_type in ('association','vendor','gov','academic',
                           'news','edu','archive','other')),
  is_commercial boolean not null default false,
  publisher_group text,
  access_method text not null default 'html'
    check (access_method in ('api','rss','sitemap','html','pdf','video')),
  feed_urls jsonb not null default '[]'::jsonb,
  allowed_paths jsonb not null default '[]'::jsonb,
  terms_url text,
  text_reuse_policy text not null default 'summary_with_attribution',
  image_reuse_policy text not null default 'no_reuse',
  check_interval_minutes int not null default 480
    check (check_interval_minutes between 30 and 20160),
  priority int not null default 100,
  status text not null default 'candidate'
    check (status in ('candidate','active','degraded','paused','blocked')),
  status_reason text,
  etag text,
  http_last_modified text,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  consecutive_failures int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Arşiv (evergreen) taraması ilerleme kaydı: {sitemap_url, offset, done_at}.
alter table public.academy_sources
  add column if not exists archive_cursor jsonb not null default '{}'::jsonb,
  add column if not exists content_proof jsonb not null default '{}'::jsonb;
alter table public.academy_sources enable row level security;
revoke all on public.academy_sources from public, anon, authenticated;
grant select, insert, update, delete on public.academy_sources to service_role;

create table if not exists public.academy_bot_sources (
  bot_key text not null
    references public.academy_bot_profiles(bot_key) on delete cascade,
  source_id uuid not null
    references public.academy_sources(id) on delete cascade,
  weight int not null default 100,
  primary key (bot_key, source_id)
);
alter table public.academy_bot_sources enable row level security;
revoke all on public.academy_bot_sources from public, anon, authenticated;
grant select, insert, update, delete on public.academy_bot_sources
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 3) İçerik adayı → taslak → medya hattı (dahili).
-- ────────────────────────────────────────────────────────────────────────
create table if not exists public.academy_content_items (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null
    references public.academy_sources(id) on delete cascade,
  canonical_url text not null,
  url text not null,
  title text not null default '',
  lang text,
  content_kind text not null default 'unknown'
    check (content_kind in ('news','evergreen','commercial','research',
                            'unknown')),
  published_at timestamptz,
  source_updated_at timestamptz,
  event_date date,
  fetched_at timestamptz not null default now(),
  text_fingerprint text,
  excerpt text not null default '',
  full_text text,
  status text not null default 'discovered'
    check (status in ('discovered','read','normalized','eligible','assigned',
                      'drafted','rejected','deferred','failed')),
  status_reason text,
  assigned_bot_key text
    references public.academy_bot_profiles(bot_key) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academy_item_canonical_uq unique (canonical_url)
);
create unique index if not exists academy_item_fingerprint_uq
  on public.academy_content_items (text_fingerprint)
  where text_fingerprint is not null;
create index if not exists academy_item_status_idx
  on public.academy_content_items (status, created_at);
alter table public.academy_content_items enable row level security;
revoke all on public.academy_content_items from public, anon, authenticated;
grant select, insert, update, delete on public.academy_content_items
  to service_role;

create table if not exists public.academy_drafts (
  id uuid primary key default gen_random_uuid(),
  content_item_id uuid
    references public.academy_content_items(id) on delete set null,
  bot_key text not null
    references public.academy_bot_profiles(bot_key) on delete cascade,
  kind text not null default 'evergreen'
    check (kind in ('news','evergreen','commercial_note','humor')),
  topic text not null default '',
  title text not null,
  body text not null,
  practical_notes text not null default '',
  tags text[] not null default '{}',
  claims jsonb not null default '[]'::jsonb,
  source_ids uuid[] not null default '{}',
  date_context text not null default '',
  image_brief text not null default '',
  uncertainties text not null default '',
  publishable boolean not null default false,
  model text,
  tokens_in int not null default 0,
  tokens_out int not null default 0,
  cost_usd_cents int not null default 0,
  status text not null default 'draft'
    check (status in ('draft','checked','media_ready','scheduled',
                      'published','dry_run_done','rejected','failed')),
  status_reason text,
  scheduled_for timestamptz,
  post_id uuid,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academy_draft_idem_uq unique (idempotency_key)
);
create index if not exists academy_draft_status_idx
  on public.academy_drafts (status, scheduled_for);
alter table public.academy_drafts enable row level security;
revoke all on public.academy_drafts from public, anon, authenticated;
grant select, insert, update, delete on public.academy_drafts to service_role;

create table if not exists public.academy_media (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null
    references public.academy_drafts(id) on delete cascade,
  provider text not null default 'info_card'
    check (provider in ('source','stock','generated','info_card')),
  storage_path text not null,
  width int,
  height int,
  size_bytes bigint,
  alt_text text not null default '',
  license jsonb not null default '{}'::jsonb,
  status text not null default 'ready'
    check (status in ('pending','ready','failed','orphaned')),
  created_at timestamptz not null default now()
);
alter table public.academy_media enable row level security;
revoke all on public.academy_media from public, anon, authenticated;
grant select, insert, update, delete on public.academy_media to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 4) Kalıcı iş kuyruğu + çalıştırma kaydı + kullanım sayaçları.
-- ────────────────────────────────────────────────────────────────────────
create table if not exists public.academy_jobs (
  id bigint generated always as identity primary key,
  job_type text not null,
  payload jsonb not null default '{}'::jsonb,
  dedupe_key text,
  priority int not null default 100,
  run_after timestamptz not null default now(),
  status text not null default 'queued'
    check (status in ('queued','running','succeeded','failed','dead')),
  attempts int not null default 0,
  max_attempts int not null default 5,
  locked_by text,
  locked_at timestamptz,
  lease_until timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Dedupe YALNIZ bekleyen/çalışan işlerde: tamamlanan (succeeded/dead) iş
-- aynı anahtarla yeniden kuyruklamayı ENGELLEMEZ — dry-run→canlı geçişi,
-- günlük sınırdan ertelenen taslak ve anahtar-sonrası toparlanma çalışır.
drop index if exists academy_jobs_dedupe_uq;
create unique index if not exists academy_jobs_dedupe_uq
  on public.academy_jobs (dedupe_key)
  where dedupe_key is not null and status in ('queued', 'running');
create index if not exists academy_jobs_ready_idx
  on public.academy_jobs (status, run_after, priority);
-- job_type CHECK ayrı constraint olarak (yeniden çalıştırılabilir güncelleme).
alter table public.academy_jobs
  drop constraint if exists academy_jobs_type_chk;
alter table public.academy_jobs
  drop constraint if exists academy_jobs_job_type_check;
alter table public.academy_jobs
  add constraint academy_jobs_type_chk
  check (job_type in ('scan_source','archive_scan','classify','draft',
                      'media','publish','humor_post','humor_comment',
                      'humor_reply','humor_dm','maintenance'));
alter table public.academy_jobs enable row level security;
revoke all on public.academy_jobs from public, anon, authenticated;
grant select, insert, update, delete on public.academy_jobs to service_role;

create table if not exists public.academy_job_runs (
  id bigint generated always as identity primary key,
  job_id bigint not null references public.academy_jobs(id) on delete cascade,
  worker text not null default '',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  outcome text,
  error text
);
alter table public.academy_job_runs enable row level security;
revoke all on public.academy_job_runs from public, anon, authenticated;
grant select, insert, update, delete on public.academy_job_runs
  to service_role;

create table if not exists public.academy_usage_daily (
  day date not null,
  metric text not null,
  value bigint not null default 0,
  primary key (day, metric)
);
alter table public.academy_usage_daily enable row level security;
revoke all on public.academy_usage_daily from public, anon, authenticated;
grant select, insert, update, delete on public.academy_usage_daily
  to service_role;

-- Mizah etkileşim günlüğü (hız sınırı + 72 saat kuralı + idempotency).
create table if not exists public.academy_humor_interactions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('comment','reply','dm')),
  target_user_id uuid references auth.users(id) on delete cascade,
  post_id uuid,
  comment_id uuid,
  conversation_id uuid,
  event_key text not null,
  created_at timestamptz not null default now(),
  constraint academy_humor_event_uq unique (event_key)
);
create index if not exists academy_humor_target_idx
  on public.academy_humor_interactions (target_user_id, created_at);
alter table public.academy_humor_interactions enable row level security;
revoke all on public.academy_humor_interactions
  from public, anon, authenticated;
grant select, insert, update, delete on public.academy_humor_interactions
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 5) Kullanıcı etkileşim tercihleri (client kendi satırını yönetir).
-- ────────────────────────────────────────────────────────────────────────
create table if not exists public.academy_engagement_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  allow_humor_comments boolean not null default true,
  allow_humor_dm boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.academy_engagement_prefs enable row level security;
drop policy if exists aep_select_own on public.academy_engagement_prefs;
drop policy if exists aep_insert_own on public.academy_engagement_prefs;
drop policy if exists aep_update_own on public.academy_engagement_prefs;
create policy aep_select_own on public.academy_engagement_prefs
  for select to authenticated using (user_id = auth.uid());
create policy aep_insert_own on public.academy_engagement_prefs
  for insert to authenticated with check (user_id = auth.uid());
create policy aep_update_own on public.academy_engagement_prefs
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on public.academy_engagement_prefs from public, anon;
revoke delete, truncate, references, trigger
  on public.academy_engagement_prefs from authenticated;
grant select, insert, update on public.academy_engagement_prefs
  to authenticated;
grant select, insert, update, delete on public.academy_engagement_prefs
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 6) İş kuyruğu RPC'leri (YALNIZ service_role).
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.academy_enqueue_job(
  p_job_type text,
  p_payload jsonb default '{}'::jsonb,
  p_run_after timestamptz default now(),
  p_priority int default 100,
  p_dedupe_key text default null,
  p_max_attempts int default 5
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_id bigint;
begin
  insert into public.academy_jobs
    (job_type, payload, run_after, priority, dedupe_key, max_attempts)
  values (p_job_type, p_payload, p_run_after, p_priority, p_dedupe_key,
          p_max_attempts)
  on conflict do nothing -- arbiter: partial dedupe index (queued/running)
  returning id into v_id;
  return v_id; -- null = dedupe (zaten kuyrukta/çalışıyor)
end;
$$;

create or replace function public.academy_claim_jobs(
  p_worker text,
  p_limit int default 5,
  p_lease_seconds int default 120
)
returns setof public.academy_jobs
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  update public.academy_jobs j
     set status = 'running',
         locked_by = p_worker,
         locked_at = now(),
         lease_until = now() + make_interval(secs => p_lease_seconds),
         attempts = j.attempts + 1,
         updated_at = now()
   where j.id in (
     select id from public.academy_jobs
      where (status = 'queued' and run_after <= now())
         -- süresi geçmiş lease → yarıda kalan işi devral
         or (status = 'running' and lease_until is not null
             and lease_until < now())
      order by priority asc, run_after asc
      for update skip locked
      limit greatest(p_limit, 1)
   )
   returning j.*;
end;
$$;

create or replace function public.academy_complete_job(
  p_job_id bigint,
  p_outcome text,           -- succeeded | failed | dead
  p_error text default null,
  p_retry_delay_seconds int default 300,
  p_worker text default ''
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.academy_jobs;
  v_final text;
begin
  select * into v_job from public.academy_jobs where id = p_job_id
    for update;
  if not found then return 'not_found'; end if;
  -- Bayat worker koruması: lease'i başka worker devraldıysa eski worker
  -- işi complete EDEMEZ (çifte tamamlama / geç yan etki engeli).
  if v_job.status = 'running'
     and v_job.locked_by is distinct from p_worker then
    insert into public.academy_job_runs
      (job_id, worker, started_at, finished_at, outcome, error)
    values (p_job_id, coalesce(p_worker, ''), now(), now(),
            'stale_worker_rejected', p_error);
    return 'stale_worker';
  end if;

  if p_outcome = 'succeeded' then
    v_final := 'succeeded';
    update public.academy_jobs set status = 'succeeded', last_error = null,
      locked_by = null, lease_until = null, updated_at = now()
      where id = p_job_id;
  elsif p_outcome = 'dead'
        or (p_outcome = 'failed' and v_job.attempts >= v_job.max_attempts) then
    v_final := 'dead';
    update public.academy_jobs set status = 'dead', last_error = p_error,
      locked_by = null, lease_until = null, updated_at = now()
      where id = p_job_id;
  else
    -- sınırlı retry + artan bekleme (attempt^2 * taban)
    v_final := 'queued';
    update public.academy_jobs set status = 'queued',
      last_error = p_error,
      run_after = now() + make_interval(
        secs => p_retry_delay_seconds * greatest(v_job.attempts, 1)),
      locked_by = null, lease_until = null, updated_at = now()
      where id = p_job_id;
  end if;

  insert into public.academy_job_runs
    (job_id, worker, started_at, finished_at, outcome, error)
  values (p_job_id, coalesce(p_worker, v_job.locked_by, ''),
          coalesce(v_job.locked_at, now()), now(), v_final, p_error);
  return v_final;
end;
$$;

-- Lease uzatma (heartbeat): uzun süren iş, sahipliği koruyarak süre alır.
create or replace function public.academy_extend_lease(
  p_job_id bigint,
  p_worker text,
  p_lease_seconds int default 120
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_ok boolean;
begin
  update public.academy_jobs
     set lease_until = now() + make_interval(secs => p_lease_seconds),
         updated_at = now()
   where id = p_job_id and status = 'running' and locked_by = p_worker
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

-- Günlük kullanım sayacı (bütçe): artır ve yeni değeri döndür.
create or replace function public.academy_incr_usage(
  p_metric text,
  p_delta bigint default 1
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v bigint;
begin
  insert into public.academy_usage_daily (day, metric, value)
  values ((now() at time zone 'Europe/Istanbul')::date, p_metric, p_delta)
  on conflict (day, metric)
  do update set value = public.academy_usage_daily.value + excluded.value
  returning value into v;
  return v;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────
-- 7) İDEMPOTENT yayın RPC'si — dry-run + günlük sınırlar SERVER-SIDE.
-- ────────────────────────────────────────────────────────────────────────
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
  -- İdempotency: yeniden yürütmede ikinci post OLUŞMAZ.
  if v_draft.post_id is not null then
    return query select 'already_published'::text, v_draft.post_id; return;
  end if;
  if v_draft.status in ('published','dry_run_done','rejected','failed') then
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

  -- Genel acil durdurma + dry-run: kullanıcı-görünür yazma YOK.
  if not public.app_config_bool('academy_enabled', false) then
    return query select 'blocked_academy_disabled'::text, null::uuid; return;
  end if;
  if public.app_config_bool('academy_dry_run', true) then
    update public.academy_drafts set status = 'dry_run_done',
      status_reason = 'dry_run', updated_at = now() where id = p_draft_id;
    return query select 'dry_run_done'::text, null::uuid; return;
  end if;

  -- Günlük bot sınırı (Europe/Istanbul günü). Paralel publish çağrılarının
  -- sayacı yarış koşuluyla aşmaması için bot+gün bazlı advisory kilit.
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

  -- Yayın: feed_posts + feed_media tek transaksiyonda (fonksiyon gövdesi).
  v_text := v_draft.title || E'\n\n' || v_draft.body ||
    case when v_draft.practical_notes <> ''
      then E'\n\n' || v_draft.practical_notes else '' end;
  -- Kullanıcı-görünür KAYNAK atfı: ad + DOĞRULANMIŞ URL sicilden (modelden
  -- asla); ticari kaynak notu + haberde tarih bağlamı. Mizahta kaynak yok.
  if v_draft.content_item_id is not null then
    declare
      v_src_name text;
      v_src_commercial boolean;
      v_item_url text;
      v_item_published timestamptz;
    begin
      select s.name, s.is_commercial, i.canonical_url, i.published_at
        into v_src_name, v_src_commercial, v_item_url, v_item_published
        from public.academy_content_items i
        join public.academy_sources s on s.id = i.source_id
       where i.id = v_draft.content_item_id;
      if v_src_name is not null then
        v_text := v_text || E'\n\n' || 'Kaynak: ' || v_src_name ||
          case when v_src_commercial then ' (üretici içeriği)' else '' end ||
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

-- ────────────────────────────────────────────────────────────────────────
-- 8) Mizah guard'ları: kendiliğinden yorum + DM (YALNIZ service_role).
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.academy_humor_can_comment(
  p_target_user uuid
)
returns text  -- 'ok' veya red nedeni
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bot uuid;
  v_today_start timestamptz;
begin
  select profile_id into v_bot from public.academy_bot_profiles
    where is_humor and is_active limit 1;
  if v_bot is null then return 'no_humor_bot'; end if;
  if p_target_user is null then return 'no_target'; end if;
  if p_target_user = v_bot then return 'self'; end if;
  -- bot-bot döngüsü engeli
  if exists (select 1 from public.profiles
             where id = p_target_user and is_bot) then
    return 'target_is_bot';
  end if;
  -- kullanıcı tercihi (satır yoksa varsayılan izinli)
  if exists (select 1 from public.academy_engagement_prefs
             where user_id = p_target_user
               and allow_humor_comments = false) then
    return 'user_opted_out';
  end if;
  -- çift yön engel
  if exists (select 1 from public.user_blocks
             where (blocker_id = p_target_user and blocked_user_id = v_bot)
                or (blocker_id = v_bot and blocked_user_id = p_target_user))
  then
    return 'blocked';
  end if;
  -- aynı kullanıcıya en erken 72 saat sonra
  if exists (select 1 from public.academy_humor_interactions
             where target_user_id = p_target_user
               and kind in ('comment','reply')
               and created_at > now() - make_interval(hours =>
                 public.app_config_int(
                   'academy_humor_comment_user_gap_hours', 72))) then
    return 'user_gap';
  end if;
  -- günlük toplam kendiliğinden yorum sınırı
  v_today_start := date_trunc('day',
    now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
  if (select count(*) from public.academy_humor_interactions
       where kind = 'comment' and created_at >= v_today_start)
     >= public.app_config_int('academy_humor_daily_comment_cap', 3) then
    return 'daily_cap';
  end if;
  return 'ok';
end;
$$;

-- Mizah günlük yorum sayacı yarışına karşı gün-bazlı advisory kilit anahtarı.
create or replace function public.academy_humor_day_lock()
returns void
language sql
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('academy_humor:' ||
    (now() at time zone 'Europe/Istanbul')::date, 0));
$$;

create or replace function public.academy_humor_publish_comment(
  p_post_id uuid,
  p_body text,
  p_event_key text
)
returns table (result text, comment_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bot public.academy_bot_profiles;
  v_owner uuid;
  v_guard text;
  v_comment uuid;
begin
  select * into v_bot from public.academy_bot_profiles
    where is_humor and is_active limit 1;
  if not found then
    return query select 'no_humor_bot'::text, null::uuid; return;
  end if;
  -- idempotency: aynı olaya İKİNCİ cevap oluşmaz
  if exists (select 1 from public.academy_humor_interactions
             where event_key = p_event_key) then
    return query select 'duplicate_event'::text, null::uuid; return;
  end if;
  -- gönderim ANINDA içerik hâlâ erişilebilir mi
  select owner_id into v_owner from public.feed_posts
    where id = p_post_id and is_deleted = false;
  if v_owner is null then
    return query select 'post_gone'::text, null::uuid; return;
  end if;
  -- Paralel çağrılar günlük sınırı yarışla aşamasın.
  perform public.academy_humor_day_lock();
  v_guard := public.academy_humor_can_comment(v_owner);
  if v_guard <> 'ok' then
    return query select ('blocked_' || v_guard)::text, null::uuid; return;
  end if;
  if not public.app_config_bool('academy_enabled', false) then
    return query select 'blocked_academy_disabled'::text, null::uuid; return;
  end if;
  if public.app_config_bool('academy_dry_run', true) then
    -- dry-run: etkileşim GÜNLÜĞE yazılmaz (gerçek sayaçları kirletmesin),
    -- kullanıcı-görünür yorum YAZILMAZ.
    return query select 'dry_run_done'::text, null::uuid; return;
  end if;

  insert into public.feed_comments (post_id, owner_id, text)
  values (p_post_id, v_bot.profile_id, p_body)
  returning id into v_comment;
  insert into public.academy_humor_interactions
    (kind, target_user_id, post_id, comment_id, event_key)
  values ('comment', v_owner, p_post_id, v_comment, p_event_key);
  return query select 'published'::text, v_comment;
end;
$$;

-- Mizah YANIT (B): kendi gönderisindeki yoruma / kendisine verilen cevaba
-- tek-seviye kuralına uygun cevap. Gönderim ANINDA yeniden doğrulama:
-- yorum/gönderi silinmemiş, engel yok, bot-bot yok, duplicate-event yok.
-- (72 saat/duyuru sınırı KENDİLİĞİNDEN yorum içindir; kullanıcı botla
-- konuşmayı kendisi başlattığı için burada uygulanmaz.)
create or replace function public.academy_humor_publish_reply(
  p_parent_comment_id uuid,
  p_body text,
  p_event_key text
)
returns table (result text, comment_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bot public.academy_bot_profiles;
  v_parent record;
  v_reply_to uuid;
  v_comment uuid;
begin
  select * into v_bot from public.academy_bot_profiles
    where is_humor and is_active limit 1;
  if not found then
    return query select 'no_humor_bot'::text, null::uuid; return;
  end if;
  if exists (select 1 from public.academy_humor_interactions
             where event_key = p_event_key) then
    return query select 'duplicate_event'::text, null::uuid; return;
  end if;
  select c.id, c.owner_id, c.post_id, c.parent_comment_id, c.is_deleted,
         p.is_deleted as post_deleted, p.owner_id as post_owner
    into v_parent
    from public.feed_comments c
    join public.feed_posts p on p.id = c.post_id
   where c.id = p_parent_comment_id;
  if not found or v_parent.is_deleted or v_parent.post_deleted then
    return query select 'comment_gone'::text, null::uuid; return;
  end if;
  if v_parent.owner_id = v_bot.profile_id then
    return query select 'blocked_self_reply'::text, null::uuid; return;
  end if;
  -- bot-bot döngüsü yok
  if exists (select 1 from public.profiles
             where id = v_parent.owner_id and is_bot) then
    return query select 'blocked_target_is_bot'::text, null::uuid; return;
  end if;
  -- çift yön engel
  if exists (select 1 from public.user_blocks
             where (blocker_id = v_parent.owner_id
                    and blocked_user_id = v_bot.profile_id)
                or (blocker_id = v_bot.profile_id
                    and blocked_user_id = v_parent.owner_id)) then
    return query select 'blocked_blocked'::text, null::uuid; return;
  end if;
  if not public.app_config_bool('academy_enabled', false) then
    return query select 'blocked_academy_disabled'::text, null::uuid; return;
  end if;
  if public.app_config_bool('academy_dry_run', true) then
    return query select 'dry_run_done'::text, null::uuid; return;
  end if;

  -- Tek-seviye kuralı: parent bir cevapsa, botun cevabı ÜST yoruma bağlanır.
  v_reply_to := coalesce(v_parent.parent_comment_id, v_parent.id);
  insert into public.feed_comments (post_id, owner_id, text,
    parent_comment_id)
  values (v_parent.post_id, v_bot.profile_id, p_body, v_reply_to)
  returning id into v_comment;
  insert into public.academy_humor_interactions
    (kind, target_user_id, post_id, comment_id, event_key)
  values ('reply', v_parent.owner_id, v_parent.post_id, v_comment,
          p_event_key);
  return query select 'published'::text, v_comment;
end;
$$;

-- Mizah DM (C/E): var olan konuşmaya cevap; kendiliğinden İLK mesaj yalnız
-- açık kullanıcı izniyle (allow_humor_dm). Gönderim anında yeniden doğrulama.
create or replace function public.academy_humor_send_dm(
  p_conversation_id uuid,
  p_body text,
  p_event_key text,
  p_proactive boolean default false
)
returns table (result text, message_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bot public.academy_bot_profiles;
  v_other uuid;
  v_msg uuid;
begin
  select * into v_bot from public.academy_bot_profiles
    where is_humor and is_active limit 1;
  if not found then
    return query select 'no_humor_bot'::text, null::uuid; return;
  end if;
  if exists (select 1 from public.academy_humor_interactions
             where event_key = p_event_key) then
    return query select 'duplicate_event'::text, null::uuid; return;
  end if;
  -- Bot bu konuşmanın katılımcısı olmalı; karşı taraf tek ve bot olmamalı.
  if not exists (select 1 from public.conversation_participants
                 where conversation_id = p_conversation_id
                   and user_id = v_bot.profile_id) then
    return query select 'not_participant'::text, null::uuid; return;
  end if;
  select user_id into v_other from public.conversation_participants
   where conversation_id = p_conversation_id
     and user_id <> v_bot.profile_id
   limit 1;
  if v_other is null then
    return query select 'no_counterpart'::text, null::uuid; return;
  end if;
  if exists (select 1 from public.profiles
             where id = v_other and is_bot) then
    return query select 'blocked_target_is_bot'::text, null::uuid; return;
  end if;
  if exists (select 1 from public.user_blocks
             where (blocker_id = v_other
                    and blocked_user_id = v_bot.profile_id)
                or (blocker_id = v_bot.profile_id
                    and blocked_user_id = v_other)) then
    return query select 'blocked_blocked'::text, null::uuid; return;
  end if;
  if p_proactive then
    -- Kendiliğinden DM: varsayılan KAPALI; açık, geri alınabilir izin şart.
    if not exists (select 1 from public.academy_engagement_prefs
                   where user_id = v_other and allow_humor_dm) then
      return query select 'blocked_dm_not_opted_in'::text, null::uuid;
      return;
    end if;
  else
    -- Cevap: kullanıcı konuşmada bottan SONRA en az bir mesaj yazmış olmalı
    -- (kullanıcının başlattığı/sürdürdüğü sohbet; boşuna takip mesajı yok).
    if not exists (
      select 1 from public.messages m
       where m.conversation_id = p_conversation_id
         and m.sender_id = v_other
         and m.created_at > coalesce((
           select max(created_at) from public.messages
            where conversation_id = p_conversation_id
              and sender_id = v_bot.profile_id), '-infinity'::timestamptz)
    ) then
      return query select 'no_pending_user_message'::text, null::uuid;
      return;
    end if;
  end if;
  if not public.app_config_bool('academy_enabled', false) then
    return query select 'blocked_academy_disabled'::text, null::uuid; return;
  end if;
  if public.app_config_bool('academy_dry_run', true) then
    return query select 'dry_run_done'::text, null::uuid; return;
  end if;

  insert into public.messages (conversation_id, sender_id, content)
  values (p_conversation_id, v_bot.profile_id, p_body)
  returning id into v_msg;
  insert into public.academy_humor_interactions
    (kind, target_user_id, conversation_id, event_key)
  values ('dm', v_other, p_conversation_id, p_event_key);
  return query select 'published'::text, v_msg;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────
-- 9) Bota DM kuralı: yalnız allow_dm=true bot (Mizah) DM alabilir.
--    Gövde 20260612040000 sürümüyle BİREBİR; tek ek blok işaretli.
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.find_or_create_direct_conversation(
  p_other_user uuid,
  p_context_type text default 'profile_direct'::text,
  p_context_id uuid default null::uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_me   uuid := auth.uid();
  v_conv uuid;
  v_lock_key bigint;
begin
  if v_me is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if v_me = p_other_user then
    raise exception 'cannot direct-message self' using errcode = '22023';
  end if;
  -- UGC Safety V1.1 — çift yön engel: herhangi bir yönde block varsa reddet.
  if exists (
    select 1 from public.user_blocks
    where (blocker_id = p_other_user and blocked_user_id = v_me)
       or (blocker_id = v_me and blocked_user_id = p_other_user)
  ) then
    raise exception 'blocked between users' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user) then
    raise exception 'target profile not found' using errcode = '23503';
  end if;
  -- Akademi V1 — bot hedefli DM: yalnız allow_dm=true + aktif bot (Mizah).
  -- Diğer botlar giriş yapamaz/yanıt veremez → DM açmak kullanıcıyı yanıltır.
  if exists (select 1 from public.profiles
             where id = p_other_user and is_bot) then
    if not exists (
      select 1 from public.academy_bot_profiles
      where profile_id = p_other_user and is_active and allow_dm
    ) then
      raise exception 'bot does not accept direct messages'
        using errcode = '42501';
    end if;
  end if;
  if p_context_type not in ('market_listing','profile_direct','job_offer','job_seek') then
    raise exception 'invalid context_type: %', p_context_type using errcode = '22023';
  end if;
  if p_context_type = 'profile_direct' and p_context_id is not null then
    raise exception 'profile_direct must not have context_id' using errcode = '22023';
  end if;
  if p_context_type in ('market_listing','job_offer','job_seek') and p_context_id is null then
    raise exception 'context_id required for %', p_context_type using errcode = '22023';
  end if;
  if p_context_type = 'market_listing' then
    if not exists (
      select 1 from public.market_listings ml
      where ml.id = p_context_id and ml.is_deleted = false and ml.owner_id = p_other_user
    ) then
      raise exception 'market_listing context invalid (not found, deleted, or owner mismatch)'
        using errcode = '23503';
    end if;
  end if;
  v_lock_key := hashtextextended(
    format('msg-direct:%s:%s:%s:%s',
      p_context_type,
      coalesce(p_context_id::text, '-'),
      least(v_me::text, p_other_user::text),
      greatest(v_me::text, p_other_user::text)
    ), 0
  );
  perform pg_advisory_xact_lock(v_lock_key);
  select c.id into v_conv
    from public.conversations c
   where c.type = 'direct'
     and c.context_type = p_context_type
     and coalesce(c.context_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_context_id, '00000000-0000-0000-0000-000000000000'::uuid)
     and exists (select 1 from public.conversation_participants p where p.conversation_id = c.id and p.user_id = v_me)
     and exists (select 1 from public.conversation_participants p where p.conversation_id = c.id and p.user_id = p_other_user)
   limit 1;
  if v_conv is not null then return v_conv; end if;
  insert into public.conversations (type, context_type, context_id, created_by)
  values ('direct', p_context_type, p_context_id, v_me)
  returning id into v_conv;
  insert into public.conversation_participants (conversation_id, user_id, role)
  values (v_conv, v_me, 'owner'), (v_conv, p_other_user, 'member');
  return v_conv;
end;
$function$;

-- ────────────────────────────────────────────────────────────────────────
-- 10) RPC grant hijyeni: motor RPC'leri YALNIZ service_role.
-- ────────────────────────────────────────────────────────────────────────
revoke execute on function public.academy_enqueue_job(
  text, jsonb, timestamptz, int, text, int) from public, anon, authenticated;
grant execute on function public.academy_enqueue_job(
  text, jsonb, timestamptz, int, text, int) to service_role;

revoke execute on function public.academy_claim_jobs(text, int, int)
  from public, anon, authenticated;
grant execute on function public.academy_claim_jobs(text, int, int)
  to service_role;

revoke execute on function public.academy_complete_job(
  bigint, text, text, int, text) from public, anon, authenticated;
grant execute on function public.academy_complete_job(
  bigint, text, text, int, text) to service_role;

revoke execute on function public.academy_incr_usage(text, bigint)
  from public, anon, authenticated;
grant execute on function public.academy_incr_usage(text, bigint)
  to service_role;

revoke execute on function public.academy_publish_draft(uuid)
  from public, anon, authenticated;
grant execute on function public.academy_publish_draft(uuid)
  to service_role;

revoke execute on function public.academy_humor_can_comment(uuid)
  from public, anon, authenticated;
grant execute on function public.academy_humor_can_comment(uuid)
  to service_role;

revoke execute on function public.academy_humor_publish_comment(
  uuid, text, text) from public, anon, authenticated;
grant execute on function public.academy_humor_publish_comment(
  uuid, text, text) to service_role;

revoke execute on function public.academy_extend_lease(bigint, text, int)
  from public, anon, authenticated;
grant execute on function public.academy_extend_lease(bigint, text, int)
  to service_role;

revoke execute on function public.academy_humor_day_lock()
  from public, anon, authenticated;
grant execute on function public.academy_humor_day_lock() to service_role;

revoke execute on function public.academy_humor_publish_reply(
  uuid, text, text) from public, anon, authenticated;
grant execute on function public.academy_humor_publish_reply(
  uuid, text, text) to service_role;

revoke execute on function public.academy_humor_send_dm(
  uuid, text, text, boolean) from public, anon, authenticated;
grant execute on function public.academy_humor_send_dm(
  uuid, text, text, boolean) to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 11) 11 bot idempotent seed (sabit UUID'ler; giriş-kapalı sistem hesabı).
--     Yeniden çalıştırma kopya ÜRETMEZ (on conflict do nothing).
-- ────────────────────────────────────────────────────────────────────────
do $$
declare
  b record;
begin
  for b in select * from (values
    ('ab010000-0000-4000-8000-000000000001'::uuid, 'ekmek_fermantasyon',
     'FırınNet Ekmek ve Fermantasyon', 'ekmek_fermantasyon',
     'Hamur gelişimi, yoğurma, maya ve ekşi maya fermantasyonu üzerine '
     || 'kaynaklı teknik bilgi.',
     array['Hamur gelişimi ve yoğurma','Maya, ekşi maya ve fermantasyon'],
     false, 10),
    ('ab010000-0000-4000-8000-000000000002'::uuid, 'un_tahil',
     'FırınNet Un ve Tahıl', 'un_tahil',
     'Un özellikleri, kalite ölçütleri, buğday ve öğütme üzerine kaynaklı '
     || 'bilgi.',
     array['Un özellikleri ve kalite','Buğday, öğütme ve hammadde seçimi'],
     false, 20),
    ('ab010000-0000-4000-8000-000000000003'::uuid, 'turk_urunleri',
     'FırınNet Türkiye''nin Unlu Mamulleri', 'turk_urunleri',
     'Simit, pide, poğaça, börek ve yerel ürünlerin üretim pratikleri.',
     array['Simit ve pide','Poğaça, börek ve yerel ürünler'],
     false, 30),
    ('ab010000-0000-4000-8000-000000000004'::uuid, 'pastacilik',
     'FırınNet Pastacılık ve Yeni Ürünler', 'pastacilik',
     'Kruvasan, katmanlı hamurlar, dolgular ve ürün geliştirme.',
     array['Kruvasan ve katmanlı hamurlar',
           'Dolgu, pastacılık ve ürün geliştirme'],
     false, 40),
    ('ab010000-0000-4000-8000-000000000005'::uuid, 'firin_teknoloji',
     'FırınNet Fırın ve Üretim Teknolojisi', 'firin_teknoloji',
     'Pişirme, buhar, fırın kullanımı, ekipman, otomasyon ve enerji.',
     array['Pişirme, buhar ve fırın kullanımı',
           'Ekipman, otomasyon ve enerji'],
     false, 50),
    ('ab010000-0000-4000-8000-000000000006'::uuid, 'hijyen_kalite',
     'FırınNet Hijyen ve Kalite', 'hijyen_kalite',
     'Temizlik, çapraz bulaşma, saklama, kalite kusurları ve raf ömrü.',
     array['Temizlik, çapraz bulaşma ve saklama',
           'Kalite kusurları ve raf ömrü'],
     false, 60),
    ('ab010000-0000-4000-8000-000000000007'::uuid, 'isletme',
     'FırınNet Fırın İşletmeciliği', 'isletme',
     'Maliyet, fire, stok, ekip, operasyon ve müşteri yönetimi.',
     array['Maliyet ve fire','Stok, ekip, operasyon ve müşteri yönetimi'],
     false, 70),
    ('ab010000-0000-4000-8000-000000000008'::uuid, 'sektor_gundemi',
     'FırınNet Sektör Gündemi', 'sektor_gundemi',
     'Türkiye ve dünyadan sektör gelişmeleri, tedarik, fuarlar ve pazar.',
     array['Türkiye ve dünya gelişmeleri',
           'Tedarik, fuarlar ve pazar haberleri'],
     false, 80),
    ('ab010000-0000-4000-8000-000000000009'::uuid, 'bilim_arge',
     'FırınNet Bilim ve Ar-Ge', 'bilim_arge',
     'Fırıncılık araştırmaları, sürdürülebilirlik ve yeni üretim yöntemleri.',
     array['Fırıncılık araştırmaları',
           'Sürdürülebilirlik ve yeni üretim yöntemleri'],
     false, 90),
    ('ab010000-0000-4000-8000-000000000010'::uuid, 'ustalik_dunya',
     'FırınNet Ustalık ve Dünya Ekmekleri', 'ustalik_dunya',
     'Şekillendirme, kesik, mesleki teknikler ve dünya ekmek gelenekleri.',
     array['Şekillendirme, kesik ve mesleki teknikler',
           'Farklı ekmek gelenekleri'],
     false, 100),
    ('ab010000-0000-4000-8000-000000000011'::uuid, 'mizah',
     'FırınNet Mizah', 'mizah',
     'Fırındaki gündelik hâller üzerine özgün mesleki mizah. '
     || 'Bir yapay zekâ karakteridir.',
     array['Fırındaki gündelik durumlar',
           'Özgün mesleki mizah ve bağlama uygun sohbet'],
     true, 110)
  ) as t(id, bot_key, display_name, topic, bio, subtopics, is_humor, ord)
  loop
    -- 1) giriş-kapalı sistem auth hesabı (parola yok; token kolonları '').
    insert into auth.users (instance_id, id, aud, role, email,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change, email_change_token_current,
      phone_change, phone_change_token, reauthentication_token)
    values ('00000000-0000-0000-0000-000000000000', b.id, 'authenticated',
      'authenticated', 'bot+' || b.bot_key || '@firinnet.system', now(),
      '{"provider":"system","providers":["system"]}'::jsonb,
      '{"is_bot":true}'::jsonb, now(), now(), '','','','','','','','')
    on conflict (id) do nothing;

    -- 2) profiles (auth trigger'ı satırı önce oluşturmuş olabilir →
    --    update ile bot alanları garanti edilir).
    insert into public.profiles (id, display_name, account_type, is_bot)
    values (b.id, b.display_name, 'individual', true)
    on conflict (id) do update
      set display_name = excluded.display_name, is_bot = true;

    -- 3) academy_bot_profiles metadata (idempotent).
    insert into public.academy_bot_profiles
      (profile_id, bot_key, topic, bio, subtopics, is_humor,
       allow_dm, allow_self_comment, daily_post_limit, display_order)
    values (b.id, b.bot_key, b.topic, b.bio, b.subtopics, b.is_humor,
            b.is_humor, b.is_humor,
            case when b.is_humor then 1 else 2 end, b.ord)
    on conflict (profile_id) do update
      set topic = excluded.topic, bio = excluded.bio,
          subtopics = excluded.subtopics, is_humor = excluded.is_humor,
          allow_dm = excluded.allow_dm,
          allow_self_comment = excluded.allow_self_comment,
          display_order = excluded.display_order;

    -- 4) dahili üslup ayarı (client'a kapalı tablo).
    insert into public.academy_bot_settings (bot_key, style_prompt)
    values (b.bot_key, case
      when b.is_humor then
        'Üslup: samimi, kısa, Türkçe fırın mizahı. Gerçek kişi taklidi, '
        || 'sahte kişisel anı ve alay yok. Ciddi/üzücü konuda mizah üretme.'
      when b.bot_key = 'sektor_gundemi' then
        'Üslup: tarih ve kaynak odaklı, tarafsız haber dili. Eski haberi '
        || 'yeni gibi sunma; tarih bağlamını her zaman belirt.'
      when b.bot_key = 'isletme' then
        'Üslup: somut ve hesaplı; örnek rakamları kaynağa bağla, kârlılık '
        || 'garantisi verme.'
      else
        'Üslup: açıklayıcı teknik anlatım; ölçü/sıcaklık/süre iddialarını '
        || 'kaynakla ilişkilendir, kesinlik uydurma.'
      end)
    on conflict (bot_key) do nothing;
  end loop;
end
$$;
