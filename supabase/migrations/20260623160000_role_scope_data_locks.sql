-- Rol/Scope Veri Kilidi (role_data_lock) — ADDITIVE. Veri silme/drop YOK.
--
-- Ürün kararı:
--  1) Kendi işletme/Bayi Defteri verisi olan kullanıcı şoför davetini KABUL
--     EDEMEZ (başka işletmenin defteriyle karışmasın).
--  2) Rol-kilitli verisi olan kullanıcı profil account_type'ını DEĞİŞTİREMEZ.
--  3) Asıl blok DB katmanında (RPC + trigger); UI yalnız açıklama gösterir.
--  4) Veri silinmeden / aktarım özelliği gelmeden rol/scope değişimi yok.
--
-- "Rol-kilitli veri" = kullanıcının sahip (owner_id) olduğu herhangi bir:
--   dealers / dealer_transactions / dealer_deliveries / dealer_prices /
--   dealer_notes / debt_expense_entries kaydı.

-- 1) Yardımcı: kullanıcının rol-kilitli verisi var mı? (RLS-bağımsız okuma için
--    SECURITY DEFINER; yalnız definer fonksiyon/trigger çağırır → EXECUTE revoke.)
create or replace function public.has_role_locked_data(p_uid uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select
    exists (select 1 from public.dealers where owner_id = p_uid)
    or exists (select 1 from public.dealer_transactions where owner_id = p_uid)
    or exists (select 1 from public.dealer_deliveries where owner_id = p_uid)
    or exists (select 1 from public.dealer_prices where owner_id = p_uid)
    or exists (select 1 from public.dealer_notes where owner_id = p_uid)
    or exists (select 1 from public.debt_expense_entries where owner_id = p_uid);
$$;
revoke execute on function public.has_role_locked_data(uuid)
  from public, anon, authenticated;

-- 2) respond_driver_invite: p_accept=true iken davet edilen kullanıcının
--    rol-kilitli verisi varsa kabulü ENGELLE. (Mevcut imza/akış korunur;
--    yalnız kabul dalına lock kontrolü eklendi. Grant'lar replace ile korunur.)
create or replace function public.respond_driver_invite(p_invite_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid; v_name text; v_phone text; v_note text; v_perm text;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select owner_id, driver_name, driver_phone, note, permission_level
    into v_owner, v_name, v_phone, v_note, v_perm
  from public.dealer_driver_invites
  where id = p_invite_id and invited_user_id = v_uid and status = 'pending';
  if v_owner is null then raise exception 'invite not found'; end if;
  if p_accept then
    -- ROL/SCOPE VERİ KİLİDİ: kendi defter/işletme kaydı olan kullanıcı şoför
    -- olamaz. Önce kayıtlar temizlenmeli (veya gelecekte aktarım özelliğiyle
    -- taşınmalı). Veri silinmez; yalnız kabul reddedilir.
    if public.has_role_locked_data(v_uid) then
      raise exception 'role_data_lock: personal records must be cleared before accepting driver invite';
    end if;
    insert into public.dealer_drivers (owner_id, driver_user_id, name, phone, note, permission_level)
    values (v_owner, v_uid, v_name, v_phone, v_note, coalesce(v_perm, 'half'))
    on conflict (owner_id, driver_user_id) do nothing;
    update public.dealer_driver_invites set status = 'accepted', responded_at = now() where id = p_invite_id;
  else
    update public.dealer_driver_invites set status = 'rejected', responded_at = now() where id = p_invite_id;
  end if;
end;
$$;

-- 3) profiles.account_type değişim guard'ı — rol-kilitli verisi olan kullanıcı
--    tip değiştiremez. BEFORE UPDATE trigger (account_type gerçekten değişiyorsa).
--    SECURITY DEFINER: has_role_locked_data (EXECUTE revoke'lu) çağrılabilsin.
create or replace function public.guard_account_type_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.account_type is distinct from old.account_type then
    if public.has_role_locked_data(new.id) then
      raise exception 'role_data_lock: existing business records block account type change';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_account_type_change()
  from public, anon, authenticated;

drop trigger if exists trg_guard_account_type_change on public.profiles;
create trigger trg_guard_account_type_change
  before update on public.profiles
  for each row execute function public.guard_account_type_change();
