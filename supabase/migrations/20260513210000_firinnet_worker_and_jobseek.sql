-- ============================================================
-- FırınNet — Bireysel (Worker) profil + İş Arıyorum ilanları
-- Tarih: 2026-05-13
-- Amaç:
--   • worker_profiles — kullanıcı başına tekil ustalık profili
--   • worker_experiences — çalışma geçmişi kalemleri
--   • job_seek_posts — "iş arıyorum" ilanları (aktif olanları diğer
--     authenticated kullanıcılar görebilir)
--   • RLS owner CRUD; profil ve tecrübe authenticated read (sektör profili),
--     iş ilanı yalnız aktifse veya sahibinse okunabilir.
-- ============================================================

create table if not exists public.worker_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  profession_badge text,
  experience_years integer check (experience_years is null or experience_years >= 0),
  cities text[] not null default '{}',
  shift_preference text,
  salary_expectation numeric(12,2) check (salary_expectation is null or salary_expectation >= 0),
  work_type text,
  skills text[] not null default '{}',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.worker_experiences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  workplace text,
  city text,
  start_date date,
  end_date date,
  description text,
  created_at timestamptz not null default now()
);

create index if not exists idx_worker_experiences_owner_start
  on public.worker_experiences (owner_id, start_date desc nulls last);

create table if not exists public.job_seek_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  profession_badge text,
  city text,
  experience_years integer check (experience_years is null or experience_years >= 0),
  salary_expectation numeric(12,2) check (salary_expectation is null or salary_expectation >= 0),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_job_seek_posts_active_created
  on public.job_seek_posts (created_at desc)
  where is_active = true;
create index if not exists idx_job_seek_posts_owner
  on public.job_seek_posts (owner_id, created_at desc);

-- RLS
alter table public.worker_profiles    enable row level security;
alter table public.worker_experiences enable row level security;
alter table public.job_seek_posts     enable row level security;

-- worker_profiles: sektör için authenticated read serbest, edit owner-only.
drop policy if exists worker_profiles_select_auth on public.worker_profiles;
drop policy if exists worker_profiles_insert_own on public.worker_profiles;
drop policy if exists worker_profiles_update_own on public.worker_profiles;
drop policy if exists worker_profiles_delete_own on public.worker_profiles;
create policy worker_profiles_select_auth on public.worker_profiles
  for select to authenticated using (true);
create policy worker_profiles_insert_own on public.worker_profiles
  for insert to authenticated with check (owner_id = auth.uid());
create policy worker_profiles_update_own on public.worker_profiles
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy worker_profiles_delete_own on public.worker_profiles
  for delete to authenticated using (owner_id = auth.uid());

-- worker_experiences: aynı pattern (read serbest, edit owner-only)
drop policy if exists worker_experiences_select_auth on public.worker_experiences;
drop policy if exists worker_experiences_insert_own on public.worker_experiences;
drop policy if exists worker_experiences_update_own on public.worker_experiences;
drop policy if exists worker_experiences_delete_own on public.worker_experiences;
create policy worker_experiences_select_auth on public.worker_experiences
  for select to authenticated using (true);
create policy worker_experiences_insert_own on public.worker_experiences
  for insert to authenticated with check (owner_id = auth.uid());
create policy worker_experiences_update_own on public.worker_experiences
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy worker_experiences_delete_own on public.worker_experiences
  for delete to authenticated using (owner_id = auth.uid());

-- job_seek_posts: aktif olanlar authenticated, hepsi owner; edit owner-only.
drop policy if exists job_seek_posts_select_active_or_own on public.job_seek_posts;
drop policy if exists job_seek_posts_insert_own on public.job_seek_posts;
drop policy if exists job_seek_posts_update_own on public.job_seek_posts;
drop policy if exists job_seek_posts_delete_own on public.job_seek_posts;
create policy job_seek_posts_select_active_or_own on public.job_seek_posts
  for select to authenticated using (is_active = true or owner_id = auth.uid());
create policy job_seek_posts_insert_own on public.job_seek_posts
  for insert to authenticated with check (owner_id = auth.uid());
create policy job_seek_posts_update_own on public.job_seek_posts
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy job_seek_posts_delete_own on public.job_seek_posts
  for delete to authenticated using (owner_id = auth.uid());

comment on table public.worker_profiles is
  'FırınNet V1.2 — bireysel ustalık profili (rol, tecrübe yılı, şehirler, beceriler). read serbest, edit owner.';
comment on table public.worker_experiences is
  'FırınNet V1.2 — usta çalışma geçmişi kalemleri. read serbest, edit owner.';
comment on table public.job_seek_posts is
  'FırınNet V1.2 — iş arıyorum ilanı. aktif ise authenticated read; edit owner.';
