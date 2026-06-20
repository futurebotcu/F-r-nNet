-- feature/dealer-driver-permission-levels — V1 (dar kapsam).
-- Şoför yetki seviyesi: 'half' (varsayılan) / 'full'. Tam yetkili şofor yalnız
-- ATANMIŞ bayilerde fiyat ekleme/düzenleme + işlem silme/iptal + düzeltme
-- (adjustment) yapabilir. RLS doğrudan gevşetilmez; yazımlar SECURITY DEFINER
-- RPC üzerinden (driver_add_transaction deseni: atama + owner + permission
-- doğrulanır, owner_id=patron yazılır). public/anon execute kapalı.
-- NOT: Bu dosya MCP apply_migration ile uygulanan migration'ın izlenebilir
-- kopyasıdır (aynı isim/içerik).

-- 1) permission_level kolonları (default 'half')
ALTER TABLE public.dealer_drivers
  ADD COLUMN IF NOT EXISTS permission_level text NOT NULL DEFAULT 'half'
  CHECK (permission_level IN ('half','full'));
ALTER TABLE public.dealer_driver_invites
  ADD COLUMN IF NOT EXISTS permission_level text NOT NULL DEFAULT 'half'
  CHECK (permission_level IN ('half','full'));

-- 2) create_driver_invite: p_permission_level taşır (eski 4-arg drop edilir)
DROP FUNCTION IF EXISTS public.create_driver_invite(text, text, text, text);
CREATE FUNCTION public.create_driver_invite(
  p_target_firinnet_id text,
  p_driver_name text DEFAULT NULL::text,
  p_driver_phone text DEFAULT NULL::text,
  p_note text DEFAULT NULL::text,
  p_permission_level text DEFAULT 'half'
) RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_fn text := upper(trim(coalesce(p_target_firinnet_id, '')));
  v_perm text := lower(coalesce(p_permission_level, 'half'));
  v_target uuid;
  v_pending_count int;
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_driver_name), '') = '' then raise exception 'name required'; end if;
  if v_fn = '' then raise exception 'invite failed'; end if;
  if v_perm not in ('half','full') then raise exception 'invalid permission'; end if;

  select id into v_target from public.profiles where firinnet_id = v_fn;
  if v_target is null then raise exception 'invite failed'; end if;
  if v_target = v_uid then raise exception 'cannot invite self'; end if;
  if exists (select 1 from public.dealer_drivers where owner_id = v_uid and driver_user_id = v_target) then
    raise exception 'already a driver'; end if;
  if exists (select 1 from public.dealer_driver_invites where owner_id = v_uid and invited_user_id = v_target and status = 'pending') then
    raise exception 'invite already pending'; end if;

  select count(*) into v_pending_count from public.dealer_driver_invites where owner_id = v_uid and status = 'pending';
  if v_pending_count >= 20 then raise exception 'too many pending invites'; end if;

  insert into public.dealer_driver_invites (owner_id, invited_user_id, driver_name, driver_phone, note, permission_level)
  values (v_uid, v_target, trim(p_driver_name), nullif(p_driver_phone, ''), nullif(p_note, ''), v_perm)
  returning id into v_id;
  return v_id;
end;
$function$;

-- 3) respond_driver_invite: kabulde permission_level kopyalanır
CREATE OR REPLACE FUNCTION public.respond_driver_invite(p_invite_id uuid, p_accept boolean)
  RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
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
    insert into public.dealer_drivers (owner_id, driver_user_id, name, phone, note, permission_level)
    values (v_owner, v_uid, v_name, v_phone, v_note, coalesce(v_perm, 'half'))
    on conflict (owner_id, driver_user_id) do nothing;
    update public.dealer_driver_invites set status = 'accepted', responded_at = now() where id = p_invite_id;
  else
    update public.dealer_driver_invites set status = 'rejected', responded_at = now() where id = p_invite_id;
  end if;
end;
$function$;

