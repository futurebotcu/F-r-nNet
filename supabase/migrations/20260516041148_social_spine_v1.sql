-- Migration: social_spine_v1
-- Version: 20260516041148
-- Applied to remote: 2026-05-16 via MCP apply_migration.
-- Lokal dosya adı remote version ile eşitlendi (önceki taslak version 20260515120000 idi).
-- Apply sonrası bulunan P0 RLS bypass için ek migration:
--   20260516043809_social_spine_v1_fix_group_messages_insert.sql
-- Detay: SOCIAL_SPINE_LIVE_SMOKE_REPORT.md
--
-- FırınNet — Sosyal Omurga V1 (Feed + Sosyal Gruplar)
-- ----------------------------------------------------
-- Tablolar:
--   feed_posts, feed_likes, feed_saves, feed_comments,
--   social_groups, group_members, group_messages.
--
-- Tasarım kararları:
--   * profiles RLS owner-only olarak korunuyor (auth modülüne dokunmadık).
--     Diğer kullanıcıların display_name/profession_badge bilgisi feed/group
--     satırına BEFORE INSERT triggerla snapshot edilir (`author_name`,
--     `author_role`, social_groups.`owner_name`).
--   * Email, avatar_url, city gibi profil alanları feed/group satırına
--     yazılmaz; sızıntı yok.
--   * Tüm tablolarda RLS açık. authenticated rolüne owner-only DML.
--     anon role'üne hiç DML yok (sadece olası `usage on schema public`
--     mevcut grant'tan miras).
--   * feed_posts.like_count + comment_count, social_groups.member_count
--     denormalize sayaçlar; feed_likes / feed_comments / group_members
--     üzerindeki AFTER triggerlarla atomik güncellenir.
--   * group_members INSERT için BEFORE trigger max_members aşımını
--     engeller.
--   * Tüm SECURITY DEFINER fonksiyonlarda `set search_path = public` +
--     `revoke execute from public, anon, authenticated`.
--
-- Geri dönüş:
--   drop trigger ... on ...;  drop function ... cascade;  drop table ... cascade;
--   (Detay için her bölümün altında ROLLBACK yorumu).

create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- feed_posts
-- ============================================================
create table public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'question'
    check (type in ('production','question','supply','equipment','job','group_highlight')),
  text text not null,
  tags text[] not null default '{}'::text[],
  -- group_id FK constraint social_groups CREATE TABLE'dan SONRA ALTER ile eklenir
  -- (aşağıda). Bu sıralama hayati: feed_posts üst kısımda tanımlanıyor ama
  -- social_groups daha aşağıda; ileri-referans hata vermesin diye burada FK yok.
  group_id uuid,
  group_name text,
  -- Denormalize author snapshot — BEFORE INSERT trigger doldurur.
  author_name text not null default '',
  author_role text not null default '',
  like_count integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_feed_posts_created_visible
  on public.feed_posts (created_at desc)
  where is_deleted = false;
create index idx_feed_posts_owner_created
  on public.feed_posts (owner_id, created_at desc);
create index idx_feed_posts_type
  on public.feed_posts (type) where is_deleted = false;
create index idx_feed_posts_group
  on public.feed_posts (group_id) where group_id is not null and is_deleted = false;

-- ============================================================
-- feed_likes  (composite PK)
-- ============================================================
create table public.feed_likes (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, owner_id)
);

create index idx_feed_likes_owner on public.feed_likes (owner_id);

-- ============================================================
-- feed_saves  (composite PK)
-- ============================================================
create table public.feed_saves (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, owner_id)
);

create index idx_feed_saves_owner on public.feed_saves (owner_id);

-- ============================================================
-- feed_comments
-- ============================================================
create table public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  -- Denormalize author snapshot
  author_name text not null default '',
  author_role text not null default '',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_feed_comments_post_created
  on public.feed_comments (post_id, created_at)
  where is_deleted = false;
create index idx_feed_comments_owner
  on public.feed_comments (owner_id);

