-- Bayi Yönetimi — Şoförler · Sprint 6: GÜVENLİ DAVET/ONAY akışı (additive).
--
-- Patron şoförü doğrudan sessizce bağlamaz; pending davet oluşturur. Şoför
-- kendi hesabından kabul edince dealer_drivers (aktif bağlantı) oluşur.
--
-- Tasarım — TAM GERİYE UYUMLU:
--   * dealer_drivers kaydı = AKTİF bağlantı; yalnız kabul sonrası oluşur.
--     Mevcut dealer_drivers kayıtları aktif kabul edilir (değişmez).
--   * Mevcut read-only/yazma RLS + driver_add_transaction RPC DEĞİŞMEZ
--     (pending davete dealer_drivers satırı YOK → hiçbir yetki yok).
--   * Pending durum YALNIZ dealer_driver_invites'ta; owner-only RLS gevşetilmez.
--   * Tüm yazma SECURITY DEFINER RPC ile; davet tablosuna direct INSERT/UPDATE yok.
--   * Kimlik sızıntısı yok: davet hedefi tam profile id; geniş arama yok,
--     nötr "davet oluşturuldu" yanıtı.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

create table if not exists public.dealer_driver_invites (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  invited_user_id uuid not null references public.profiles(id) on delete restrict,
  driver_name text not null,
  driver_phone text,
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);
create index if not exists idx_dealer_driver_invites_owner
  on public.dealer_driver_invites(owner_id);
create index if not exists idx_dealer_driver_invites_invited
  on public.dealer_driver_invites(invited_user_id);

alter table public.dealer_driver_invites enable row level security;

-- SELECT: yalnız davetin tarafları (patron veya davet edilen şoför).
-- INSERT/UPDATE/DELETE policy YOK → yazma yalnız RPC.
drop policy if exists dealer_driver_invites_select on public.dealer_driver_invites;
create policy dealer_driver_invites_select on public.dealer_driver_invites
  for select to authenticated
  using (owner_id = auth.uid() or invited_user_id = auth.uid());

-- ── Davet oluştur (patron) ──
create or replace function public.create_driver_invite(
  p_invited_user_id uuid,
  p_driver_name text,
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
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_driver_name), '') = '' then raise exception 'name required'; end if;
  if p_invited_user_id = v_uid then raise exception 'cannot invite self'; end if;
  -- Zaten aktif şoför mü?
  if exists (
    select 1 from public.dealer_drivers
    where owner_id = v_uid and driver_user_id = p_invited_user_id
  ) then
    raise exception 'already a driver';
  end if;
  -- Zaten bekleyen davet var mı?
  if exists (
    select 1 from public.dealer_driver_invites
    where owner_id = v_uid and invited_user_id = p_invited_user_id and status = 'pending'
  ) then
    raise exception 'invite already pending';
  end if;
  insert into public.dealer_driver_invites
    (owner_id, invited_user_id, driver_name, driver_phone, note)
  values
    (v_uid, p_invited_user_id, trim(p_driver_name), nullif(p_driver_phone, ''),
     nullif(p_note, ''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.create_driver_invite(uuid, text, text, text)
  from public, anon;
grant execute on function public.create_driver_invite(uuid, text, text, text)
  to authenticated;

-- ── Davet yanıtla (şoför: kabul/ret) ──
create or replace function public.respond_driver_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_name text;
  v_phone text;
  v_note text;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select owner_id, driver_name, driver_phone, note
    into v_owner, v_name, v_phone, v_note
  from public.dealer_driver_invites
  where id = p_invite_id and invited_user_id = v_uid and status = 'pending';
  if v_owner is null then raise exception 'invite not found'; end if;

  if p_accept then
    -- Aktif bağlantı oluştur (duplicate'te yok say).
    insert into public.dealer_drivers
      (owner_id, driver_user_id, name, phone, note)
    values (v_owner, v_uid, v_name, v_phone, v_note)
    on conflict (owner_id, driver_user_id) do nothing;
    update public.dealer_driver_invites
      set status = 'accepted', responded_at = now()
    where id = p_invite_id;
  else
    update public.dealer_driver_invites
      set status = 'rejected', responded_at = now()
    where id = p_invite_id;
  end if;
end;
$$;
revoke execute on function public.respond_driver_invite(uuid, boolean)
  from public, anon;
grant execute on function public.respond_driver_invite(uuid, boolean)
  to authenticated;

-- ── Davet iptal (patron) ──
create or replace function public.cancel_driver_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'auth required'; end if;
  update public.dealer_driver_invites
    set status = 'cancelled', responded_at = now()
  where id = p_invite_id and owner_id = v_uid and status = 'pending';
end;
$$;
revoke execute on function public.cancel_driver_invite(uuid) from public, anon;
grant execute on function public.cancel_driver_invite(uuid) to authenticated;
