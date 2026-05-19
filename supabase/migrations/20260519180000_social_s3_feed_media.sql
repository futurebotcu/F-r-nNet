-- =============================================================================
-- FırınNet Social S3 — Feed Media (Image V1)
-- =============================================================================
-- Feed post'a tek resim ekleme. V1 image only; V1.2'de video aynı tabloya
-- media_type = 'video' olarak eklenecek.
--
-- Tasarım:
--   * Tablo: public.feed_media — post_id (FK→feed_posts on delete cascade),
--     owner_id (FK→profiles), media_type CHECK ('image','video'),
--     storage_path (bucket göreceli yol), width/height/size_bytes nullable,
--     is_deleted soft-delete, created_at.
--   * Storage bucket: `feed-media` public read; INSERT/UPDATE/DELETE
--     authenticated + path prefix owner_id::text ile korumalı.
--   * Path scheme: `{owner_id}/{post_id}/{media_id}.{ext}`.
--   * RLS:
--     - SELECT: post görünürse media görünür (feed_posts.is_deleted=false
--       koşulu üzerinden EXISTS subquery).
--     - INSERT: owner_id = auth.uid() AND post sahibi de aynı kullanıcı
--       (cross-owner upload önlenir).
--     - UPDATE/DELETE: owner_id = auth.uid().
--
-- Donor kıyaslaması (itsezlife):
--   Donor `images(id, owner_id, url, blur_hash)` + `posts.media` text
--   ayrı tutmuş; biz daha normalleştirilmiş feed_media tablosuyla
--   single source of truth tutarız. Donor RLS'i `WITH CHECK (true)`
--   gevşek; FırınNet sıkı `owner_id = auth.uid()` standardı.
--
-- Geri dönüş:
--   drop policy if exists feed_media_select_visible on public.feed_media;
--   drop policy if exists feed_media_insert_self on public.feed_media;
--   drop policy if exists feed_media_update_own on public.feed_media;
--   drop policy if exists feed_media_delete_own on public.feed_media;
--   drop table if exists public.feed_media;
--   delete from storage.buckets where id = 'feed-media';
-- =============================================================================

create table public.feed_media (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.feed_posts(id) on delete cascade,
  owner_id      uuid not null references public.profiles(id) on delete cascade,
  media_type    text not null default 'image' check (media_type in ('image','video')),
  storage_path  text not null,
  width         integer,
  height        integer,
  size_bytes    bigint,
  is_deleted    boolean not null default false,
  created_at    timestamptz not null default now()
);

create index feed_media_post_visible_idx
  on public.feed_media (post_id, created_at asc)
  where is_deleted = false;

create index feed_media_owner_idx
  on public.feed_media (owner_id);

alter table public.feed_media enable row level security;

-- SELECT: media post görünürken görülür. Post is_deleted=true ise media
-- gizlenir (orphan görünmesin).
create policy feed_media_select_visible
  on public.feed_media
  for select to authenticated
  using (
    is_deleted = false
    and exists (
      select 1 from public.feed_posts p
      where p.id = feed_media.post_id
        and p.is_deleted = false
    )
  );

-- INSERT: yalnız owner kendi medyasını ekleyebilir; ayrıca ilgili post da
-- aynı owner'ın olmalı (cross-owner upload önlenir).
create policy feed_media_insert_self
  on public.feed_media
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.feed_posts p
      where p.id = post_id
        and p.owner_id = auth.uid()
        and p.is_deleted = false
    )
  );

create policy feed_media_update_own
  on public.feed_media
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy feed_media_delete_own
  on public.feed_media
  for delete to authenticated
  using (owner_id = auth.uid());

grant select, insert, update, delete on public.feed_media to authenticated;

comment on table public.feed_media is
  'V1 Social S3 — Feed post media (image V1; video V1.2). RLS: SELECT post '
  'visible iff post visible; INSERT/UPDATE/DELETE owner-only; INSERT '
  'cross-checks post owner.';

-- =============================================================================
-- Storage bucket: feed-media (public read, path-prefix protected writes)
-- =============================================================================

insert into storage.buckets (id, name, public)
  values ('feed-media', 'feed-media', true)
on conflict (id) do nothing;

-- SELECT: bucket public; herkes okuyabilir (cached_network_image için).
-- Authenticated kontrolüne gerek yok (post zaten public select RLS'iyle
-- gating'li; storage object URL'i yalnız o post'a bakan kullanıcıların
-- ulaşabildiği veridir).
drop policy if exists feed_media_storage_select on storage.objects;
create policy feed_media_storage_select
  on storage.objects
  for select to public
  using (bucket_id = 'feed-media');

-- INSERT: yalnız authenticated; path prefix `{auth.uid()}/...` olmalı.
drop policy if exists feed_media_storage_insert_owner on storage.objects;
create policy feed_media_storage_insert_owner
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'feed-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE: yalnız owner kendi path'i.
drop policy if exists feed_media_storage_update_owner on storage.objects;
create policy feed_media_storage_update_owner
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'feed-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'feed-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: yalnız owner kendi path'i.
drop policy if exists feed_media_storage_delete_owner on storage.objects;
create policy feed_media_storage_delete_owner
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'feed-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

comment on column public.feed_media.storage_path is
  'feed-media bucket''ı içinde göreceli yol. Format: '
  '{owner_id}/{post_id}/{media_id}.{ext}. Public URL: '
  'getPublicUrl(storage_path) ile elde edilir.';
