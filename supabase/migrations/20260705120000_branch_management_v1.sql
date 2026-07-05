-- Şube Yönetimi Mini App — V1 foundation (ADDITIVE; mevcut tablolara dokunmaz).
--
-- Ürün modeli:
--   * Ticari (patron) şube açar, FırınNet ID ile personel davet eder,
--     şube süreçlerini takip eder.
--   * Bireysel kullanıcı hesap türü DEĞİŞMEDEN yalnız "şube personeli
--     üyeliği" kazanır (şoför sistemi emsali); aktif üyeliği yoksa hiçbir
--     şube verisi göremez.
--
-- Güvenlik tasarımı (fail-closed):
--   * branch_invites / branch_memberships / branch_processes /
--     branch_activity_log tablolarına CLIENT YAZAMAZ (INSERT/UPDATE policy
--     yok) — tüm yazma SECURITY DEFINER RPC'lerle, izin denetimi RPC içinde
--     (server-side; client-only permission kontrolü YOK).
--   * FN-ID çözümleme yalnız RPC içinde (create_driver_invite emsali,
--     FN-AUDIT-012): nötr hatalar, enumeration yok, FN-ID SAKLANMAZ.
--   * Üye SELECT erişimi is_active_branch_member() helper'ı ile; üyelik
--     suspended/removed olduğu an erişim kesilir.
--   * Şoför sistemi (dealer_driver_*) ile hiçbir tablo/RPC paylaşılmaz.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. TABLOLAR
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  address text,
  phone text,
  -- 'dikkat' durumu SAKLANMAZ; açık attention süreçten UI'da türetilir.
  status text not null default 'active'
    check (status in ('active', 'passive')),
  is_main_branch boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.branches is
  'Şube Yönetimi V1 — ticari işletmenin şubeleri. RLS: owner tam; aktif üye SELECT.';
create index if not exists idx_branches_owner on public.branches(owner_id);

create table if not exists public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  -- owner_id şubeden kopyalanır (RPC set eder) → ucuz owner-RLS + rapor.
  owner_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null
    check (role in ('branch_manager', 'counter', 'production', 'cashier',
                    'shipping', 'accounting_assistant')),
  -- İzinli süreç tipleri: jsonb text array (örn. ["production_note", ...]).
  -- branch_manager rolü tip listesinden bağımsız TÜM tiplere yetkilidir.
  permissions jsonb not null default '[]'::jsonb
    check (jsonb_typeof(permissions) = 'array'),
  status text not null default 'active'
    check (status in ('active', 'suspended', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, user_id)
);
comment on table public.branch_memberships is
  'Şube personel üyeliği. Yazma yalnız RPC (respond_branch_invite / set_branch_membership_status).';
create index if not exists idx_branch_memberships_user
  on public.branch_memberships(user_id) where status = 'active';
create index if not exists idx_branch_memberships_branch
  on public.branch_memberships(branch_id);

create table if not exists public.branch_invites (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  -- Audit: daveti fiilen oluşturan kullanıcı (V1'de owner; ileride
  -- branch_manager davet yetkisi alırsa kim davet etti izlenir).
  invited_by uuid not null references public.profiles(id) on delete cascade,
  -- FN-ID SAKLANMAZ (ID politikası); RPC çözer, yalnız uuid tutulur.
  -- cascade: D-1 hesap silme zinciri davet satırına takılmasın.
  invited_user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null
    check (role in ('branch_manager', 'counter', 'production', 'cashier',
                    'shipping', 'accounting_assistant')),
  permissions jsonb not null default '[]'::jsonb
    check (jsonb_typeof(permissions) = 'array'),
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'revoked')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);
comment on table public.branch_invites is
  'Şube personel davetleri. Yazma yalnız RPC; SELECT yalnız taraflar.';
create index if not exists idx_branch_invites_owner
  on public.branch_invites(owner_id) where status = 'pending';
create index if not exists idx_branch_invites_invited
  on public.branch_invites(invited_user_id) where status = 'pending';
-- Saatlik rate-limit sorgusu için (invited_by + created_at).
create index if not exists idx_branch_invites_inviter_created
  on public.branch_invites(invited_by, created_at desc);

