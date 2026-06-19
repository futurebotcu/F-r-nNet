-- Bayi Yönetimi — Şoförler · Şoför daveti FN-ID ile (additive, davranış korunur).
--
-- Patron/toptancı, şoförün Ayarlar'da gördüğü FırınNet ID'sini (profiles.firinnet_id,
-- format FN-YYYY-NNNNNN) girer. Çözümleme client'ta DEĞİL, bu SECURITY DEFINER
-- RPC içinde yapılır (profiles SELECT own-only; geniş arama/lookup yok).
--
-- Değişen TEK şey: create_driver_invite imzası (uuid → FN-ID text). dealer_driver_
-- invites tablosu/RLS, respond_/cancel_driver_invite, driver_add_transaction,
-- owner-only politikalar DEĞİŞMEZ. Kabul akışı aynen respond_driver_invite ile.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- Eski uuid imzası kaldırılır (tek caller = Supabase repo; FN-ID'ye geçiyor).
drop function if exists public.create_driver_invite(uuid, text, text, text);

create or replace function public.create_driver_invite(
  p_target_firinnet_id text,
  p_driver_name text default null,
  p_driver_phone text default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_fn text := upper(trim(coalesce(p_target_firinnet_id, '')));
  v_target uuid;
  v_pending_count int;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if coalesce(trim(p_driver_name), '') = '' then
    raise exception 'name required';
  end if;
  -- FN-ID boş/biçimsizse → generic (enumeration/sızıntı yok).
  if v_fn = '' then
    raise exception 'invite failed';
  end if;

  -- Tam eşleşme (firinnet_id UNIQUE → 0/1). Bulunamazsa generic hata.
  select id into v_target from public.profiles where firinnet_id = v_fn;
  if v_target is null then
    raise exception 'invite failed';
  end if;

  if v_target = v_uid then
    raise exception 'cannot invite self';
  end if;
  if exists (
    select 1 from public.dealer_drivers
    where owner_id = v_uid and driver_user_id = v_target
  ) then
    raise exception 'already a driver';
  end if;
  if exists (
    select 1 from public.dealer_driver_invites
    where owner_id = v_uid and invited_user_id = v_target and status = 'pending'
  ) then
    raise exception 'invite already pending';
  end if;

  -- Basit spam/abuse koruması: owner başına ≥20 bekleyen davet → engelle.
  select count(*) into v_pending_count
  from public.dealer_driver_invites
  where owner_id = v_uid and status = 'pending';
  if v_pending_count >= 20 then
    raise exception 'too many pending invites';
  end if;

  insert into public.dealer_driver_invites
    (owner_id, invited_user_id, driver_name, driver_phone, note)
  values
    (v_uid, v_target, trim(p_driver_name), nullif(p_driver_phone, ''),
     nullif(p_note, ''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.create_driver_invite(text, text, text, text)
  from public, anon;
grant execute on function public.create_driver_invite(text, text, text, text)
  to authenticated;
