-- Şube Yönetimi V2 — bildirimler + branch_manager yetkileri (ADDITIVE).
--
-- Kapsam:
--   1. In-app bildirim trigger'ları (mevcut public.notifications merkezi;
--      in_app_notification_events + dealer_driver_invite_notify emsali):
--      davet oluştu / davet yanıtlandı / üyelik askı-çıkarma / süreç oluştu /
--      süreç attention-completed.
--   2. branch_manager sınırlı yönetim yetkisi — SERVER-SIDE:
--      * create_branch_invite: owner VEYA aktif branch_manager (yalnız kendi
--        şubesi + yalnız alt roller; branch_manager rolü veremez).
--      * set_branch_membership_status: branch_manager yalnız kendi şubesinin
--        non-manager üyeleri üzerinde (kendisi ve manager'lar hariç).
--      * cancel_branch_invite: owner VEYA daveti oluşturan aktif manager.
--      * update_branch_membership_permissions (YENİ): owner tam; manager
--        yalnız non-manager üyelerde. Rol bu RPC ile DEĞİŞTİRİLEMEZ.
--   3. RLS SELECT genişletme (dar): aktif branch_manager kendi şubesinin
--      üyelik ve davet satırlarını görebilir (personel listesi/bekleyen
--      davet). Normal personel için değişiklik YOK; yazma policy'leri
--      açılmaz (fail-closed; tüm yazma RPC).
--
-- Geriye uyumluluk: V1 RPC imzaları korunur (create or replace, aynı
-- parametreler). Destructive değişiklik yok; mevcut veri bozulmaz.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. HELPER'LAR
-- ────────────────────────────────────────────────────────────────────────

-- Aktif şube sorumlusu mu? (SECURITY DEFINER — RLS recursion önler;
-- is_active_branch_member emsali.)
create or replace function public.is_active_branch_manager(p_branch_id uuid)
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
      and role = 'branch_manager'
  );
$$;
revoke execute on function public.is_active_branch_manager(uuid)
  from public, anon;
grant execute on function public.is_active_branch_manager(uuid)
  to authenticated;