create table if not exists public.branch_processes (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  assigned_to uuid references public.profiles(id) on delete set null,
  type text not null
    check (type in ('opening_check', 'production_note', 'shipment_prep',
                    'dealer_collection', 'account_note', 'general_note')),
  title text not null check (char_length(trim(title)) between 1 and 120),
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'completed', 'attention')),
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high')),
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.branch_processes is
  'Şube süreç/görevleri. Yazma yalnız RPC (create_/update_branch_process) — izin denetimi server-side.';
create index if not exists idx_branch_processes_branch_status
  on public.branch_processes(branch_id, status);
create index if not exists idx_branch_processes_owner
  on public.branch_processes(owner_id);

create table if not exists public.branch_activity_log (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  process_id uuid references public.branch_processes(id) on delete set null,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null
    check (event_type in ('process_created', 'process_updated',
                          'status_changed', 'membership_changed',
                          'invite_created', 'invite_responded')),
  note text,
  created_at timestamptz not null default now()
);
comment on table public.branch_activity_log is
  'Şube hareket günlüğü (append-only). Yazma yalnız RPC içi; UPDATE/DELETE yok.';
create index if not exists idx_branch_activity_branch
  on public.branch_activity_log(branch_id, created_at desc);

-- updated_at dokunuşları (core schema''daki mevcut helper yeniden kullanılır).
drop trigger if exists trg_branches_set_updated_at on public.branches;
create trigger trg_branches_set_updated_at
before update on public.branches
for each row execute function public.set_updated_at();

drop trigger if exists trg_branch_memberships_set_updated_at
  on public.branch_memberships;
create trigger trg_branch_memberships_set_updated_at
before update on public.branch_memberships
for each row execute function public.set_updated_at();

drop trigger if exists trg_branch_processes_set_updated_at
  on public.branch_processes;
create trigger trg_branch_processes_set_updated_at
before update on public.branch_processes
for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────────────────
-- 2. HELPER FONKSİYONLAR (SECURITY DEFINER — RLS recursion önler)
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.is_branch_owner(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.branches
    where id = p_branch_id and owner_id = auth.uid()
  );
$$;
revoke execute on function public.is_branch_owner(uuid) from public, anon;
grant execute on function public.is_branch_owner(uuid) to authenticated;

create or replace function public.is_active_branch_member(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.branch_memberships
    where branch_id = p_branch_id
      and user_id = auth.uid()
      and status = 'active'
  );
$$;
revoke execute on function public.is_active_branch_member(uuid)
  from public, anon;
grant execute on function public.is_active_branch_member(uuid)
  to authenticated;

-- Süreç tipi izni: owner → her zaman; aktif üye → branch_manager rolü TÜM
-- tipler, diğer roller yalnız permissions listesindeki tipler.
create or replace function public.has_branch_process_permission(
  p_branch_id uuid,
  p_type text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_branch_owner(p_branch_id)
      or exists (
        select 1 from public.branch_memberships m
        where m.branch_id = p_branch_id
          and m.user_id = auth.uid()
          and m.status = 'active'
          and (m.role = 'branch_manager'
               or m.permissions ? p_type)
      );
$$;
revoke execute on function public.has_branch_process_permission(uuid, text)
  from public, anon;
grant execute on function public.has_branch_process_permission(uuid, text)
  to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 3. RLS
-- ────────────────────────────────────────────────────────────────────────

alter table public.branches enable row level security;
alter table public.branch_memberships enable row level security;
alter table public.branch_invites enable row level security;
alter table public.branch_processes enable row level security;
alter table public.branch_activity_log enable row level security;

-- branches: owner tam CRUD (INSERT yalnız ticari hesap); aktif üye SELECT.
drop policy if exists branches_select on public.branches;
create policy branches_select on public.branches
  for select to authenticated
  using (owner_id = auth.uid() or public.is_active_branch_member(id));

drop policy if exists branches_insert on public.branches;
create policy branches_insert on public.branches
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and account_type = 'commercial'
    )
  );

