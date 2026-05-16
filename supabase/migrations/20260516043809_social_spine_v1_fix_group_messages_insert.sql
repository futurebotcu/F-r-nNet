-- Migration: social_spine_v1_fix_group_messages_insert
-- Version: 20260516043809
-- Applied to remote: 2026-05-16 via MCP apply_migration.
-- Lokal dosya adı remote version ile eşitlendi (önceki taslak version 20260516120000 idi).
--
-- Sorun:
--   social_spine_v1 (20260515120000) içindeki group_messages_insert_member
--   policy'sinde alias'sız `group_id` identifier'ı kullanılmıştı:
--     exists (select 1 from public.group_members gm
--             where gm.group_id = group_id and gm.owner_id = auth.uid())
--   Postgres scope resolution: hem outer (group_messages.group_id) hem inner
--   (gm.group_id) tabloda aynı isimde sütun olduğu için `group_id` identifier'ı
--   inner alias'a (gm.group_id) bağlandı. Sonuç: `gm.group_id = gm.group_id`
--   ifadesi daima TRUE. Bu, herhangi bir grupta üye olan authenticated
--   kullanıcının üye olmadığı başka grupların group_messages tablosuna mesaj
--   eklemesine izin veriyordu. P0 RLS bypass.
--
-- Düzeltme:
--   `gm.group_id = group_messages.group_id` ile outer tabloya açık referans.
--   Policy DROP+CREATE; tablo/şema değişikliği yok; veri kaybı yok.
--
-- Geri dönüş:
--   drop policy if exists group_messages_insert_member on public.group_messages;
--   (Eski hatalı policy'i geri yazmak ASLA önerilmez.)

drop policy if exists group_messages_insert_member on public.group_messages;
create policy group_messages_insert_member on public.group_messages
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = group_messages.group_id
        and gm.owner_id = auth.uid()
    )
  );
