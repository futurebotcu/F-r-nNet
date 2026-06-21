-- ============================================================
-- Feed sprint — repost + recipe/announcement post tipleri (ADDITIVE)
-- ============================================================
-- Mevcut feed_likes / counter-trigger / RLS desenini birebir izler.
-- NOT: type CHECK genişletilirken `drop constraint` + `add constraint`
-- kullanılır — bu bir VERİ/TABLO/KOLON drop'u DEĞİL; constraint'i daha
-- geniş (additive) bir değer setine çıkarır. Mevcut tüm satırlar yeni
-- CHECK'i sağlar (production/question/equipment/... korunur).

-- ─────────────────────────────────────────────────────────
-- 1. feed_posts.type: recipe (Tarif) + announcement (Duyuru) ekle
-- ─────────────────────────────────────────────────────────
alter table public.feed_posts drop constraint if exists feed_posts_type_check;
alter table public.feed_posts add constraint feed_posts_type_check
  check (type = any (array[
    'production','question','supply','equipment','job','group_highlight',
    'recipe','announcement'
  ]));

-- ─────────────────────────────────────────────────────────
-- 2. feed_posts.repost_count
-- ─────────────────────────────────────────────────────────
alter table public.feed_posts
  add column if not exists repost_count integer not null default 0
    check (repost_count >= 0);

-- ─────────────────────────────────────────────────────────
-- 3. feed_reposts (feed_likes deseni — composite PK)
-- ─────────────────────────────────────────────────────────
create table if not exists public.feed_reposts (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, owner_id)
);

create index if not exists idx_feed_reposts_owner
  on public.feed_reposts (owner_id);

-- feed_posts.repost_count ← feed_reposts
create or replace function public.bump_feed_post_repost_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.feed_posts
      set repost_count = repost_count + 1
      where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.feed_posts
      set repost_count = greatest(repost_count - 1, 0)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;
revoke execute on function public.bump_feed_post_repost_count() from public;
revoke execute on function public.bump_feed_post_repost_count() from anon;
revoke execute on function public.bump_feed_post_repost_count()
  from authenticated;

drop trigger if exists trg_feed_reposts_bump_count on public.feed_reposts;
create trigger trg_feed_reposts_bump_count
  after insert or delete on public.feed_reposts
  for each row execute function public.bump_feed_post_repost_count();

-- ─────────────────────────────────────────────────────────
-- RLS — feed_reposts (feed_likes ile aynı: select all auth, self CUD)
-- ─────────────────────────────────────────────────────────
alter table public.feed_reposts enable row level security;

drop policy if exists feed_reposts_select_auth on public.feed_reposts;
create policy feed_reposts_select_auth on public.feed_reposts
  for select to authenticated
  using (true);

drop policy if exists feed_reposts_insert_self on public.feed_reposts;
create policy feed_reposts_insert_self on public.feed_reposts
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists feed_reposts_delete_self on public.feed_reposts;
create policy feed_reposts_delete_self on public.feed_reposts
  for delete to authenticated
  using (owner_id = auth.uid());

grant select, insert, update, delete on public.feed_reposts to authenticated;

comment on table public.feed_reposts is
  'FırınNet — gönderi repost (post_id, owner_id) composite. RLS: select all auth, insert/delete self.';
comment on column public.feed_posts.repost_count is
  'feed_reposts trigger ile tutulan repost sayısı.';