-- Rol etiketi (bildirim metinleri için; client BranchRoleMeta.label ile
-- birebir aynı sözlük).
create or replace function public.branch_role_label(p_role text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_role
    when 'branch_manager' then 'Şube Sorumlusu'
    when 'counter' then 'Tezgah Personeli'
    when 'production' then 'Üretim Personeli'
    when 'cashier' then 'Kasa / Satış'
    when 'shipping' then 'Sevkiyat'
    when 'accounting_assistant' then 'Muhasebe / Cari Yardımcısı'
    else coalesce(p_role, '')
  end;
$$;
revoke execute on function public.branch_role_label(text)
  from public, anon, authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 2. RLS SELECT GENİŞLETME (yalnız aktif branch_manager; yazma policy YOK)
-- ────────────────────────────────────────────────────────────────────────

drop policy if exists branch_memberships_select on public.branch_memberships;
create policy branch_memberships_select on public.branch_memberships
  for select to authenticated
  using (
    owner_id = auth.uid()
    or user_id = auth.uid()
    or public.is_active_branch_manager(branch_id)
  );

drop policy if exists branch_invites_select on public.branch_invites;
create policy branch_invites_select on public.branch_invites
  for select to authenticated
  using (
    owner_id = auth.uid()
    or invited_user_id = auth.uid()
    or public.is_active_branch_manager(branch_id)
  );

-- Grant hijyeni (V2 smoke bulgusu): Supabase default privileges, RPC-only
-- tablolarda authenticated'a yazma grant'ı bırakmıştı (RLS policy'siz yazmayı
-- zaten 0 satırla engelliyordu — aktif açık değil). V1'in beyan ettiği asgari
-- grant setine indirilir; append-only artık grant katmanında da kapalı.
revoke insert, update, delete, truncate, references, trigger
  on public.branch_activity_log from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.branch_memberships from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.branch_invites from authenticated;
revoke insert, update, truncate, references, trigger
  on public.branch_processes from authenticated;
revoke truncate, references, trigger
  on public.branches from authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 3. RPC GÜNCELLEMELERİ (aynı imza; branch_manager sınırlı yetki eklenir)
-- ────────────────────────────────────────────────────────────────────────

-- ── Personel daveti oluştur: owner VEYA aktif branch_manager ──
-- Manager kuralları (server-side; UI yalnız UX filtresi):
--   * yalnız aktif üyesi olduğu şubeye davet atar,
--   * branch_manager rolü VEREMEZ (alt roller serbest),
--   * davetin owner_id'si her zaman ŞUBE SAHİBİDİR (invited_by = manager).
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
  -- Manager rol tavanı: kendi rolünü (veya üstünü) DAĞITAMAZ.
  if v_is_manager and p_role = 'branch_manager' then
    raise exception 'role not allowed';
  end if;

  -- FN-AUDIT-012 emsali saatlik rate limit — FN-ID ÇÖZÜLMEDEN ÖNCE
  -- (davet eden kullanıcı başına; enumeration denemelerini de frenler).
  select count(*) into v_hourly_count
  from public.branch_invites
  where invited_by = v_uid
    and created_at > now() - interval '1 hour';
  if v_hourly_count >= 10 then
    raise exception 'too many invites';
  end if;

  -- FN-ID boş/bulunamadı/uygunsuz hesap türü → HEP AYNI nötr hata.
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
  -- Bekleyen davet tavanı işletme (owner) başınadır.
  select count(*) into v_pending_count
  from public.branch_invites
  where owner_id = v_owner and status = 'pending';
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

-- ── Daveti geri çek: owner VEYA daveti oluşturan aktif manager ──
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
  where id = p_invite_id
    and status = 'pending'
    and (owner_id = v_uid
         or (invited_by = v_uid
             and public.is_active_branch_manager(branch_id)));
end;
$$;
revoke execute on function public.cancel_branch_invite(uuid)
  from public, anon;
grant execute on function public.cancel_branch_invite(uuid) to authenticated;

-- ── Üyelik durumu değiştir: owner tam; manager sınırlı ──
-- Manager: yalnız kendi şubesinin NON-MANAGER üyeleri; kendi üyeliğine ve
-- diğer manager'lara/owner'a DOKUNAMAZ (yetki yükseltme kapalı).
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
  v_is_owner boolean;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_status not in ('active', 'suspended', 'removed') then
    raise exception 'invalid status';
  end if;
  select * into v_row
  from public.branch_memberships
  where id = p_membership_id;
  if v_row.id is null then
    raise exception 'membership not found';
  end if;
  v_is_owner := (v_row.owner_id = v_uid);
  if not v_is_owner then
    -- Manager yolu: nötr hata (satır varlığı sızdırılmaz).
    if not public.is_active_branch_manager(v_row.branch_id)
       or v_row.user_id = v_uid
       or v_row.role = 'branch_manager' then
      raise exception 'membership not found';
    end if;
  end if;
  update public.branch_memberships
    set status = p_status, updated_at = now()
  where id = p_membership_id;
  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type, note)
  values (v_row.branch_id, v_row.owner_id, v_uid, 'membership_changed',
          p_status);
end;
$$;
revoke execute on function public.set_branch_membership_status(uuid, text)
  from public, anon;
grant execute on function public.set_branch_membership_status(uuid, text)
  to authenticated;

