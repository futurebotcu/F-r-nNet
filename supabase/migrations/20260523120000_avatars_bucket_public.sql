-- =============================================================================
-- FırınNet Profile Self-Edit M3 — `avatars` storage bucket (public read)
-- =============================================================================
-- Hedef: kullanıcı kendi profil fotoğrafını yüklesin.
-- `profiles.avatar_url` sütunu zaten var; bu migration sadece storage
-- katmanını ekler.
--
-- Tasarım (feed-media + story-media şablonu birebir):
--   * Bucket: `avatars` public read.
--   * Path scheme: `{owner_id}/avatar_{timestamp}.{ext}`.
--   * SELECT: public — avatar başkalarının profile header'ında render olur.
--   * INSERT/UPDATE/DELETE: yalnız authenticated + path prefix owner.
--   * RLS sayesinde başka kullanıcı kendi klasörünüze upload edemez.
--
-- Public URL gizlilik notu: avatar zaten public profile (display_name +
-- profession_badge + city ile) ile birlikte gösteriliyor — public bucket
-- tercih edildi. cached_network_image direct URL erişimi için public bucket
-- gerekir; signed URL hardening V2 önerisi.
--
-- Geri dönüş:
--   drop policy if exists avatars_storage_select on storage.objects;
--   drop policy if exists avatars_storage_insert_owner on storage.objects;
--   drop policy if exists avatars_storage_update_owner on storage.objects;
--   drop policy if exists avatars_storage_delete_owner on storage.objects;
--   delete from storage.buckets where id = 'avatars';
-- =============================================================================

insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- SELECT: bucket public; herkes okuyabilir (CachedNetworkImage için).
drop policy if exists avatars_storage_select on storage.objects;
create policy avatars_storage_select
  on storage.objects
  for select to public
  using (bucket_id = 'avatars');

-- INSERT: yalnız authenticated; path prefix `{auth.uid()}/...` olmalı.
drop policy if exists avatars_storage_insert_owner on storage.objects;
create policy avatars_storage_insert_owner
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE: yalnız owner kendi path'i.
drop policy if exists avatars_storage_update_owner on storage.objects;
create policy avatars_storage_update_owner
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: yalnız owner kendi path'i.
drop policy if exists avatars_storage_delete_owner on storage.objects;
create policy avatars_storage_delete_owner
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
