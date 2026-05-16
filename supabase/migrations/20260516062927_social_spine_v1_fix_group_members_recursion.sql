-- Migration: social_spine_v1_fix_group_members_recursion
-- Version: 20260516062927
-- Applied to remote: 2026-05-16 via MCP apply_migration.
--
-- Sorun (P0 RLS):
--   social_spine_v1 içindeki group_members_select_visible policy'si kendi
--   tablosuna recursive subquery yapıyordu:
--     using (
--       owner_id = auth.uid()
--       or exists (
--         select 1 from public.social_groups g
--         where g.id = group_id and g.is_deleted = false and (
--           g.is_private = false
--           or g.owner_id = auth.uid()
--           or exists (select 1 from public.group_members gm2
--                      where gm2.group_id = g.id and gm2.owner_id = auth.uid())
--         )
--       )
--     );
--
--   Aynı zamanda social_groups_select_visible group_members'a, group_messages_select_visible
--   de group_members + social_groups'a EXISTS yapıyordu. Karşılıklı policy çağrı zinciri
--   Postgres'te:
--     ERROR: infinite recursion detected in policy for relation "group_members"
--   hatasını tetikledi. PostgREST `Prefer: return=representation` ile social_groups
--   INSERT sırasında RETURNING SELECT policy'sini çalıştırınca 500 görüldü.
--
-- Düzeltme:
--   1. SECURITY DEFINER helper `is_group_member(group_id, user_id)` — RLS bypass
--      ederek group_members'a bakar (execute revoke from public/anon, grant to
--      authenticated). Stable + search_path=public.
--   2. group_members_select_visible policy: gm2 recursive subquery kaldırıldı;
--      yerine is_group_member kullanıldı.
--   3. social_groups_select_visible ve group_messages_select_visible policy'leri:
--      group_members EXISTS subquery yerine is_group_member çağrısı (aynı mantık,
--      RLS recursion zinciri kırıldı).
--   4. INSERT/UPDATE/DELETE policy'leri DEĞİŞMEDİ — yalnız SELECT recursion'a
--      düşüyordu.
--
-- Davranış aynı: kullanıcı kendi satırı, üye olduğu/sahibi olduğu/public gruba
-- ait kayıtları görür. Cross-group erişim aynen kapalı; group_messages_insert_member
-- P0 fix'i (20260516043809) aynen çalışıyor.

create or replace function public.is_group_member(p_group uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.group_members
    where group_id = p_group and owner_id = p_user
  );
$$;
revoke execute on function public.is_group_member(uuid, uuid) from public;
revoke execute on function public.is_group_member(uuid, uuid) from anon;
grant   execute on function public.is_group_member(uuid, uuid) to authenticated;

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
          or public.is_group_member(g.id, auth.uid())
        )
    )
  );

drop policy if exists social_groups_select_visible on public.social_groups;
create policy social_groups_select_visible on public.social_groups
  for select to authenticated
  using (
    is_deleted = false
    and (
      is_private = false
      or owner_id = auth.uid()
      or public.is_group_member(id, auth.uid())
    )
  );

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
          or public.is_group_member(g.id, auth.uid())
        )
    )
  );
