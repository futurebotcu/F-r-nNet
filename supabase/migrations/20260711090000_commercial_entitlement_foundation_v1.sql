-- Ticari İşletme Ücretlendirme Foundation V1 (ADDITIVE).
--
-- Amaç: paywall UI'dan ÖNCE güvenli server-side entitlement temeli. Ücretli
-- ticari aksiyonların REST/RPC bypass'ını kapatır. Ödeme entegrasyonu YOK,
-- büyük paywall UI YOK — yalnız DB temeli + gate'ler + minimal client.
--
-- Kapsam kararları (Gate Audit'ten):
--   * Şube Yönetimi = Premium
--   * Bayi Defteri = Pro'da 1 aktif bayi, Premium'da sınırsız
--   * Şoförlü bayi operasyonu = Premium
--   * Borç-Gider = Pro/Premium
--   * Reçete = Free 5 / Pro 50 / Premium sınırsız
--   * Hesaplama & Fırın Defteri rapor = client-side (server gate YOK)
--   * Trial 30 gün → effective plan = premium
--
-- KRİTİK TASARIM: Tüm gate helper'ları YALNIZ account_type='commercial'
-- kullanıcıya uygulanır. Bireysel/toptancı kullanıcılar (dealer/reçeteyi
-- ücretsiz kullananlar) gate'lerden GEÇER — mevcut davranış korunur, regresyon
-- olmaz. Ücretlendirme yalnız ticari işletmeyi hedefler.
--
-- Veri politikası: hiçbir SELECT policy'sine dokunulmaz; mevcut veri görünür
-- kalır. Yalnız YENİ-oluşturma (INSERT/expand) yolları gate'lenir. Silme/
-- gizleme YOK.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. TABLO: user_entitlements (owner başına tek satır)
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.user_entitlements (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free'
    check (plan in ('free', 'pro', 'premium')),
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  current_period_started_at timestamptz,
  current_period_ends_at timestamptz,
  source text not null default 'manual'
    check (source in ('manual', 'backoffice', 'iap', 'system')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.user_entitlements is
  'Ticari işletme ücretlendirme planı. Yazma yalnız service_role/backoffice '
  '(client self-upgrade imkânsız). SELECT yalnız kendi satırı. Trial aktifken '
  'effective plan = premium.';

drop trigger if exists trg_user_entitlements_set_updated_at
  on public.user_entitlements;
create trigger trg_user_entitlements_set_updated_at
before update on public.user_entitlements
for each row execute function public.set_updated_at();

-- ────────────────────────────────────────────────────────────────────────
-- 2. RLS + GRANTS
--    SELECT: yalnız kendi satırı. Yazma policy YOK → authenticated hiçbir
--    şekilde plan yazamaz (self-upgrade imkânsız). service_role backoffice.
-- ────────────────────────────────────────────────────────────────────────

alter table public.user_entitlements enable row level security;

drop policy if exists user_entitlements_select_own on public.user_entitlements;
create policy user_entitlements_select_own on public.user_entitlements
  for select to authenticated
  using (owner_id = auth.uid());

revoke all on public.user_entitlements from anon, public;
revoke insert, update, delete, truncate, references, trigger
  on public.user_entitlements from authenticated;
grant select on public.user_entitlements to authenticated;
-- Backoffice/edge plan yönetimi (yeni tabloya default privileges service_role'e
-- işlemez dersi — açık grant şart).
grant select, insert, update, delete
  on public.user_entitlements to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 3. HELPER FONKSİYONLAR (SECURITY DEFINER; policy + RPC içinde kullanılır)
-- ────────────────────────────────────────────────────────────────────────

-- Etkin plan: trial aktifse 'premium', değilse actual plan (satır yoksa 'free').
create or replace function public.current_business_plan(p_owner_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when e.trial_ends_at is not null and e.trial_ends_at > now() then 'premium'
    else coalesce(e.plan, 'free')
  end
  from (select p_owner_id as id) x
  left join public.user_entitlements e on e.owner_id = x.id;
$$;
revoke execute on function public.current_business_plan(uuid)
  from public, anon;
grant execute on function public.current_business_plan(uuid) to authenticated;

-- Boolean feature gate. TİCARİ OLMAYAN kullanıcı → daima true (mevcut davranış
-- korunur; ücretlendirme yalnız ticari işletmeye uygulanır).
create or replace function public.has_business_feature(
  p_owner_id uuid,
  p_feature text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_plan text;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  return case p_feature
    when 'branches' then v_plan = 'premium'
    when 'dealer_driver_ops' then v_plan = 'premium'
    when 'debt_expense' then v_plan in ('pro', 'premium')
    else false
  end;
end;
$$;
revoke execute on function public.has_business_feature(uuid, text)
  from public, anon;
grant execute on function public.has_business_feature(uuid, text)
  to authenticated;

-- Bayi ekleyebilir mi? Ticari değilse true. Premium/trial sınırsız; Pro 1 aktif
-- bayi (is_active=true); Free hayır.
create or replace function public.can_add_dealer(p_owner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_plan text;
  v_count int;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  if v_plan = 'premium' then
    return true;
  end if;
  if v_plan = 'pro' then
    select count(*) into v_count from public.dealers
      where owner_id = p_owner_id and is_active = true;
    return v_count < 1;
  end if;
  return false; -- free
end;
$$;
revoke execute on function public.can_add_dealer(uuid) from public, anon;
grant execute on function public.can_add_dealer(uuid) to authenticated;

-- Reçete ekleyebilir mi? Ticari değilse true. Premium/trial sınırsız; Pro <50;
-- Free <5. (Bireysel/işletme sayı ayrımı yok — ama gate yalnız ticariye.)
create or replace function public.can_add_recipe(p_owner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
  v_plan text;
  v_count int;
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  if v_plan = 'premium' then
    return true;
  end if;
  select count(*) into v_count from public.recipe_calculations
    where owner_id = p_owner_id;
  if v_plan = 'pro' then
    return v_count < 50;
  end if;
  return v_count < 5; -- free
end;
$$;
revoke execute on function public.can_add_recipe(uuid) from public, anon;
grant execute on function public.can_add_recipe(uuid) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 4. CLIENT RPC'LERİ (güvenli alanlar + satır garantisi)
-- ────────────────────────────────────────────────────────────────────────

-- Çağıranın entitlement'ı için güvenli alanlar. Internal source / ödeme
-- referansı DÖNMEZ. recipe_limit/dealer_limit: -1 = sınırsız.
create or replace function public.my_entitlement()
returns table (
  plan text,
  effective_plan text,
  is_trial_active boolean,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  days_left int,
  recipe_limit int,
  dealer_limit int,
  can_use_branches boolean,
  can_use_debt_expense boolean,
  can_use_dealer_driver_ops boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select
      public.current_business_plan(auth.uid()) as eff,
      e.plan as actual,
      e.trial_started_at,
      e.trial_ends_at
    from (select auth.uid() as id) x
    left join public.user_entitlements e on e.owner_id = x.id
  )
  select
    coalesce(me.actual, 'free'),
    me.eff,
    (me.trial_ends_at is not null and me.trial_ends_at > now()),
    me.trial_started_at,
    me.trial_ends_at,
    case
      when me.trial_ends_at is not null and me.trial_ends_at > now()
      then ceil(extract(epoch from (me.trial_ends_at - now())) / 86400.0)::int
      else 0
    end,
    case me.eff when 'premium' then -1 when 'pro' then 50 else 5 end,
    case me.eff when 'premium' then -1 when 'pro' then 1 else 0 end,
    public.has_business_feature(auth.uid(), 'branches'),
    public.has_business_feature(auth.uid(), 'debt_expense'),
    public.has_business_feature(auth.uid(), 'dealer_driver_ops')
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;

-- Satır garantisi: çağıranın entitlement'ı yoksa oluşturur. Ticari →
-- 30 gün trial. Diğer → free (etkisiz). Plan/status client'tan ALINMAZ.
create or replace function public.ensure_my_entitlement()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_acct text;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if exists (
    select 1 from public.user_entitlements where owner_id = v_uid
  ) then
    return;
  end if;
  select account_type into v_acct from public.profiles where id = v_uid;
  if v_acct = 'commercial' then
    insert into public.user_entitlements
      (owner_id, plan, trial_started_at, trial_ends_at, source)
    values (v_uid, 'free', now(), now() + interval '30 days', 'system')
    on conflict (owner_id) do nothing;
  else
    insert into public.user_entitlements (owner_id, plan, source)
    values (v_uid, 'free', 'system')
    on conflict (owner_id) do nothing;
  end if;
end;
$$;
revoke execute on function public.ensure_my_entitlement() from public, anon;
grant execute on function public.ensure_my_entitlement() to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 5. SERVER-SIDE GATE'LER — INSERT POLICY'LERİ (direct-write yolları)
--    Yalnız WITH CHECK'e entitlement koşulu eklenir; owner-scope korunur;
--    SELECT/UPDATE/DELETE policy'lerine DOKUNULMAZ.
-- ────────────────────────────────────────────────────────────────────────

-- Şube oluşturma → Premium (account_type='commercial' + plan).
drop policy if exists branches_insert on public.branches;
create policy branches_insert on public.branches
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and account_type = 'commercial'
    )
    and public.has_business_feature(auth.uid(), 'branches')
  );

-- Bayi oluşturma → Free hayır / Pro 1 aktif / Premium sınırsız.
drop policy if exists dealers_insert_own on public.dealers;
create policy dealers_insert_own on public.dealers
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.can_add_dealer(auth.uid())
  );

-- Şoför satırı direct insert → Premium (bypass kapanır; legit respond_driver_
-- invite RPC definer olduğu için etkilenmez).
drop policy if exists dealer_drivers_insert_own on public.dealer_drivers;
create policy dealer_drivers_insert_own on public.dealer_drivers
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.has_business_feature(auth.uid(), 'dealer_driver_ops')
  );

-- Borç-Gider yeni kayıt → Pro/Premium.
drop policy if exists debt_expense_insert_own on public.debt_expense_entries;
create policy debt_expense_insert_own on public.debt_expense_entries
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.has_business_feature(auth.uid(), 'debt_expense')
  );

-- Reçete oluşturma/kopyalama → 5/50/sınırsız.
drop policy if exists recipe_calculations_insert_own
  on public.recipe_calculations;
create policy recipe_calculations_insert_own on public.recipe_calculations
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.can_add_recipe(auth.uid())
  );

-- ────────────────────────────────────────────────────────────────────────
-- 6. SERVER-SIDE GATE'LER — RPC'LER (create/expand aksiyonları)
--    Plan kontrolü işletme SAHİBİ (v_owner) üzerinden; branch_manager/personel
--    kendi planıyla DEĞİL, bağlı olduğu işletmenin planıyla çalışır.
--    Bu PR yalnız CREATE/EXPAND aksiyonlarını gate'ler; mevcut süreç/üyelik
--    üzerindeki bakım/azaltma aksiyonları (update/suspend/remove/cancel)
--    kasıtlı olarak AÇIK bırakılır — "mevcut veri görünür + yönetilebilir
--    kalır" ilkesi ve kullanıcıyı sıkıştırmama. Gelir hattı create-gate'leriyle
--    tamamen korunur (premium olmadan GENİŞLETİLEMEZ).
-- ────────────────────────────────────────────────────────────────────────

-- ── Şube personel daveti (create/expand) → owner Premium ──
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
  v_owner uuid;
  v_is_owner boolean;
  v_is_manager boolean;
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
  select owner_id into v_owner from public.branches where id = p_branch_id;
  if v_owner is null then
    raise exception 'not branch owner';
  end if;
  v_is_owner := (v_owner = v_uid);
  v_is_manager := (not v_is_owner)
    and public.is_active_branch_manager(p_branch_id);
  if not (v_is_owner or v_is_manager) then
    raise exception 'not branch owner';
  end if;
  -- ENTITLEMENT: personel daveti = Şube Yönetimi = Premium. Owner planı.
  if not public.has_business_feature(v_owner, 'branches') then
    raise exception 'plan required';
  end if;
  if v_is_manager and p_role = 'branch_manager' then
    raise exception 'role not allowed';
  end if;

  select count(*) into v_hourly_count
  from public.branch_invites
  where invited_by = v_uid
    and created_at > now() - interval '1 hour';
  if v_hourly_count >= 10 then
    raise exception 'too many invites';
  end if;

  if v_fn = '' then
    raise exception 'invite failed';
  end if;
  select p.id, p.account_type into v_target, v_target_type
  from public.profiles p where p.firinnet_id = v_fn;
  if v_target is null then
    raise exception 'invite failed';
  end if;
  if v_target_type is distinct from 'individual' then
    raise exception 'invite failed';
  end if;
  if v_target = v_uid or v_target = v_owner then
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
  select count(*) into v_pending_count
  from public.branch_invites
  where owner_id = v_owner and status = 'pending';
  if v_pending_count >= 20 then
    raise exception 'too many invites';
  end if;

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
    (p_branch_id, v_owner, v_uid, v_target, p_role, v_perms,
     nullif(p_note, ''))
  returning id into v_id;

  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type)
  values (p_branch_id, v_owner, v_uid, 'invite_created');
  return v_id;
