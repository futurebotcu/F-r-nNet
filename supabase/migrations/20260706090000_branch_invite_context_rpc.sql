-- =============================================================================
-- FırınNet Şube Yönetimi V1 Polish — Branch Invite Context RPC
-- =============================================================================
-- Sorun (V1 audit, 2026-07-05):
--   Bekleyen şube davetinde davetli, `branches_select` RLS'i gereği (owner
--   veya AKTİF üye) şube satırını göremez → davet kartında şube adı boş
--   kalır ve "Şube daveti" fallback'i görünür. Davetli neyi kabul ettiğini
--   bilemiyor.
--
-- Çözüm (dar, read-only SECURITY DEFINER RPC — policy genişletme YOK):
--   `my_branch_invite_contexts()` parametresiz fonksiyonu, YALNIZ çağıran
--   kullanıcının (auth.uid()) kendi PENDING davetleri için davet kartının
--   ihtiyaç duyduğu güvenli alanları döner:
--     - invite_id / branch_id
--     - branch_name        (yalnız ad; adres/telefon/durum DÖNMEZ)
--     - owner_display_name (public_profile_snapshot ile aynı gizlilik sınıfı)
--     - role / status / permissions / created_at (davetlinin zaten kendi
--       satırında RLS ile görebildiği alanlar)
--
-- Güvenlik değerlendirmesi:
--   * Parametre YOK → başka davet/şube id'si probe edilemez (enumeration
--     yüzeyi sıfır). Filtre sunucuda sabit: invited_user_id = auth.uid()
--     and status = 'pending'.
--   * branches tablosuna yeni SELECT policy AÇILMAZ; RLS fail-closed kalır.
--     Kabul öncesi tam şube verisi (adres, telefon, durum, diğer üyeler,
--     süreçler) kapalı kalmaya devam eder — yalnız AD sızar ki bu, davetin
--     kendisinin taşıdığı asgari bağlamdır.
--   * FN-ID hiçbir yerde geçmez (davet satırında zaten saklanmıyor).
--   * Mevcut RPC pattern'ı: SECURITY DEFINER + set search_path = public +
--     revoke public/anon + grant authenticated + STABLE (read-only).
--
-- Rollback:
--   drop function if exists public.my_branch_invite_contexts();
-- =============================================================================

create or replace function public.my_branch_invite_contexts()
returns table (
  invite_id   uuid,
  branch_id   uuid,
  branch_name text,
  owner_name  text,
  role        text,
  status      text,
  permissions jsonb,
  created_at  timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    i.id,
    i.branch_id,
    b.name,
    nullif(trim(coalesce(p.display_name, '')), ''),
    i.role,
    i.status,
    i.permissions,
    i.created_at
  from public.branch_invites i
  join public.branches b on b.id = i.branch_id
  left join public.profiles p on p.id = i.owner_id
  where i.invited_user_id = auth.uid()
    and i.status = 'pending'
  order by i.created_at desc;
$$;

revoke execute on function public.my_branch_invite_contexts() from public;
revoke execute on function public.my_branch_invite_contexts() from anon;
grant  execute on function public.my_branch_invite_contexts() to authenticated;

comment on function public.my_branch_invite_contexts() is
  'Şube Yönetimi V1 polish — davetlinin KENDİ pending davetleri için davet '
  'kartı bağlamı (şube adı + davet eden adı + rol/izin). Parametresiz; '
  'yalnız auth.uid() filtreli → enumeration yüzeyi yok. branches RLS''i '
  'genişletilmedi; kabul öncesi tam şube verisi kapalı kalır.';