-- ============================================================
-- social_groups
-- ============================================================
create table public.social_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text not null default '',
  -- category Flutter enum'una bağlı; bilinmeyen değer fallback'le 'bakers'.
  category text not null default 'general',
  city text,
  is_private boolean not null default false,
  max_members integer not null default 250 check (max_members > 0),
  tags text[] not null default '{}'::text[],
  visual_seed integer not null default 0,
  -- Denormalize owner snapshot — BEFORE INSERT trigger doldurur.
  owner_name text not null default '',
  -- Denormalize üye sayısı — group_members triggerla bakım eder.
  member_count integer not null default 0 check (member_count >= 0),
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_social_groups_created_visible
  on public.social_groups (created_at desc)
  where is_deleted = false;
create index idx_social_groups_category
  on public.social_groups (category) where is_deleted = false;
create index idx_social_groups_owner
  on public.social_groups (owner_id);

-- feed_posts.group_id FK referansını şimdi ekleyebiliriz; social_groups
-- artık var. Ancak CREATE TABLE üst kısmında `references social_groups(id)`
-- yazdık → tabloyu sonradan oluşturduğumuz için ileri-referans hatası
-- oluşurdu. Bu yüzden feed_posts tablosu social_groups'tan SONRA tanımlanmalı
-- veya FK ALTER TABLE ile sonradan eklenmeli. Üst kısımdaki feed_posts
-- tanımında zaten "references public.social_groups(id)" yazdık; bunu
-- sosyal grup tanımı sonrası ALTER TABLE ile yine doğrulamak için
-- yedek tedbir olarak constraint validate çağırıyoruz. Eğer migration
-- sırayla işlerse zaten sorun olmaz. Aksi durumda aşağıdaki ALTER NO-OP
-- görünmez bir constraint kontrolü yapar:
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'feed_posts_group_id_fkey'
  ) then
    alter table public.feed_posts
      add constraint feed_posts_group_id_fkey
      foreign key (group_id) references public.social_groups(id) on delete set null;
  end if;
end$$;

-- ============================================================
-- group_members
-- ============================================================
create table public.group_members (
  group_id uuid not null references public.social_groups(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner','moderator','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, owner_id)
);

create index idx_group_members_owner on public.group_members (owner_id);

-- ============================================================
-- group_messages
-- ============================================================
create table public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.social_groups(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  -- Denormalize author snapshot
  author_name text not null default '',
  author_role text not null default '',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_group_messages_group_created
  on public.group_messages (group_id, created_at)
  where is_deleted = false;
create index idx_group_messages_owner
  on public.group_messages (owner_id);

-- ============================================================
-- Generic updated_at trigger (re-uses existing set_updated_at if present)
-- ============================================================
create trigger trg_feed_posts_updated_at
  before update on public.feed_posts
  for each row execute function public.set_updated_at();

create trigger trg_feed_comments_updated_at
  before update on public.feed_comments
  for each row execute function public.set_updated_at();

create trigger trg_social_groups_updated_at
  before update on public.social_groups
  for each row execute function public.set_updated_at();

create trigger trg_group_messages_updated_at
  before update on public.group_messages
  for each row execute function public.set_updated_at();

-- ============================================================
-- Author snapshot triggers (feed_posts, feed_comments, group_messages,
-- social_groups owner_name) — yalnız INSERT'te çalışır.
-- SECURITY DEFINER çünkü profiles RLS owner-only; bu trigger profiles
-- satırını yalnız okuyup public alanları snapshot eder.
-- ============================================================

create or replace function public.snapshot_feed_post_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_badge text;
  v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account
  from public.profiles
  where id = new.owner_id;

  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet Kullanıcısı');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial'  then 'Ticari'
      when 'wholesaler'  then 'Toptancı'
      when 'individual'  then 'Bireysel'
      else 'Üye'
    end
  );
  return new;
end;
$$;
revoke execute on function public.snapshot_feed_post_author() from public;
revoke execute on function public.snapshot_feed_post_author() from anon;
revoke execute on function public.snapshot_feed_post_author() from authenticated;

create trigger trg_feed_posts_snapshot_author
  before insert on public.feed_posts
  for each row execute function public.snapshot_feed_post_author();

-- feed_comments için aynı snapshot davranışı (tek fonksiyon yeniden
-- kullanılamaz çünkü tablo tipi NEW farklı; aynı pattern'de ayrı fonksiyon).
create or replace function public.snapshot_feed_comment_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_badge text;
  v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account
  from public.profiles
  where id = new.owner_id;

  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet Kullanıcısı');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial'  then 'Ticari'
      when 'wholesaler'  then 'Toptancı'
      when 'individual'  then 'Bireysel'
      else 'Üye'
    end
  );
  return new;
