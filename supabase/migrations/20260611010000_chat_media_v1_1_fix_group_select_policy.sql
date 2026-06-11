-- =============================================================================
-- Chat Media V1.1 — P0 fix: group media SELECT policy column shadowing.
--
-- Bug: chat_media_v1 policy'sindeki EXISTS subquery içinde çıplak `name`,
-- `social_groups g`'nin name KOLONUNA bağlanıyordu (storage.objects.name
-- yerine). foldername(g.name)[2] her zaman null → tüm groups/* objelerinde
-- SELECT reddi → signed URL üretilemiyor → grup medyası UI'da emoji-text
-- fallback olarak kalıyordu. Fix: `objects.name` açıkça nitelendi.
-- Semantik aynı: public grup → authenticated; private → owner/üye.
--
-- Geri dönüş: bu dosyadaki policy'yi 20260610170000_chat_media_v1.sql'deki
-- önceki tanımla yeniden oluştur.
-- =============================================================================

drop policy if exists chat_media_storage_select on storage.objects;
create policy chat_media_storage_select
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      (
        (storage.foldername(objects.name))[1] = 'conversations'
        and public.is_in_conversation(((storage.foldername(objects.name))[2])::uuid)
      )
      or (
        (storage.foldername(objects.name))[1] = 'groups'
        and exists (
          select 1 from public.social_groups g
          where g.id = ((storage.foldername(objects.name))[2])::uuid
            and g.is_deleted = false
            and (
              g.is_private = false
              or g.owner_id = auth.uid()
              or public.is_group_member(g.id, auth.uid())
            )
        )
      )
    )
  );
