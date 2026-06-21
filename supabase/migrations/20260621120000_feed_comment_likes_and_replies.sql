-- ============================================================
-- Feed PR #2 — Yoruma beğeni + tek-seviye cevap (additive)
-- ============================================================
-- Mevcut feed_comments / feed_likes / counter-trigger / RLS desenini birebir
-- izler. Kararlar:
--   1) Cevaplar feed_posts.comment_count'a DAHİL (mevcut
--      bump_feed_post_comment_count tüm yorumları sayar → ek değişiklik yok).
--   2) Üst yorum soft-delete olunca bağlı cevaplar da soft-delete (görünmez +
--      her cevap için comment_count düşer).
--   3) Yoruma beğeni sayısı herkese görünür (feed_likes deseni).
-- Tek seviye: bir cevabın parent'ı yine cevap olamaz (parent top-level olmalı).

-- ─────────────────────────────────────────────────────────
-- feed_comments: like_count + parent_comment_id
-- ─────────────────────────────────────────────────────────
alter table public.feed_comments
  add column if not exists like_count integer not null default 0
    check (like_count >= 0);

alter table public.feed_comments
  add column if not exists parent_comment_id uuid
    references public.feed_comments(id) on delete cascade;

create index if not exists idx_feed_comments_parent
  on public.feed_comments (parent_comment_id, created_at)
  where parent_comment_id is not null and is_deleted = false;

-- ─────────────────────────────────────────────────────────
-- Tek-seviye guard: cevabın parent'ı, aynı post'ta bir ÜST yorum olmalı.
-- ─────────────────────────────────────────────────────────
create or replace function public.enforce_single_level_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.parent_comment_id is not null then
    if new.parent_comment_id = new.id then
      raise exception 'comment cannot be its own parent';
    end if;
    if not exists (
      select 1 from public.feed_comments p
      where p.id = new.parent_comment_id
        and p.parent_comment_id is null     -- parent kendisi cevap olamaz
        and p.post_id = new.post_id         -- aynı gönderi
    ) then
      raise exception 'reply parent must be a top-level comment on same post';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_single_level_comment_reply() from public;
revoke execute on function public.enforce_single_level_comment_reply() from anon;
revoke execute on function public.enforce_single_level_comment_reply()
  from authenticated;

drop trigger if exists trg_feed_comments_single_level on public.feed_comments;
create trigger trg_feed_comments_single_level
  before insert or update on public.feed_comments
  for each row execute function public.enforce_single_level_comment_reply();

-- ─────────────────────────────────────────────────────────
-- Üst yorum soft-delete → cevapları da soft-delete (cascade).
-- Cevap update'leri parent'ı null olduğu için yeniden cascade tetiklemez.
-- Her cevabın is_deleted=true olması bump_feed_post_comment_count (UPDATE)
-- ile comment_count'u düşürür.
-- ─────────────────────────────────────────────────────────
create or replace function public.cascade_soft_delete_comment_replies()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_deleted = false
     and new.is_deleted = true
     and new.parent_comment_id is null then
    update public.feed_comments
      set is_deleted = true, updated_at = now()
      where parent_comment_id = new.id
        and is_deleted = false;
  end if;
  return new;
end;
$$;
revoke execute on function public.cascade_soft_delete_comment_replies()
  from public;
revoke execute on function public.cascade_soft_delete_comment_replies()
  from anon;
revoke execute on function public.cascade_soft_delete_comment_replies()
  from authenticated;

drop trigger if exists trg_feed_comments_cascade_soft_delete
  on public.feed_comments;
create trigger trg_feed_comments_cascade_soft_delete
  after update on public.feed_comments
  for each row execute function public.cascade_soft_delete_comment_replies();

-- ─────────────────────────────────────────────────────────
-- feed_comment_likes (post_likes deseni — composite PK)
-- ─────────────────────────────────────────────────────────
create table if not exists public.feed_comment_likes (
  comment_id uuid not null
    references public.feed_comments(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, owner_id)
);

create index if not exists idx_feed_comment_likes_owner
  on public.feed_comment_likes (owner_id);

-- feed_comments.like_count ← feed_comment_likes
create or replace function public.bump_feed_comment_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.feed_comments
      set like_count = like_count + 1
      where id = new.comment_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.feed_comments
      set like_count = greatest(like_count - 1, 0)
      where id = old.comment_id;
    return old;
  end if;
  return null;
end;
$$;
revoke execute on function public.bump_feed_comment_like_count() from public;
revoke execute on function public.bump_feed_comment_like_count() from anon;
revoke execute on function public.bump_feed_comment_like_count()
  from authenticated;

drop trigger if exists trg_feed_comment_likes_bump_count
  on public.feed_comment_likes;
create trigger trg_feed_comment_likes_bump_count
  after insert or delete on public.feed_comment_likes
  for each row execute function public.bump_feed_comment_like_count();

-- ─────────────────────────────────────────────────────────
-- RLS — feed_comment_likes (feed_likes ile aynı: select all auth, self CUD)
-- ─────────────────────────────────────────────────────────
alter table public.feed_comment_likes enable row level security;

drop policy if exists feed_comment_likes_select_auth on public.feed_comment_likes;
create policy feed_comment_likes_select_auth on public.feed_comment_likes
  for select to authenticated
  using (true);

drop policy if exists feed_comment_likes_insert_self on public.feed_comment_likes;
create policy feed_comment_likes_insert_self on public.feed_comment_likes
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_comment_likes_delete_self on public.feed_comment_likes;
create policy feed_comment_likes_delete_self on public.feed_comment_likes
  for delete to authenticated
  using (owner_id = auth.uid());

grant select, insert, update, delete on public.feed_comment_likes
  to authenticated;

comment on table public.feed_comment_likes is
  'FırınNet — yorum beğeni (comment_id, owner_id) composite. RLS: select all auth, insert/delete self.';
comment on column public.feed_comments.parent_comment_id is
  'Tek-seviye cevap: dolu ise üst yoruma cevap (parent top-level olmalı).';
comment on column public.feed_comments.like_count is
  'feed_comment_likes trigger ile tutulan yorum beğeni sayısı.';