-- 4) driver_add_transaction: adjustment yalnız full şofore açık
CREATE OR REPLACE FUNCTION public.driver_add_transaction(
  p_dealer_id uuid, p_type text, p_amount numeric DEFAULT 0,
  p_quantity integer DEFAULT NULL::integer, p_unit_price numeric DEFAULT NULL::numeric,
  p_payment_method text DEFAULT NULL::text, p_product_name text DEFAULT NULL::text,
  p_note text DEFAULT NULL::text, p_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
  RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_driver uuid; v_owner uuid; v_perm text;
  v_dealer_owner uuid; v_dealer_active boolean; v_bakery uuid;
  v_at timestamptz := coalesce(p_created_at, now());
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select dd.id, dd.owner_id, dd.permission_level into v_driver, v_owner, v_perm
  from public.dealer_driver_assignments a
  join public.dealer_drivers dd on dd.id = a.driver_id
  where a.dealer_id = p_dealer_id and dd.driver_user_id = v_uid and dd.is_active = true
  limit 1;
  if v_driver is null then raise exception 'not assigned to this dealer'; end if;

  if p_type not in ('delivery', 'payment', 'return', 'adjustment') then raise exception 'invalid type'; end if;
  if p_type = 'adjustment' and coalesce(v_perm, 'half') <> 'full' then raise exception 'permission required'; end if;
  if p_amount is null then raise exception 'invalid amount'; end if;
  if p_type <> 'adjustment' and p_amount < 0 then raise exception 'invalid amount'; end if;
  if p_type = 'adjustment' and p_amount = 0 then raise exception 'invalid amount'; end if;

  select owner_id, is_active, bakery_id into v_dealer_owner, v_dealer_active, v_bakery
  from public.dealers where id = p_dealer_id;
  if v_dealer_owner is null then raise exception 'dealer not found'; end if;
  if v_dealer_owner <> v_owner then raise exception 'owner mismatch'; end if;
  if v_dealer_active is not true then raise exception 'dealer not active'; end if;

  if p_type = 'delivery' then
    if coalesce(p_quantity, 0) <= 0 or coalesce(p_unit_price, 0) < 0 then raise exception 'invalid delivery line'; end if;
    insert into public.dealer_deliveries(owner_id, bakery_id, dealer_id, driver_id, delivery_date, paid_amount, note)
      values (v_owner, v_bakery, p_dealer_id, v_driver, v_at::date, 0, nullif(p_note, '')) returning id into v_id;
    insert into public.dealer_delivery_items(delivery_id, owner_id, product_name, quantity, unit_price)
      values (v_id, v_owner, coalesce(p_product_name, ''), p_quantity, coalesce(p_unit_price, 0));
  else
    if p_type <> 'adjustment' and p_amount <= 0 then raise exception 'invalid amount'; end if;
    insert into public.dealer_transactions(owner_id, dealer_id, driver_id, type, product_name, quantity, unit_price, amount, payment_method, note, created_at)
      values (v_owner, p_dealer_id, v_driver, p_type, p_product_name, p_quantity, p_unit_price, p_amount, nullif(p_payment_method, ''), nullif(p_note, ''), v_at) returning id into v_id;
  end if;
  return v_id;
end;
$function$;

-- 5) driver_set_price: full şofor atanmış bayide yeni aktif fiyat ekler
CREATE OR REPLACE FUNCTION public.driver_set_price(
  p_dealer_id uuid, p_product_name text, p_unit_price numeric)
  RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_driver uuid; v_owner uuid; v_perm text; v_dealer_owner uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_product_name), '') = '' then raise exception 'product required'; end if;
  if p_unit_price is null or p_unit_price < 0 then raise exception 'invalid price'; end if;

  select dd.id, dd.owner_id, dd.permission_level into v_driver, v_owner, v_perm
  from public.dealer_driver_assignments a
  join public.dealer_drivers dd on dd.id = a.driver_id
  where a.dealer_id = p_dealer_id and dd.driver_user_id = v_uid and dd.is_active = true
  limit 1;
  if v_driver is null then raise exception 'not assigned to this dealer'; end if;
  if coalesce(v_perm, 'half') <> 'full' then raise exception 'permission required'; end if;

  select owner_id into v_dealer_owner from public.dealers where id = p_dealer_id;
  if v_dealer_owner is null then raise exception 'dealer not found'; end if;
  if v_dealer_owner <> v_owner then raise exception 'owner mismatch'; end if;

  insert into public.dealer_prices(owner_id, dealer_id, product_name, unit_price, valid_from)
    values (v_owner, p_dealer_id, trim(p_product_name), p_unit_price, current_date)
    returning id into v_id;
  return v_id;
end;
$function$;

-- 6) driver_delete_transaction: full şofor atanmış bayide işlem/teslimat siler
CREATE OR REPLACE FUNCTION public.driver_delete_transaction(
  p_id uuid, p_is_delivery boolean)
  RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_dealer uuid; v_row_owner uuid;
  v_driver uuid; v_owner uuid; v_perm text;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  if p_is_delivery then
    select d.dealer_id, di.owner_id into v_dealer, v_row_owner
    from public.dealer_delivery_items di
    join public.dealer_deliveries d on d.id = di.delivery_id
    where di.id = p_id;
  else
    select t.dealer_id, t.owner_id into v_dealer, v_row_owner
    from public.dealer_transactions t where t.id = p_id;
  end if;
  if v_dealer is null then raise exception 'record not found'; end if;

  select dd.id, dd.owner_id, dd.permission_level into v_driver, v_owner, v_perm
  from public.dealer_driver_assignments a
  join public.dealer_drivers dd on dd.id = a.driver_id
  where a.dealer_id = v_dealer and dd.driver_user_id = v_uid and dd.is_active = true
  limit 1;
  if v_driver is null then raise exception 'not assigned to this dealer'; end if;
  if coalesce(v_perm, 'half') <> 'full' then raise exception 'permission required'; end if;
  if v_row_owner <> v_owner then raise exception 'owner mismatch'; end if;

  if p_is_delivery then
    delete from public.dealer_delivery_items where id = p_id;
  else
    delete from public.dealer_transactions where id = p_id;
  end if;
end;
$function$;

-- 7) Execute grants: public/anon kapalı, authenticated açık
REVOKE EXECUTE ON FUNCTION public.create_driver_invite(text,text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.driver_set_price(uuid,text,numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.driver_delete_transaction(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_driver_invite(text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_set_price(uuid,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_delete_transaction(uuid,boolean) TO authenticated;
