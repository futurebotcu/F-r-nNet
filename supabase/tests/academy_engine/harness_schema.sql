-- Akademi motoru izole test harness'ı — Supabase mock'ları + önkoşul tablolar.
-- Yalnız academy migration'larının (20260713 + 20260929) bağımlılıkları
-- mock'lanır; gerçek migration dosyaları bunun ÜZERİNE uygulanır.

create schema if not exists auth;

create table if not exists auth.users (
  instance_id uuid,
  id uuid primary key,
  aud text,
  role text,
  email text unique,
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb default '{}'::jsonb,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  confirmation_token text default '',
  recovery_token text default '',
  email_change_token_new text default '',
  email_change text default '',
  email_change_token_current text default '',
  phone_change text default '',
  phone_change_token text default '',
  reauthentication_token text default ''
);

create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    -- service_role mock'una BYPASSRLS şart (prod davranış aynası).
    create role service_role nologin bypassrls;
  end if;
end
$$;
grant usage on schema public, auth to anon, authenticated, service_role;
grant select on auth.users to service_role;
grant insert, update on auth.users to service_role;

-- ── profiles (auth handler trigger'ının prod'da oluşturduğu satırlar) ──
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  account_type text not null default 'individual',
  is_bot boolean not null default false, -- prod'da A1 ekler; harness hazır tutar
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy profiles_select_all on public.profiles
  for select to authenticated using (true);
grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.profiles to service_role;

-- ── feed_posts + author snapshot trigger (prod davranış aynası) ──
create table if not exists public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'announcement',
  text text not null default '',
  tags text[] not null default '{}',
  author_name text not null default '',
  author_role text not null default '',
  like_count int not null default 0,
  comment_count int not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.feed_posts enable row level security;
create policy feed_posts_select_all on public.feed_posts
  for select to authenticated using (is_deleted = false);
create policy feed_posts_insert_self on public.feed_posts
  for insert to authenticated with check (owner_id = auth.uid());
grant select, insert on public.feed_posts to authenticated;
grant select, insert, update, delete on public.feed_posts to service_role;

create or replace function public.snapshot_feed_post_author()
returns trigger
language plpgsql
security definer
as $$
begin
  if coalesce(new.author_name, '') = '' then
    select coalesce(nullif(p.display_name, ''), 'FırınNet Kullanıcısı')
      into new.author_name
      from public.profiles p where p.id = new.owner_id;
    new.author_name := coalesce(new.author_name, 'FırınNet Kullanıcısı');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_feed_posts_author on public.feed_posts;
create trigger trg_feed_posts_author
  before insert on public.feed_posts
  for each row execute function public.snapshot_feed_post_author();

create table if not exists public.feed_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  media_type text not null default 'image',
  storage_path text not null,
  width int, height int, size_bytes bigint,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.feed_media enable row level security;
grant select, insert, update, delete on public.feed_media to service_role;

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  author_name text not null default '',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.feed_comments enable row level security;
create policy feed_comments_insert_self on public.feed_comments
  for insert to authenticated with check (owner_id = auth.uid());
grant select, insert on public.feed_comments to authenticated;
grant select, insert, update, delete on public.feed_comments to service_role;

-- ── UGC safety / mesajlaşma önkoşulları ──
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id)
);
alter table public.user_blocks enable row level security;
grant select, insert, delete on public.user_blocks to service_role;

create table if not exists public.market_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  is_deleted boolean not null default false
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct',
  context_type text not null default 'profile_direct',
  context_id uuid,
  created_by uuid not null,
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_participants (
  conversation_id uuid not null
    references public.conversations(id) on delete cascade,
  user_id uuid not null,
  role text not null default 'member',
  primary key (conversation_id, user_id)
);
grant select, insert on public.conversations,
  public.conversation_participants to authenticated, service_role;

-- ── app_runtime_config + okuyucular (20260923 aynası) ──
create table if not exists public.app_runtime_config (
  key text primary key,
  value jsonb,
  updated_at timestamptz not null default now()
);
alter table public.app_runtime_config enable row level security;
grant select, insert, update, delete on public.app_runtime_config
  to service_role;

create or replace function public.app_config_int(p_key text, p_default int)
returns int
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select nullif(value #>> '{}', 'null')::int
       from public.app_runtime_config where key = p_key), p_default);
$$;
create or replace function public.app_config_bool(
  p_key text, p_default boolean)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select nullif(value #>> '{}', 'null')::boolean
       from public.app_runtime_config where key = p_key), p_default);
$$;
create or replace function public.app_config_timestamptz(
  p_key text, p_default timestamptz)
returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select nullif(value #>> '{}', 'null')::timestamptz
       from public.app_runtime_config where key = p_key), p_default);
$$;
grant execute on function public.app_config_int(text, int),
  public.app_config_bool(text, boolean),
  public.app_config_timestamptz(text, timestamptz)
  to authenticated, service_role;

-- ── find_or_create_direct_conversation'ın 20260612 tabanı (academy
--    migration'ı bunu yeniden tanımlar; taban davranış testi için yükle) ──
-- (20260929 create or replace ettiği için burada tanımlamak şart değil.)

-- ── Test kullanıcıları ──
insert into auth.users (id, email, confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token) values
  ('00000000-0000-4000-8000-000000000001', 'u1@test.local',
   '','','','','','','',''),
  ('00000000-0000-4000-8000-000000000002', 'u2@test.local',
   '','','','','','','','')
on conflict do nothing;
insert into public.profiles (id, display_name, account_type) values
  ('00000000-0000-4000-8000-000000000001', 'Kullanıcı Bir', 'individual'),
  ('00000000-0000-4000-8000-000000000002', 'Kullanıcı İki', 'commercial')
on conflict do nothing;