-- ── Üyelik süreç izinlerini güncelle (YENİ; rol DEĞİŞMEZ) ──
create or replace function public.update_branch_membership_permissions(
  p_membership_id uuid,
  p_permissions jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
  v_perms jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  select * into v_row
  from public.branch_memberships
  where id = p_membership_id;
  if v_row.id is null then
    raise exception 'membership not found';
  end if;
  if v_row.owner_id is distinct from v_uid then
    if not public.is_active_branch_manager(v_row.branch_id)
       or v_row.user_id = v_uid
       or v_row.role = 'branch_manager' then
      raise exception 'membership not found';
    end if;
  end if;
  select coalesce(jsonb_agg(distinct t), '[]'::jsonb) into v_perms
  from jsonb_array_elements_text(
         case when jsonb_typeof(p_permissions) = 'array'
              then p_permissions else '[]'::jsonb end
       ) as e(t)
  where t = any (public.branch_process_types());
  update public.branch_memberships
    set permissions = v_perms, updated_at = now()
  where id = p_membership_id;
  insert into public.branch_activity_log
    (branch_id, owner_id, actor_id, event_type, note)
  values (v_row.branch_id, v_row.owner_id, v_uid, 'membership_changed',
          'permissions');
end;
$$;
revoke execute on function
  public.update_branch_membership_permissions(uuid, jsonb)
  from public, anon;
grant execute on function
  public.update_branch_membership_permissions(uuid, jsonb)
  to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 4. BİLDİRİM TRIGGER'LARI (mevcut notifications merkezi; definer INSERT)
--    Kurallar: actor kendine bildirim ALMAZ; alıcı listesi tekilleştirilir;
--    route'lar guard'lı yüzeyler (/my-branch fail-closed, /branches RLS).
-- ────────────────────────────────────────────────────────────────────────

-- Ortak dar yardımcı: profil görünen adı (definer içi kullanım).
create or replace function public.branch_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(trim(coalesce(display_name, '')), '')
  from public.profiles where id = p_user_id;
$$;
revoke execute on function public.branch_display_name(uuid)
  from public, anon, authenticated;

-- ── A) Davet oluştu → davetliye ──
create or replace function public.notify_branch_invite_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch text;
  v_inviter text;
begin
  if new.invited_user_id is distinct from new.invited_by then
    select name into v_branch from public.branches where id = new.branch_id;
    v_inviter := coalesce(
      public.branch_display_name(new.invited_by), 'Bir işletme');
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id,
       route)
    values
      (new.invited_user_id, new.invited_by, 'branch_invite_created',
       'Şube davetin var',
       v_inviter || ' seni ' || coalesce(v_branch, 'şube') ||
         ' şubesine ' || public.branch_role_label(new.role) ||
         ' olarak davet etti.',
       'branch_invite', new.id, '/my-branch');
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_branch_invite_created()
  from public, anon, authenticated;
drop trigger if exists trg_notify_branch_invite_created
  on public.branch_invites;
create trigger trg_notify_branch_invite_created
  after insert on public.branch_invites
  for each row execute function public.notify_branch_invite_created();

-- ── B/C) Davet yanıtlandı → owner'a (+ daveti atan manager'a) ──
create or replace function public.notify_branch_invite_responded()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch text;
  v_staff text;
  v_title text;
  v_body text;
  v_type text;
  v_recipient uuid;
begin
  select name into v_branch from public.branches where id = new.branch_id;
  v_staff := coalesce(
    public.branch_display_name(new.invited_user_id), 'Davet edilen personel');
  if new.status = 'accepted' then
    v_type := 'branch_invite_accepted';
    v_title := 'Personel daveti kabul edildi';
    v_body := v_staff || ' ' || coalesce(v_branch, 'şube') ||
      ' şubesine katıldı.';
  else
    v_type := 'branch_invite_rejected';
    v_title := 'Personel daveti reddedildi';
    v_body := v_staff || ' ' || coalesce(v_branch, 'şube') ||
      ' şubesi davetini reddetti.';
  end if;
  -- Alıcılar: işletme sahibi + (farklıysa) daveti oluşturan manager;
  -- aktör (davetli) hariç, tekil.
  for v_recipient in
    select distinct r from unnest(
      array[new.owner_id, new.invited_by]) as r
    where r is not null and r is distinct from new.invited_user_id
  loop
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id,
       route)
    values
      (v_recipient, new.invited_user_id, v_type, v_title, v_body,
       'branch_invite', new.id,
       case when v_recipient = new.owner_id
            then '/branches/' || new.branch_id::text
            else '/my-branch' end);
  end loop;
  return new;
end;
$$;
revoke execute on function public.notify_branch_invite_responded()
  from public, anon, authenticated;
drop trigger if exists trg_notify_branch_invite_responded
  on public.branch_invites;
create trigger trg_notify_branch_invite_responded
  after update on public.branch_invites
  for each row
  when (old.status = 'pending' and new.status in ('accepted', 'rejected'))
  execute function public.notify_branch_invite_responded();