drop policy if exists branches_update on public.branches;
create policy branches_update on public.branches
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists branches_delete on public.branches;
create policy branches_delete on public.branches
  for delete to authenticated
  using (owner_id = auth.uid());

-- branch_memberships: SELECT taraflar; yazma policy YOK (yalnız RPC).
drop policy if exists branch_memberships_select on public.branch_memberships;
create policy branch_memberships_select on public.branch_memberships
  for select to authenticated
  using (owner_id = auth.uid() or user_id = auth.uid());

-- branch_invites: SELECT taraflar; yazma policy YOK (yalnız RPC).
drop policy if exists branch_invites_select on public.branch_invites;
create policy branch_invites_select on public.branch_invites
  for select to authenticated
  using (owner_id = auth.uid() or invited_user_id = auth.uid());

-- branch_processes: SELECT owner + aktif üye; DELETE yalnız owner;
-- INSERT/UPDATE policy YOK (yalnız RPC — server-side izin denetimi).
drop policy if exists branch_processes_select on public.branch_processes;
create policy branch_processes_select on public.branch_processes
  for select to authenticated
  using (owner_id = auth.uid() or public.is_active_branch_member(branch_id));

drop policy if exists branch_processes_delete on public.branch_processes;
create policy branch_processes_delete on public.branch_processes
  for delete to authenticated
  using (owner_id = auth.uid());

-- branch_activity_log: SELECT owner + aktif üye; yazma policy YOK (RPC içi).
drop policy if exists branch_activity_select on public.branch_activity_log;
create policy branch_activity_select on public.branch_activity_log
  for select to authenticated
  using (owner_id = auth.uid() or public.is_active_branch_member(branch_id));

-- Grants (RLS kapıları; anon tamamen dışarıda).
revoke all on public.branches from anon;
revoke all on public.branch_memberships from anon;
revoke all on public.branch_invites from anon;
revoke all on public.branch_processes from anon;
revoke all on public.branch_activity_log from anon;
grant select, insert, update, delete on public.branches to authenticated;
grant select on public.branch_memberships to authenticated;
grant select on public.branch_invites to authenticated;
grant select, delete on public.branch_processes to authenticated;
grant select on public.branch_activity_log to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 4. RPC'LER (SECURITY DEFINER; tüm yazma buradan)
-- ────────────────────────────────────────────────────────────────────────

-- Geçerli süreç tipleri (permissions sanitizasyonu için ortak sabit).
create or replace function public.branch_process_types()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['opening_check', 'production_note', 'shipment_prep',
               'dealer_collection', 'account_note', 'general_note'];
$$;
revoke execute on function public.branch_process_types() from public, anon;
grant execute on function public.branch_process_types() to authenticated;