end;
$$;
revoke execute on function public.snapshot_feed_comment_author() from public;
revoke execute on function public.snapshot_feed_comment_author() from anon;
revoke execute on function public.snapshot_feed_comment_author() from authenticated;

create trigger trg_feed_comments_snapshot_author
  before insert on public.feed_comments
  for each row execute function public.snapshot_feed_comment_author();

create or replace function public.snapshot_group_message_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_badge text;
  v_account text;
begin
  select
    coalesce(nullif(trim(display_name), ''), ''),
    coalesce(nullif(trim(profession_badge), ''), ''),
    coalesce(nullif(trim(account_type), ''), '')
  into v_name, v_badge, v_account
  from public.profiles
  where id = new.owner_id;

  new.author_name := coalesce(nullif(v_name, ''), 'FırınNet Kullanıcısı');
  new.author_role := coalesce(
    nullif(v_badge, ''),
    case v_account
      when 'commercial'  then 'Ticari'
      when 'wholesaler'  then 'Toptancı'
      when 'individual'  then 'Bireysel'
      else 'Üye'
    end
  );
  return new;
end;
$$;
revoke execute on function public.snapshot_group_message_author() from public;
revoke execute on function public.snapshot_group_message_author() from anon;
revoke execute on function public.snapshot_group_message_author() from authenticated;

create trigger trg_group_messages_snapshot_author
  before insert on public.group_messages
  for each row execute function public.snapshot_group_message_author();

create or replace function public.snapshot_social_group_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  select coalesce(nullif(trim(display_name), ''), '')
  into v_name
  from public.profiles
  where id = new.owner_id;
  new.owner_name := coalesce(nullif(v_name, ''), 'FırınNet Kullanıcısı');
  return new;
end;
$$;
revoke execute on function public.snapshot_social_group_owner() from public;
revoke execute on function public.snapshot_social_group_owner() from anon;
revoke execute on function public.snapshot_social_group_owner() from authenticated;

create trigger trg_social_groups_snapshot_owner
  before insert on public.social_groups
  for each row execute function public.snapshot_social_group_owner();

-- ============================================================
-- Counter triggers
-- ============================================================

-- feed_posts.like_count  ←  feed_likes
create or replace function public.bump_feed_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.feed_posts
      set like_count = like_count + 1
      where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.feed_posts
      set like_count = greatest(like_count - 1, 0)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;
revoke execute on function public.bump_feed_post_like_count() from public;
revoke execute on function public.bump_feed_post_like_count() from anon;
revoke execute on function public.bump_feed_post_like_count() from authenticated;

create trigger trg_feed_likes_bump_count
  after insert or delete on public.feed_likes
  for each row execute function public.bump_feed_post_like_count();

-- feed_posts.comment_count  ←  feed_comments (sadece is_deleted=false)
create or replace function public.bump_feed_post_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.is_deleted = false then
      update public.feed_posts
        set comment_count = comment_count + 1
        where id = new.post_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.is_deleted = false then
      update public.feed_posts
        set comment_count = greatest(comment_count - 1, 0)
        where id = old.post_id;
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    if old.is_deleted = false and new.is_deleted = true then
      update public.feed_posts
        set comment_count = greatest(comment_count - 1, 0)
        where id = new.post_id;
    elsif old.is_deleted = true and new.is_deleted = false then
      update public.feed_posts
        set comment_count = comment_count + 1
        where id = new.post_id;
    end if;
    return new;
  end if;
  return null;
end;
$$;
revoke execute on function public.bump_feed_post_comment_count() from public;
revoke execute on function public.bump_feed_post_comment_count() from anon;
revoke execute on function public.bump_feed_post_comment_count() from authenticated;

create trigger trg_feed_comments_bump_count
  after insert or update or delete on public.feed_comments
  for each row execute function public.bump_feed_post_comment_count();

-- social_groups.member_count  ←  group_members
create or replace function public.bump_social_group_member_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.social_groups
      set member_count = member_count + 1
      where id = new.group_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.social_groups
      set member_count = greatest(member_count - 1, 0)
      where id = old.group_id;
    return old;
  end if;
  return null;
end;
$$;
revoke execute on function public.bump_social_group_member_count() from public;
revoke execute on function public.bump_social_group_member_count() from anon;
revoke execute on function public.bump_social_group_member_count() from authenticated;

