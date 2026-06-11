-- =============================================================================
-- UGC Safety V1 — content_reports (moderasyon kuyruğu) + user_blocks.
--
-- Amaç: kullanıcı üretimli içerikte şikayet + kullanıcı engelleme altyapısı
-- (App Store Guideline 1.2). İçerik OTOMATİK silinmez; report'lar pending
-- statüsüyle kuyruğa düşer. Admin review UI P2 — veri modeli hazır.
--
-- Mevcut tablolara/policy'lere DOKUNULMAZ. Geri dönüş:
--   drop table if exists public.content_reports;
--   drop table if exists public.user_blocks;
-- =============================================================================

-- ─── 1. content_reports ─────────────────────────────────────────────────────
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  -- Şikayet edilen içeriğin sahibi (profil raporunda hedefin kendisi).
  reported_user_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in
    ('feed_post','comment','group_message','market_listing','job_listing','profile')),
  target_id uuid not null,
  reason text not null check (reason in
    ('spam','harassment','hate','scam','inappropriate_media',
     'illegal_or_dangerous','privacy','other')),
  details text check (details is null or char_length(details) <= 1000),
  status text not null default 'pending' check (status in
    ('pending','reviewed','dismissed','action_taken')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_id uuid,
  metadata jsonb,
  -- Aynı kullanıcı aynı hedefi bir kez şikayet edebilir (duplicate guard).
  constraint content_reports_unique_per_target
    unique (reporter_id, target_type, target_id)
);

comment on table public.content_reports is
  'UGC Safety V1 — şikayet/moderasyon kuyruğu. İçerik otomatik silinmez; '
  'status pending ile kuyruğa düşer. Review service-role/admin (P2 UI).';

-- Moderasyon kuyruğu sorgusu (status + tarih).
create index content_reports_queue_idx
  on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;

-- INSERT: yalnız kendi adına, pending + review alanları boş.
create policy content_reports_insert_own
  on public.content_reports
  for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and status = 'pending'
    and reviewed_at is null
    and reviewer_id is null
  );

-- SELECT: yalnız kendi report'ları (duplicate feedback + "şikayetlerim").
create policy content_reports_select_own
  on public.content_reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- UPDATE/DELETE policy YOK → kullanıcı kuyruğu manipüle edemez;
-- moderasyon service-role ile çalışır.

grant select, insert on public.content_reports to authenticated;

-- ─── 2. user_blocks ──────────────────────────────────────────────────────────
create table public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_unique unique (blocker_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_user_id)
);

comment on table public.user_blocks is
  'UGC Safety V1 — kullanıcı engelleme. Engelleyen, engellenenin feed/yorum/'
  'grup içeriklerini görmez (client filter V1); mesaj başlatma engellenir.';

create index user_blocks_blocker_idx on public.user_blocks (blocker_id);

alter table public.user_blocks enable row level security;

create policy user_blocks_insert_own
  on public.user_blocks
  for insert to authenticated
  with check (blocker_id = auth.uid());

create policy user_blocks_select_own
  on public.user_blocks
  for select to authenticated
  using (blocker_id = auth.uid());

-- DELETE = "Engeli kaldır".
create policy user_blocks_delete_own
  on public.user_blocks
  for delete to authenticated
  using (blocker_id = auth.uid());

grant select, insert, delete on public.user_blocks to authenticated;
