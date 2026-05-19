-- =============================================================================
-- FırınNet Groups V1 Final Closure — Public Profile Snapshot RPC
-- =============================================================================
-- Sorun (P1 UX bug, audit 2026-05-19):
--   `profiles_select_own` RLS policy: id = auth.uid() (kendi satırın).
--   Bu policy doğru bir privacy korumasıdır (email/avatar_url/account_type
--   sızmaması için). Ancak grup ekranındaki:
--     * Üyeler bottom sheet (listMembers)
--     * Katılım istekleri sheet (listPendingJoinRequests)
--   client tarafında `profiles.in_filter(ids)` REST select ile diğer üyelerin
--   `display_name`/`profession_badge`/`city` snapshot'ını çekmeye çalışıyor.
--   RLS hepsini filtreliyor → her satır için fallback "FırınNet Kullanıcısı"
--   görünüyor.
--
--   Mesajlar etkilenmez çünkü `group_messages.author_name` BEFORE INSERT
--   `snapshot_group_message_author` trigger'ı (SECURITY DEFINER) tarafından
--   yazılıyor; profil snapshot'ı satır içine alınıyor.
--
-- Çözüm (read-only SECURITY DEFINER RPC):
--   `public_profile_snapshot(p_user_ids uuid[])` fonksiyonu, verilen kullanıcı
--   id listesi için YALNIZ üç güvenli kolonu döner:
--     - id
--     - display_name (boş/null ise NULL — UI tarafı 'FırınNet Kullanıcısı'
--       fallback'ini uygular)
--     - profession_badge
--     - city
--
--   Bu kolonlar zaten group_messages/feed_posts içinde snapshot olarak
--   görünür durumdadır; ayrı bir gizlilik tabakası yoktur. Diğer hassas
--   profil alanları (email, account_type, avatar_url vb.) RPC tarafından
--   ASLA döndürülmez.
--
-- Tasarım kararları:
--   * SECURITY DEFINER + `set search_path = public` + revoke from public/anon
--     + grant to authenticated (mevcut RPC pattern'ı).
--   * STABLE (read-only).
--   * Caller listMembers/listPendingJoinRequests sonucundan elde ettiği
--     user_id listesini parametre olarak verir; bu listenin görünürlüğü
--     zaten ilgili tablonun RLS'iyle filtrelenmiştir. RPC ek gating yapmaz
--     (caller zaten yetkilendirilmiş id'leri biliyor).
--
-- Rollback:
--   drop function if exists public.public_profile_snapshot(uuid[]);
-- =============================================================================

create or replace function public.public_profile_snapshot(
  p_user_ids uuid[]
) returns table (
  id                uuid,
  display_name      text,
  profession_badge  text,
  city              text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    nullif(trim(coalesce(p.display_name, '')), '')      as display_name,
    nullif(trim(coalesce(p.profession_badge, '')), '')  as profession_badge,
    nullif(trim(coalesce(p.city, '')), '')              as city
  from public.profiles p
  where p.id = any(p_user_ids);
$$;

revoke execute on function public.public_profile_snapshot(uuid[]) from public;
revoke execute on function public.public_profile_snapshot(uuid[]) from anon;
grant  execute on function public.public_profile_snapshot(uuid[]) to authenticated;

comment on function public.public_profile_snapshot(uuid[]) is
  'V1 Closure — Read-only snapshot of public profile fields (display_name, '
  'profession_badge, city) for a list of user ids. Used by listMembers and '
  'listPendingJoinRequests UI which need names for users beyond the caller '
  'and would otherwise hit profiles owner-only RLS. SECURITY DEFINER; only '
  'three columns exposed; hassas alanlar (email, account_type) ASLA dönmez.';