create trigger trg_group_members_bump_count
  after insert or delete on public.group_members
  for each row execute function public.bump_social_group_member_count();

-- ============================================================
-- group_members max_members enforcement (BEFORE INSERT)
-- ============================================================
create or replace function public.enforce_group_max_members()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max integer;
  v_current integer;
  v_deleted boolean;
begin
  select max_members, is_deleted
    into v_max, v_deleted
    from public.social_groups
    where id = new.group_id;

  if v_max is null then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
  if v_deleted then
    raise exception 'group_deleted' using errcode = 'P0002';
  end if;

  select count(*) into v_current
    from public.group_members
    where group_id = new.group_id;

  if v_current >= v_max then
    raise exception 'group_full' using errcode = 'P0001';
  end if;

  return new;
end;
$$;
revoke execute on function public.enforce_group_max_members() from public;
revoke execute on function public.enforce_group_max_members() from anon;
revoke execute on function public.enforce_group_max_members() from authenticated;

create trigger trg_group_members_enforce_max
  before insert on public.group_members
  for each row execute function public.enforce_group_max_members();

-- ============================================================
-- RLS — enable on all tables
-- ============================================================
alter table public.feed_posts        enable row level security;
alter table public.feed_likes        enable row level security;
alter table public.feed_saves        enable row level security;
alter table public.feed_comments     enable row level security;
alter table public.social_groups     enable row level security;
alter table public.group_members     enable row level security;
alter table public.group_messages    enable row level security;

-- ─────────────────────────────────────────────────────────
-- feed_posts policies
-- SELECT: authenticated görür eğer is_deleted=false.
-- Sosyal akış için kasıtlı serbest. (anon yok.)
-- ─────────────────────────────────────────────────────────
drop policy if exists feed_posts_select_visible on public.feed_posts;
create policy feed_posts_select_visible on public.feed_posts
  for select to authenticated
  using (is_deleted = false);

