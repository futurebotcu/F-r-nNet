-- FırınNet Akademi — Bot Profil Altyapısı V1 (ADDITIVE, PR A1).
--
-- FırınNet Akademi resmi içerik hesapları. Path B (sistem-profil): botlar
-- GİRİŞ YAPAMAYAN sistem auth.users + profiles satırlarıdır (insan/giriş
-- hesabı DEĞİL). feed_posts.owner_id yapısı KORUNUR (nullable yapılmaz,
-- bot_profile_id eklenmez) → bot postu owner_id = bot profil id ile yazılır;
-- mevcut snapshot_feed_post_author trigger'ı author_name'i botun display_name'
-- inden doldurur; feed kartı/profil sayfası neredeyse değişmeden çalışır.
--
-- Bu PR YALNIZ altyapı: profiles.is_bot + academy_bot_profiles + RLS. İçerik
-- tarama / AI / Edge / cron / storage / UI / yorum botu / feed_posts author
-- değişikliği YOK (sonraki PR'lar).
--
-- GÜVENLİK: bot postu yalnız service_role yazar. Kullanıcı bot adına post
-- atamaz — mevcut feed_posts_insert_self (owner_id = auth.uid()) bir insanın
-- auth.uid()'ini asla bir bot profilinin id'sine eşitleyemez. Bu PR o policy'ye
-- DOKUNMAZ. academy_bot_profiles'a client YAZAMAZ (insert/update/delete grant
-- yok, policy yok); yalnız görünür+aktif botları SELECT eder.
--
-- SEED: bu migration auth.users / profiles / bot SEED ETMEZ. Canlı bot kimlik
-- kurulumu ayrı kontrollü service_role/backoffice adımıdır (bkz.
-- docs/academy/bot_seed_plan.md).
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. profiles.is_bot — sistem/bot profili ayrımı (account_type DEĞİL, flag).
-- ────────────────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists is_bot boolean not null default false;

comment on column public.profiles.is_bot is
  'FırınNet Akademi sistem/bot profili mi? Yalnız service_role/backoffice '
  'true yapar; giriş-kapalı sistem hesabı. UI ayrımı + client post guard.';

-- ────────────────────────────────────────────────────────────────────────
-- 2. academy_bot_profiles — bot metadata (kimlik profiles'ta; tekrar yok).
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.academy_bot_profiles (
  profile_id uuid primary key
    references public.profiles(id) on delete cascade,
  bot_key text not null unique,
  topic text not null,
  bio text not null default '',
  is_active boolean not null default true,
  is_visible boolean not null default true,
  posting_enabled boolean not null default true,
  daily_post_limit integer not null default 1,
  created_at timestamptz not null default now(),
  constraint academy_topic_chk check (topic in (
    'akademi', 'haber', 'makine', 'un', 'hammadde', 'usta', 'tarif',
    'maliyet', 'trend', 'hijyen', 'fuar_sektor')),
  constraint academy_daily_limit_chk
    check (daily_post_limit >= 0 and daily_post_limit <= 10)
);

comment on table public.academy_bot_profiles is
  'FırınNet Akademi bot metadata. display_name/avatar_url profiles tarafında '
  '(tekrar yok). Yazma yalnız service_role; client görünür+aktif SELECT eder.';

-- bot_key zaten UNIQUE; profile_id zaten PK. Ekstra index gereksiz.

-- ────────────────────────────────────────────────────────────────────────
-- 3. RLS + GRANTS — görünür+aktif bot public/authenticated SELECT; yazma
--    yalnız service_role (client insert/update/delete YOK).
-- ────────────────────────────────────────────────────────────────────────

alter table public.academy_bot_profiles enable row level security;

drop policy if exists academy_bot_profiles_select_visible
  on public.academy_bot_profiles;
create policy academy_bot_profiles_select_visible
  on public.academy_bot_profiles
  for select to anon, authenticated
  using (is_visible = true and is_active = true);

revoke insert, update, delete, truncate, references, trigger
  on public.academy_bot_profiles from anon, authenticated;
grant select on public.academy_bot_profiles to anon, authenticated;
grant select, insert, update, delete
  on public.academy_bot_profiles to service_role;
