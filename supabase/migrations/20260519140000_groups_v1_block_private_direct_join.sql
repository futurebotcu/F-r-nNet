-- =============================================================================
-- FırınNet Groups V1 — Block Direct Join Into Private Groups
-- =============================================================================
-- P0 (audit 2026-05-19 post-deployment):
--   `group_members_insert_self` policy was:
--     WITH CHECK (
--       owner_id = auth.uid()
--       AND EXISTS (
--         SELECT 1 FROM social_groups g
--         WHERE g.id = group_members.group_id AND g.is_deleted = false
--       )
--     )
--   This allowed any authenticated user to INSERT into group_members for ANY
--   non-deleted group — INCLUDING private (is_private = true) groups — without
--   going through `request_group_join` + `decide_group_join_request`. Result:
--   private groups were effectively join-on-tap from the client list card.
--
--   UI ekran kompozisyonu non-member private için detay ekranında `_PrivateGated`
--   + `_RequestButton` gösteriyordu (doğru), ANCAK liste kartındaki
--   `_PrimaryCta` "Katıl" → `joinGroup` → REST INSERT yolu private kontrolü
--   yapmadığı için bu gating'i bypass ediyordu.
--
--   Yaşanan örnek: "Konyali" (is_private=true) grubuna `group_join_requests`
--   satırı oluşmadan direct `group_members` INSERT ile üye olundu; üye olunca
--   chat erişimi açıldı (mesaj okuma için RLS `is_group_member` yeterli).
--
-- Düzeltme:
--   Policy `WITH CHECK` koşuluna `(g.is_private = false OR g.owner_id = auth.uid())`
--   eklendi:
--     * Public grup → direct join devam eder (mevcut davranış).
--     * Private grup → INSERT reddedilir. Üyelik yalnızca
--       `decide_group_join_request` SECURITY DEFINER RPC üzerinden (owner
--       approve) eklenebilir; RPC SECURITY DEFINER olduğu için bu policy'yi
--       bypass eder.
--     * `g.owner_id = auth.uid()` — defansif: owner createGroup atomik
--       trade-off'unda kendisini sonradan üye olarak ekleyebilmeli (current
--       repo davranışı; trigger zaten owner için group_members satırını
--       ekliyor ama edge-case için bırakılır).
--
-- Mevcut satırlara etki:
--   Policy yalnız YENİ INSERT'leri kapsar. Audit anında zaten "Konyali"
--   grubunun üyesi olan kullanıcı (audit kanıtı: Fatih Kartal in
--   51d61702-...) satırı silinmez; manuel temizlik isteğe bağlı bir
--   sonraki adım. Bu migration yetki aşımının tekrarlanmasını engeller.
--
-- Geri dönüş:
--   drop policy if exists group_members_insert_self on public.group_members;
--   create policy group_members_insert_self on public.group_members
--     for insert to authenticated
--     with check (
--       owner_id = auth.uid()
--       and exists (
--         select 1 from public.social_groups g
--         where g.id = group_members.group_id and g.is_deleted = false
--       )
--     );
-- =============================================================================

drop policy if exists group_members_insert_self on public.group_members;

create policy group_members_insert_self on public.group_members
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.social_groups g
      where g.id = group_members.group_id
        and g.is_deleted = false
        and (
          g.is_private = false
          or g.owner_id = auth.uid()
        )
    )
  );

comment on policy group_members_insert_self on public.group_members is
  'V1 P0 — Direct INSERT yalnız public gruba veya owner kendisine; private '
  'grubu için yol decide_group_join_request RPC (SECURITY DEFINER bypass).';