drop policy if exists feed_posts_insert_self on public.feed_posts;
create policy feed_posts_insert_self on public.feed_posts
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_posts_update_own on public.feed_posts;
create policy feed_posts_update_own on public.feed_posts
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists feed_posts_delete_own on public.feed_posts;
create policy feed_posts_delete_own on public.feed_posts
  for delete to authenticated
  using (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────
-- feed_likes policies
-- ─────────────────────────────────────────────────────────
drop policy if exists feed_likes_select_auth on public.feed_likes;
create policy feed_likes_select_auth on public.feed_likes
  for select to authenticated
  using (true);

drop policy if exists feed_likes_insert_self on public.feed_likes;
create policy feed_likes_insert_self on public.feed_likes
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_likes_delete_self on public.feed_likes;
create policy feed_likes_delete_self on public.feed_likes
  for delete to authenticated
  using (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────
-- feed_saves policies
-- ─────────────────────────────────────────────────────────
drop policy if exists feed_saves_select_self on public.feed_saves;
create policy feed_saves_select_self on public.feed_saves
  for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists feed_saves_insert_self on public.feed_saves;
create policy feed_saves_insert_self on public.feed_saves
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_saves_delete_self on public.feed_saves;
create policy feed_saves_delete_self on public.feed_saves
  for delete to authenticated
  using (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────
-- feed_comments policies
-- ─────────────────────────────────────────────────────────
drop policy if exists feed_comments_select_visible on public.feed_comments;
create policy feed_comments_select_visible on public.feed_comments
  for select to authenticated
  using (is_deleted = false);

drop policy if exists feed_comments_insert_self on public.feed_comments;
create policy feed_comments_insert_self on public.feed_comments
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_comments_update_own on public.feed_comments;
create policy feed_comments_update_own on public.feed_comments
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists feed_comments_delete_own on public.feed_comments;
create policy feed_comments_delete_own on public.feed_comments
  for delete to authenticated
  using (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────
-- social_groups policies
-- SELECT: is_deleted=false ve (public veya owner veya member ise).
-- ─────────────────────────────────────────────────────────
drop policy if exists social_groups_select_visible on public.social_groups;
create policy social_groups_select_visible on public.social_groups
  for select to authenticated
  using (
    is_deleted = false
    and (
      is_private = false
      or owner_id = auth.uid()
      or exists (
        select 1 from public.group_members gm
        where gm.group_id = id and gm.owner_id = auth.uid()
      )
    )
  );

drop policy if exists social_groups_insert_self on public.social_groups;
create policy social_groups_insert_self on public.social_groups
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists social_groups_update_own on public.social_groups;
create policy social_groups_update_own on public.social_groups
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists social_groups_delete_own on public.social_groups;
create policy social_groups_delete_own on public.social_groups
  for delete to authenticated
  using (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────
-- group_members policies
-- SELECT: grup public ise veya kullanıcı kendi satırı/grup sahibi/üyesi ise.
-- INSERT: yalnız owner_id = auth.uid() (kendin için).
-- DELETE: kendi satırın veya grup sahibi.
-- ─────────────────────────────────────────────────────────
drop policy if exists group_members_select_visible on public.group_members;
create policy group_members_select_visible on public.group_members
  for select to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.social_groups g
      where g.id = group_id
        and g.is_deleted = false
        and (
          g.is_private = false
          or g.owner_id = auth.uid()
          or exists (
            select 1 from public.group_members gm2
            where gm2.group_id = g.id and gm2.owner_id = auth.uid()
          )
        )
    )
  );

drop policy if exists group_members_insert_self on public.group_members;
create policy group_members_insert_self on public.group_members
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.social_groups g
      where g.id = group_id and g.is_deleted = false
    )
  );

drop policy if exists group_members_delete_self_or_owner on public.group_members;
create policy group_members_delete_self_or_owner on public.group_members
  for delete to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.social_groups g
      where g.id = group_id and g.owner_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────
-- group_messages policies
-- SELECT: is_deleted=false ve grup public veya member ise.
-- INSERT: member ise.
-- UPDATE/DELETE: yalnız mesaj sahibi.
-- ─────────────────────────────────────────────────────────
drop policy if exists group_messages_select_visible on public.group_messages;
create policy group_messages_select_visible on public.group_messages
  for select to authenticated
  using (
    is_deleted = false
    and exists (
      select 1 from public.social_groups g
      where g.id = group_id
        and g.is_deleted = false
        and (
          g.is_private = false
          or g.owner_id = auth.uid()
          or exists (
            select 1 from public.group_members gm
            where gm.group_id = g.id and gm.owner_id = auth.uid()
          )
        )
    )
  );

drop policy if exists group_messages_insert_member on public.group_messages;
create policy group_messages_insert_member on public.group_messages
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = group_id and gm.owner_id = auth.uid()
    )
  );

drop policy if exists group_messages_update_own on public.group_messages;
create policy group_messages_update_own on public.group_messages
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists group_messages_delete_own on public.group_messages;
create policy group_messages_delete_own on public.group_messages
  for delete to authenticated
  using (owner_id = auth.uid());

-- ============================================================
-- Grants — authenticated CRUD, anon hiç
-- ============================================================
grant select, insert, update, delete on
  public.feed_posts,
  public.feed_likes,
  public.feed_saves,
  public.feed_comments,
  public.social_groups,
  public.group_members,
  public.group_messages
to authenticated;

-- anon role'üne hiçbir DML verilmez (default-deny). Mevcut V1 grant migration'ı
-- `alter default privileges in schema public grant ... to authenticated` koyduğu
-- için ALTER yine de authenticated için işler. anon'a explicit revoke gerekmez
-- çünkü grant edilmedi.

-- ============================================================
-- Comments
-- ============================================================
comment on table public.feed_posts is
  'FırınNet — sektör akışı gönderileri. RLS: anyone authenticated select, owner CRUD.';
comment on table public.feed_likes is
  'FırınNet — feed beğeni (post_id, owner_id) composite. RLS: select all auth, insert/delete self.';
comment on table public.feed_saves is
  'FırınNet — feed bookmark. RLS: select/insert/delete self.';
comment on table public.feed_comments is
  'FırınNet — feed yorumları. RLS: select visible, insert/update/delete owner.';
comment on table public.social_groups is
  'FırınNet — sektör grupları. RLS: select public/owner/member, owner CRUD.';
comment on table public.group_members is
  'FırınNet — grup üyeleri. RLS: select visible to scope, insert self, delete self or group owner.';
comment on table public.group_messages is
  'FırınNet — grup mesajları. RLS: select if visible, insert if member, owner update/delete.';