-- ── D) Üyelik askıya alındı / çıkarıldı → personele ──
-- actor_id NULL + kişisel bilgi içermeyen metin (dealer davet emsali).
create or replace function public.notify_branch_membership_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch text;
begin
  if new.status in ('suspended', 'removed')
     and new.user_id is distinct from auth.uid() then
    select name into v_branch from public.branches where id = new.branch_id;
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id,
       route)
    values
      (new.user_id, null, 'branch_membership_updated',
       'Şube erişimin güncellendi',
       coalesce(v_branch, 'Şube') || ' için erişimin ' ||
         case when new.status = 'suspended'
              then 'askıya alındı.' else 'kapatıldı.' end,
       'branch_membership', new.id, '/my-branch');
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_branch_membership_status()
  from public, anon, authenticated;
drop trigger if exists trg_notify_branch_membership_status
  on public.branch_memberships;
create trigger trg_notify_branch_membership_status
  after update on public.branch_memberships
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_branch_membership_status();

-- ── E) Süreç oluştu → owner'a (+ atanmış personele) ──
create or replace function public.notify_branch_process_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch text;
begin
  select name into v_branch from public.branches where id = new.branch_id;
  if new.owner_id is distinct from new.created_by then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id,
       route)
    values
      (new.owner_id, new.created_by, 'branch_process_created',
       'Yeni şube süreci',
       coalesce(v_branch, 'Şube') || ': ' || new.title,
       'branch_process', new.id, '/branches/' || new.branch_id::text);
  end if;
  if new.assigned_to is not null
     and new.assigned_to is distinct from new.created_by
     and new.assigned_to is distinct from new.owner_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id,
       route)
    values
      (new.assigned_to, new.created_by, 'branch_process_created',
       'Sana yeni süreç atandı',
       coalesce(v_branch, 'Şube') || ': ' || new.title,
       'branch_process', new.id, '/my-branch');
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_branch_process_created()
  from public, anon, authenticated;
drop trigger if exists trg_notify_branch_process_created
  on public.branch_processes;
create trigger trg_notify_branch_process_created
  after insert on public.branch_processes
  for each row execute function public.notify_branch_process_created();

-- ── F/G) Süreç attention/completed oldu ──
-- attention → owner + şubenin aktif branch_manager'ları (aktör hariç);
-- completed → owner + atanmış personel (aktör hariç).
create or replace function public.notify_branch_process_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_branch text;
  v_recipient uuid;
begin
  if new.status not in ('attention', 'completed') then
    return new;
  end if;
  select name into v_branch from public.branches where id = new.branch_id;
  if new.status = 'attention' then
    for v_recipient in
      select distinct r from (
        select new.owner_id as r
        union
        select m.user_id from public.branch_memberships m
        where m.branch_id = new.branch_id
          and m.status = 'active'
          and m.role = 'branch_manager'
      ) recipients
      where r is not null and r is distinct from v_actor
    loop
      insert into public.notifications
        (recipient_id, actor_id, type, title, body, entity_type, entity_id,
         route)
      values
        (v_recipient, v_actor, 'branch_process_attention',
         'Şubede dikkat gereken süreç var',
         coalesce(v_branch, 'Şube') || ': ' || new.title,
         'branch_process', new.id,
         case when v_recipient = new.owner_id
              then '/branches/' || new.branch_id::text
              else '/my-branch' end);
    end loop;
  else
    for v_recipient in
      select distinct r from unnest(
        array[new.owner_id, new.assigned_to]) as r
      where r is not null and r is distinct from v_actor
    loop
      insert into public.notifications
        (recipient_id, actor_id, type, title, body, entity_type, entity_id,
         route)
      values
        (v_recipient, v_actor, 'branch_process_completed',
         'Süreç tamamlandı',
         coalesce(v_branch, 'Şube') || ': ' || new.title,
         'branch_process', new.id,
         case when v_recipient = new.owner_id
              then '/branches/' || new.branch_id::text
              else '/my-branch' end);
    end loop;
  end if;
  return new;
end;
$$;
revoke execute on function public.notify_branch_process_status()
  from public, anon, authenticated;
drop trigger if exists trg_notify_branch_process_status
  on public.branch_processes;
create trigger trg_notify_branch_process_status
  after update on public.branch_processes
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_branch_process_status();