-- ── Personel daveti oluştur (patron; FN-ID server-side çözülür) ──
create or replace function public.create_branch_invite(
  p_branch_id uuid,
  p_target_firinnet_id text,
  p_role text,
  p_permissions jsonb default '[]'::jsonb,
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
  v_target_type text;
  v_hourly_count int;
  v_pending_count int;
  v_perms jsonb;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if not public.is_branch_owner(p_branch_id) then
    raise exception 'not branch owner';
  end if;

  -- FN-AUDIT-012 emsali saatlik rate limit — FN-ID ÇÖZÜLMEDEN ÖNCE:
  -- limit, hedef aramasından bağımsız çalıştığı için enumeration
  -- denemelerini de frenler. Son 1 saatte (status'tan bağımsız) bu
  -- kullanıcının oluşturduğu davet sayısı ≥10 → nötr throttle hatası.
  select count(*) into v_hourly_count
  from public.branch_invites
  where invited_by = v_uid
    and created_at > now() - interval '1 hour';
  if v_hourly_count >= 10 then
    raise exception 'too many invites';
  end if;

  -- FN-ID boş/bulunamadı/uygunsuz hesap türü → HEP AYNI nötr hata
  -- (var/yok, hesap türü, format ayırt edilemez; sızıntı yok).
  if v_fn = '' then
    raise exception 'invite failed';
  end if;
  select p.id, p.account_type into v_target, v_target_type
  from public.profiles p where p.firinnet_id = v_fn;
  if v_target is null then
    raise exception 'invite failed';
  end if;
  -- Şube personeli yalnız BİREYSEL kullanıcı olabilir (bireysel hesap
  -- ticari'ye dönüşmez; yalnız üyelik kazanır). commercial/wholesaler
  -- hedefler not-found ile AYNI nötr hatayı alır.
  if v_target_type is distinct from 'individual' then
    raise exception 'invite failed';
  end if;
  if v_target = v_uid then
    raise exception 'invite failed';
  end if;
  if exists (
    select 1 from public.branch_memberships
    where branch_id = p_branch_id and user_id = v_target
      and status = 'active'
  ) then
    raise exception 'already a member';
  end if;
  if exists (
    select 1 from public.branch_invites
    where branch_id = p_branch_id and invited_user_id = v_target
      and status = 'pending'
  ) then
    raise exception 'invite already pending';
  end if;
  -- Bekleyen davet tavanı: owner başına ≥20 bekleyen → engelle.
  select count(*) into v_pending_count
  from public.branch_invites
  where owner_id = v_uid and status = 'pending';
  if v_pending_count >= 20 then
    raise exception 'too many invites';
  end if;

  -- permissions sanitizasyonu: yalnız geçerli süreç tipleri kalır.
  select coalesce(jsonb_agg(distinct t), '[]'::jsonb) into v_perms
  from jsonb_array_elements_text(
         case when jsonb_typeof(p_permissions) = 'array'
              then p_permissions else '[]'::jsonb end
       ) as e(t)
  where t = any (public.branch_process_types());

  insert into public.branch_invites
    (branch_id, owner_id, invited_by, invited_user_id, role, permissions,
     note)
  values
    (p_branch_id, v_uid, v_uid, v_target, p_role, v_perms,
     nullif(p_note, ''))
  returning id into v_id;

  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type)
  values (p_branch_id, v_uid, v_uid, 'invite_created');
  return v_id;
end;
$$;
revoke execute on function
  public.create_branch_invite(uuid, text, text, jsonb, text)
  from public, anon;
grant execute on function
  public.create_branch_invite(uuid, text, text, jsonb, text)
  to authenticated;

-- ── Daveti yanıtla (davetli: kabul/ret) ──
create or replace function public.respond_branch_invite(
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
  v_inv record;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  select * into v_inv
  from public.branch_invites
  where id = p_invite_id and invited_user_id = v_uid
    and status = 'pending';
  if v_inv.id is null then
    raise exception 'invite not found';
  end if;

  if p_accept then
    -- Daha önce removed/suspended üyelik varsa yeniden aktifleştirilir
    -- (rol/izinler davettekiyle güncellenir).
    insert into public.branch_memberships
      (branch_id, owner_id, user_id, role, permissions, status)
    values
      (v_inv.branch_id, v_inv.owner_id, v_uid, v_inv.role,
       v_inv.permissions, 'active')
    on conflict (branch_id, user_id) do update
      set role = excluded.role,
          permissions = excluded.permissions,
          status = 'active',
          updated_at = now();
    update public.branch_invites
      set status = 'accepted', responded_at = now()
    where id = p_invite_id;
  else
    update public.branch_invites
      set status = 'rejected', responded_at = now()
    where id = p_invite_id;
  end if;

  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type,
     note)
  values (v_inv.branch_id, v_inv.owner_id, v_uid, 'invite_responded',
          case when p_accept then 'accepted' else 'rejected' end);
end;
$$;
revoke execute on function public.respond_branch_invite(uuid, boolean)
  from public, anon;
grant execute on function public.respond_branch_invite(uuid, boolean)
  to authenticated;

-- ── Daveti geri çek (patron) ──
create or replace function public.cancel_branch_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  update public.branch_invites
    set status = 'revoked', responded_at = now()
  where id = p_invite_id and owner_id = v_uid and status = 'pending';
end;
$$;
revoke execute on function public.cancel_branch_invite(uuid)
  from public, anon;
grant execute on function public.cancel_branch_invite(uuid) to authenticated;

-- ── Üyelik durumu değiştir (patron: aktif/askıya al/çıkar) ──
create or replace function public.set_branch_membership_status(
  p_membership_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_status not in ('active', 'suspended', 'removed') then
    raise exception 'invalid status';
  end if;
  select * into v_row
  from public.branch_memberships
  where id = p_membership_id and owner_id = v_uid;
  if v_row.id is null then
    raise exception 'membership not found';
  end if;
  update public.branch_memberships
    set status = p_status, updated_at = now()
  where id = p_membership_id;
  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type, note)
  values (v_row.branch_id, v_uid, v_uid, 'membership_changed', p_status);
end;
$$;
revoke execute on function public.set_branch_membership_status(uuid, text)
  from public, anon;
grant execute on function public.set_branch_membership_status(uuid, text)
  to authenticated;

-- ── Süreç oluştur (owner VEYA izinli aktif üye — server-side denetim) ──
create or replace function public.create_branch_process(
  p_branch_id uuid,
  p_type text,
  p_title text,
  p_note text default null,
  p_priority text default 'normal',
  p_assigned_to uuid default null,
  p_due_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if not public.has_branch_process_permission(p_branch_id, p_type) then
    raise exception 'not allowed';
  end if;
  select owner_id into v_owner from public.branches where id = p_branch_id;
  if v_owner is null then
    raise exception 'branch not found';
  end if;
  -- assigned_to yalnız owner veya o şubenin aktif üyesi olabilir.
  if p_assigned_to is not null
     and p_assigned_to <> v_owner
     and not exists (
       select 1 from public.branch_memberships
       where branch_id = p_branch_id and user_id = p_assigned_to
         and status = 'active'
     ) then
    raise exception 'assignee not in branch';
  end if;

  insert into public.branch_processes
    (branch_id, owner_id, created_by, assigned_to, type, title, note,
     priority, due_at)
  values
    (p_branch_id, v_owner, v_uid, p_assigned_to, p_type, trim(p_title),
     nullif(p_note, ''), p_priority, p_due_at)
  returning id into v_id;

  insert into public.branch_activity_log
    (branch_id, owner_id, process_id, actor_id, event_type)
  values (p_branch_id, v_owner, v_id, v_uid, 'process_created');
  return v_id;
end;
$$;
revoke execute on function public.create_branch_process(
  uuid, text, text, text, text, uuid, timestamptz) from public, anon;
grant execute on function public.create_branch_process(
  uuid, text, text, text, text, uuid, timestamptz) to authenticated;

-- ── Süreç güncelle (durum/not/başlık; izin denetimi server-side) ──
create or replace function public.update_branch_process(
  p_process_id uuid,
  p_status text default null,
  p_note text default null,
  p_title text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  select * into v_row from public.branch_processes where id = p_process_id;
  if v_row.id is null then
    raise exception 'process not found';
  end if;
  -- İzin: sürecin tipi üzerinden (owner her zaman; üye izinliyse).
  if not public.has_branch_process_permission(v_row.branch_id, v_row.type) then
    raise exception 'not allowed';
  end if;
  if p_status is not null
     and p_status not in ('pending', 'in_progress', 'completed', 'attention')
  then
    raise exception 'invalid status';
  end if;

  update public.branch_processes
    set status = coalesce(p_status, status),
        note = coalesce(nullif(p_note, ''), note),
        title = coalesce(nullif(trim(coalesce(p_title, '')), ''), title),
        completed_at = case
          when p_status = 'completed' then now()
          when p_status is not null then null
          else completed_at
        end,
        updated_at = now()
  where id = p_process_id;

  insert into public.branch_activity_log
    (branch_id, owner_id, process_id, actor_id, event_type, note)
  values (v_row.branch_id, v_row.owner_id, p_process_id, v_uid,
          case when p_status is not null then 'status_changed'
               else 'process_updated' end,
          p_status);
end;
$$;
revoke execute on function public.update_branch_process(uuid, text, text, text)
  from public, anon;
grant execute on function public.update_branch_process(uuid, text, text, text)
  to authenticated;
