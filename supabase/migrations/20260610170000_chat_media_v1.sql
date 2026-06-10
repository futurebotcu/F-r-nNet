-- =============================================================================
-- FırınNet Chat Media V1 — Image attachments for generic + group chat
-- =============================================================================
-- Sprint G. Hem generic messaging (conversations/messages) hem grup sohbeti
-- (social_groups/group_messages) için RESİM eki. Video V1.1'e ertelendi.
--
-- Tasarım kararları (en az şema yüzeyi, mevcut hardening korunur):
--   * GENERIC: `public.messages.attachments jsonb` kolonu ZATEN var
--     (messaging_m1_generic). Resim metadata buraya yazılır:
--       { "media_type":"image", "storage_path":"...", "width":..,
--         "height":.., "size_bytes":.. }
--     `message_type` 'text' KALIR — hardened messages_insert_sender policy'sine
--     ve content 1..4000 CHECK'ine DOKUNULMAZ (content = caption veya kısa
--     placeholder). Resim, attachments.media_type='image' ile tespit edilir.
--   * GROUP: `public.group_messages` tablosuna `attachments jsonb` kolonu
--     eklenir (mevcut member-gated insert RLS aynı kalır).
--   * STORAGE: yeni PRIVATE bucket `chat-media` (public=false). Erişim
--     signed URL ile; SELECT/INSERT membership/participant RLS'iyle gated.
--       Path: conversations/{conversationId}/{ownerId}/{uuid}.{ext}
--              groups/{groupId}/{ownerId}/{uuid}.{ext}
--       foldername(name): [1]=scope, [2]=scopeId, [3]=ownerId
--
-- APPLY YOK: bu dosya repo'ya eklenir; prod'a deploy/review sürecinde
-- (supabase db push / MCP onayıyla) uygulanır. Flutter kodu bu şemayı
-- bekler; uygulanmadan medya akışı çalışmaz (text sohbet etkilenmez).
--
-- Geri dönüş:
--   alter table public.group_messages drop column if exists attachments;
--   drop policy if exists chat_media_storage_select on storage.objects;
--   drop policy if exists chat_media_storage_insert on storage.objects;
--   drop policy if exists chat_media_storage_update_owner on storage.objects;
--   drop policy if exists chat_media_storage_delete_owner on storage.objects;
--   delete from storage.buckets where id = 'chat-media';
-- =============================================================================

-- ─── 1. Group messages: attachments jsonb ───────────────────────────────────
alter table public.group_messages
  add column if not exists attachments jsonb;

comment on column public.group_messages.attachments is
  'Chat Media V1 — opsiyonel resim eki metadata: '
  '{media_type:image, storage_path, width, height, size_bytes}. '
  'Bucket chat-media (private); UI signed URL ile render eder.';

comment on column public.messages.attachments is
  'Chat Media V1 — opsiyonel resim eki metadata (jsonb). message_type ''text'' '
  'kalır; resim attachments.media_type=''image'' ile tespit edilir. '
  'Bucket chat-media (private); UI signed URL ile render eder.';

-- ─── 2. Private bucket: chat-media ───────────────────────────────────────────
insert into storage.buckets (id, name, public)
  values ('chat-media', 'chat-media', false)
on conflict (id) do nothing;

-- ─── 3. storage.objects RLS — membership/participant gated ───────────────────
-- SELECT: yalnız ilgili conversation participant'ı / grup üyesi görebilir.
-- (createSignedUrl SELECT yetkisi ister → signed URL yalnız yetkiliye üretilir.)
-- NOT: grup SELECT mantığı `group_messages_select_visible` ile birebir
-- hizalı — medya, mesaj görünürlüğüyle aynı kuralı izler: public grup →
-- authenticated görür; private grup → owner/üye. Böylece public grupta
-- üye-olmayan da resmi görebilir (text ile tutarlı). Generic conversation
-- için `is_in_conversation` (yalnız participant).
drop policy if exists chat_media_storage_select on storage.objects;
create policy chat_media_storage_select
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      (
        (storage.foldername(name))[1] = 'conversations'
        and public.is_in_conversation(((storage.foldername(name))[2])::uuid)
      )
      or (
        (storage.foldername(name))[1] = 'groups'
        and exists (
          select 1 from public.social_groups g
          where g.id = ((storage.foldername(name))[2])::uuid
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

-- INSERT: yükleyen owner segmenti auth.uid() + ilgili conversation/grup üyesi.
drop policy if exists chat_media_storage_insert on storage.objects;
create policy chat_media_storage_insert
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[3] = auth.uid()::text
    and (
      (
        (storage.foldername(name))[1] = 'conversations'
        and public.is_in_conversation(((storage.foldername(name))[2])::uuid)
      )
      or (
        (storage.foldername(name))[1] = 'groups'
        and exists (
          select 1 from public.group_members gm
          where gm.group_id = ((storage.foldername(name))[2])::uuid
            and gm.owner_id = auth.uid()
        )
      )
    )
  );

-- UPDATE: yalnız owner kendi objesi.
drop policy if exists chat_media_storage_update_owner on storage.objects;
create policy chat_media_storage_update_owner
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[3] = auth.uid()::text
  )
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[3] = auth.uid()::text
  );

-- DELETE: yalnız owner kendi objesi.
drop policy if exists chat_media_storage_delete_owner on storage.objects;
create policy chat_media_storage_delete_owner
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[3] = auth.uid()::text
  );
