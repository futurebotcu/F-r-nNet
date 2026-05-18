-- =============================================================================
-- FırınNet Groups V1 Sprint 2 — Owner Leave Auto-Handoff + Remove Member
-- =============================================================================
-- Ürün kararı (sprint brief): WhatsApp benzeri davranış.
--   * Owner gruptan çıkarsa: başka üye varsa liderlik otomatik en eski üyeye
--     geçer; tek başınaysa grup soft-delete olur.
--   * Owner üye çıkarabilir (owner kendisini çıkaramaz; bunun için leave RPC).
-- Tüm operasyonlar atomik (race-safe) olmak için SECURITY DEFINER RPC.
--
-- group_members tablosunda PK = (group_id, owner_id). `owner_id` burada
-- "membership owner" = üyenin user_id'si demek (kafa karıştıran ama mevcut
-- şema). `role` 'owner' veya 'member' (CHECK yok, serbest text default
-- 'member').
--
-- Bu migration:
--   1) leave_group_safely(p_group_id uuid) returns text
--      → 'left' | 'transferred' | 'closed'
--   2) remove_group_member(p_group_id uuid, p_member_id uuid) returns text
--      → 'removed' (owner-only; owner kendisini çıkaramaz)
--
-- Rollback (manuel):
--   drop function if exists public.leave_group_safely(uuid);
--   drop function if exists public.remove_group_member(uuid, uuid);
-- =============================================================================

-- -----------------------------------------------------------------------------
-- RPC: leave_group_safely
-- -----------------------------------------------------------------------------
-- Owner ve non-owner için tek giriş noktası. Aşağıdaki davranış:
--   * caller == owner ve başka üye var → en eski üyeye handoff;
--     yeni lider role='owner'; eski owner üyeliği silinir; 'transferred'.
--   * caller == owner ve başka üye yok → social_groups.is_deleted=true;
--     eski owner üyeliği silinir; 'closed'.
--   * caller != owner → kendi group_members satırı silinir; 'left'.
--   * is_deleted=true grup için 'group_not_found' raise.
--   * auth yoksa 'auth_required'.
create or replace function public.leave_group_safely(
  p_group_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id   uuid := auth.uid();
  v_group     public.social_groups%ROWTYPE;
  v_next_id   uuid;
  v_next_name text;
begin
  if v_user_id is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  select * into v_group
    from public.social_groups
    where id = p_group_id;
  if not found or v_group.is_deleted then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;

  -- Non-owner: yalnız kendisini çıkar.
  if v_group.owner_id <> v_user_id then
    delete from public.group_members
      where group_id = p_group_id
        and owner_id = v_user_id;
    return 'left';
  end if;

  -- Owner: en eski non-owner üyeyi bul.
  select gm.owner_id
    into v_next_id
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.owner_id <> v_user_id
    order by gm.joined_at asc
    limit 1;

  if v_next_id is not null then
    -- Devir: yeni lider ata.
    select coalesce(display_name, 'FırınNet Kullanıcısı')
      into v_next_name
      from public.profiles
      where id = v_next_id;

    update public.social_groups
      set owner_id = v_next_id,
          owner_name = v_next_name
      where id = p_group_id;

    update public.group_members
      set role = 'owner'
      where group_id = p_group_id
        and owner_id = v_next_id;

    delete from public.group_members
      where group_id = p_group_id
        and owner_id = v_user_id;

    return 'transferred';
  end if;

  -- Yalnız kalan kurucu: grubu kapat.
  update public.social_groups
    set is_deleted = true
    where id = p_group_id;

  delete from public.group_members
    where group_id = p_group_id
      and owner_id = v_user_id;

  return 'closed';
end;
$$;

revoke execute on function public.leave_group_safely(uuid) from public;
revoke execute on function public.leave_group_safely(uuid) from anon;
grant  execute on function public.leave_group_safely(uuid) to authenticated;

comment on function public.leave_group_safely(uuid) is
  'V1 Sprint 2 — Owner-leave auto-handoff veya group close; non-owner için ' ||
  'kendi çıkışı. Atomik (SECURITY DEFINER). Returns: left|transferred|closed.';


-- -----------------------------------------------------------------------------
-- RPC: remove_group_member
-- -----------------------------------------------------------------------------
-- Owner-only. Hedef üye gruptan silinir.
--   * caller owner değil → 'not_group_owner'
--   * hedef == owner → 'cannot_remove_owner' (owner kendisini bu fonksiyonla
--     çıkaramaz; leave_group_safely kullanmalı)
--   * hedef üye yok → 'member_not_found'
--   * is_deleted=true grup → 'group_not_found'
create or replace function public.remove_group_member(
  p_group_id  uuid,
  p_member_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group   public.social_groups%ROWTYPE;
  v_count   integer;
begin
  if v_user_id is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  select * into v_group
    from public.social_groups
    where id = p_group_id;
  if not found or v_group.is_deleted then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;

  if v_group.owner_id <> v_user_id then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;

  if p_member_id = v_group.owner_id then
    raise exception 'cannot_remove_owner' using errcode = 'P0001';
  end if;

  delete from public.group_members
    where group_id = p_group_id
      and owner_id = p_member_id;
  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'member_not_found' using errcode = 'P0002';
  end if;

  return 'removed';
end;
$$;

revoke execute on function public.remove_group_member(uuid, uuid) from public;
revoke execute on function public.remove_group_member(uuid, uuid) from anon;
grant  execute on function public.remove_group_member(uuid, uuid) to authenticated;

comment on function public.remove_group_member(uuid, uuid) is
  'V1 Sprint 2 — Owner-only üye çıkarma. Owner kendisini çıkaramaz; ' ||
  'leave_group_safely kullanılmalı. SECURITY DEFINER. Returns: removed.';
