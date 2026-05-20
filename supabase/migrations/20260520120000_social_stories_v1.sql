-- FırınNet — Social V2 Commit 2: Stories V1.
--
-- Donor: `packages/database_client/tables.sql` `public.stories` table +
-- `stories` storage bucket. FırınNet adaptasyonu:
--   * Table name: `feed_stories` (FırınNet `feed_*` konvansiyonu).
--   * Column name: `owner_id` (donor `user_id` yerine; FırınNet
--     `feed_posts/feed_comments` ile tutarlı).
--   * Sıkı RLS: donor'un `select using (true)` gevşekliği reddedildi.
--     Visible policy:
--       (is_deleted = false AND expires_at > now())
--         OR owner_id = auth.uid()
--     RETURNING phase'inde owner self soft-deleted/expired satırı görür
--     (P0 RLS RETURNING deneyiminden ders); diğer kullanıcılar yalnız
--     aktif + canlı story'leri görür.
--   * Soft-delete `is_deleted boolean default false` kolonu eklendi (donor
--     hard-delete + trigger storage cleanup yapıyor; FırınNet'te soft +
--     storage orphan kabul; cleanup ayrı cron task ile yapılabilir).
--   * 24h expiry: `expires_at timestamptz default (now() + interval '24 hours')`.
--   * Storage bucket: `story-media` (auth-only SELECT + path prefix
--     `{owner_id}/...` INSERT/DELETE policy ile).

-- 1) Story content type enum (image V1; video V2'ye doğru hazır).
create type story_content_type as enum ('image', 'video');

-- 2) feed_stories tablosu
create table public.feed_stories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  content_type story_content_type not null,
  content_url text not null,
  duration_ms integer,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index feed_stories_owner_id_created_at_idx
  on public.feed_stories (owner_id, created_at desc);

create index feed_stories_expires_at_idx
  on public.feed_stories (expires_at);

-- 3) Updated_at trigger (FırınNet konvansiyonu)
-- expires_at sabit, updated_at trigger gerekmiyor; pas geçildi.

-- 4) RLS aç ve policy'leri kur
alter table public.feed_stories enable row level security;

create policy feed_stories_select_visible
  on public.feed_stories
  for select
  using (
    (is_deleted = false and expires_at > now())
    or owner_id = auth.uid()
  );

create policy feed_stories_insert_self
  on public.feed_stories
  for insert
  with check (owner_id = auth.uid());

create policy feed_stories_update_own
  on public.feed_stories
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy feed_stories_delete_own
  on public.feed_stories
  for delete
  using (owner_id = auth.uid());

-- 5) Storage bucket: story-media (auth-only SELECT; owner path prefix
-- INSERT/DELETE/UPDATE)
insert into storage.buckets (id, name, public)
  values ('story-media', 'story-media', false)
  on conflict (id) do nothing;

create policy story_media_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'story-media');

create policy story_media_insert_owner_prefix
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'story-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy story_media_update_owner_prefix
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'story-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'story-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy story_media_delete_owner_prefix
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'story-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