end;
$$;
revoke execute on function
  public.create_branch_invite(uuid, text, text, jsonb, text)
  from public, anon;
grant execute on function
  public.create_branch_invite(uuid, text, text, jsonb, text)
  to authenticated;

-- ── Şube süreci oluşturma (create/expand) → owner Premium ──
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
  -- ENTITLEMENT: yeni süreç = Şube Yönetimi = Premium. Owner planı.
  if not public.has_business_feature(v_owner, 'branches') then
    raise exception 'plan required';
  end if;
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

-- ── Şoför daveti (create/expand) → owner Premium (dealer_driver_ops) ──
create or replace function public.create_driver_invite(
  p_target_firinnet_id text,
  p_driver_name text default null,
  p_driver_phone text default null,
  p_note text default null,
  p_permission_level text default 'half'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_fn text := upper(trim(coalesce(p_target_firinnet_id, '')));
  v_perm text := lower(coalesce(p_permission_level, 'half'));
  v_target uuid;
  v_pending_count int;
  v_recent_count int;
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  -- ENTITLEMENT: şoförlü bayi operasyonu = Premium.
  if not public.has_business_feature(v_uid, 'dealer_driver_ops') then
    raise exception 'plan required';
  end if;
  if coalesce(trim(p_driver_name), '') = '' then raise exception 'name required'; end if;
  if v_perm not in ('half','full') then raise exception 'invalid permission'; end if;

  select count(*) into v_recent_count
  from public.dealer_driver_invites
  where owner_id = v_uid and created_at > now() - interval '1 hour';
  if v_recent_count >= 15 then raise exception 'too many invites'; end if;

  select count(*) into v_pending_count
  from public.dealer_driver_invites where owner_id = v_uid and status = 'pending';
  if v_pending_count >= 20 then raise exception 'too many invites'; end if;

  select id into v_target from public.profiles where firinnet_id = v_fn;
  if v_target is null
     or v_target = v_uid
     or exists (select 1 from public.dealer_drivers
                where owner_id = v_uid and driver_user_id = v_target)
     or exists (select 1 from public.dealer_driver_invites
                where owner_id = v_uid and invited_user_id = v_target and status = 'pending')
  then
    raise exception 'invite failed';
  end if;

  insert into public.dealer_driver_invites
    (owner_id, invited_user_id, driver_name, driver_phone, note, permission_level)
  values (v_uid, v_target, trim(p_driver_name), nullif(p_driver_phone, ''),
          nullif(p_note, ''), v_perm)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.create_driver_invite(
  text, text, text, text, text) from public, anon;
grant execute on function public.create_driver_invite(
  text, text, text, text, text) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 7. BACKFILL: mevcut ticari kullanıcılara 30 gün trial (retroaktif kilitleme
--    önlenir). Var olan satır BOZULMAZ (on conflict do nothing).
-- ────────────────────────────────────────────────────────────────────────

insert into public.user_entitlements
  (owner_id, plan, trial_started_at, trial_ends_at, source)
select p.id, 'free', now(), now() + interval '30 days', 'system'
from public.profiles p
where p.account_type = 'commercial'
on conflict (owner_id) do nothing;
