-- Bayi Yönetimi — Şoförler · Sprint 4: ŞOFÖR İŞLEM YAZMA (yalnız SECURITY DEFINER RPC).
--
-- Şoför, YALNIZCA kendisine atanmış bayiye delivery/payment/return yazabilir.
-- Yazma doğrudan tablo INSERT politikasıyla DEĞİL, güvenli RPC ile yapılır.
--
-- Prensip:
--   * dealer_transactions/dealer_deliveries owner-only INSERT/UPDATE/DELETE RLS
--     GEVŞETİLMEZ; şoföre direct INSERT/UPDATE/DELETE politikası YOK.
--   * owner_id daima patron; driver_id daima ilgili dealer_drivers kaydı.
--   * Tek defter: şoför işlemi patronun ana defterine (dealer_transactions /
--     dealer_deliveries) düşer; ayrı defter yok. Bakiye/gün sonu/rapor mevcut
--     sistemden hesaplanmaya devam eder.
--   * Tüm yetki kontrolleri RPC içinde açık yapılır (SECURITY DEFINER RLS'i
--     bypass edebileceği için). Dynamic SQL YOK.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ── delivery atfı için: dealer_deliveries.driver_id (additive, nullable) ──
-- delivery satırları dealer_deliveries'e gider; şoför teslimatını işaretlemek
-- için (eski satırlar NULL → değişmez). dealer_transactions.driver_id Sprint 1'de eklendi.
alter table public.dealer_deliveries
  add column if not exists driver_id uuid references public.dealer_drivers(id) on delete set null;

-- ── Şoför işlem yazma RPC ──
create or replace function public.driver_add_transaction(
  p_dealer_id uuid,
  p_type text,
  p_amount numeric default 0,
  p_quantity integer default null,
  p_unit_price numeric default null,
  p_payment_method text default null,
  p_product_name text default null,
  p_note text default null,
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_driver uuid;        -- dealer_drivers.id
  v_owner uuid;         -- patron (dealer_drivers.owner_id)
  v_dealer_owner uuid;
  v_dealer_active boolean;
  v_bakery uuid;
  v_at timestamptz := coalesce(p_created_at, now());
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  -- Şoföre yalnız delivery/payment/return açık (adjustment patron tarafında kalır).
  if p_type not in ('delivery', 'payment', 'return') then
    raise exception 'invalid type';
  end if;
  if p_amount is null or p_amount < 0 then
    raise exception 'invalid amount';
  end if;

  -- Aktif olarak bu bayiye atanmış şoför mü? (assignment → driver → user)
  select dd.id, dd.owner_id
    into v_driver, v_owner
  from public.dealer_driver_assignments a
  join public.dealer_drivers dd on dd.id = a.driver_id
  where a.dealer_id = p_dealer_id
    and dd.driver_user_id = v_uid
    and dd.is_active = true
  limit 1;
  if v_driver is null then
    raise exception 'not assigned to this dealer';
  end if;

  -- Bayi sahibi + aktiflik + tek-patron tutarlılığı.
  select owner_id, is_active, bakery_id
    into v_dealer_owner, v_dealer_active, v_bakery
  from public.dealers where id = p_dealer_id;
  if v_dealer_owner is null then
    raise exception 'dealer not found';
  end if;
  if v_dealer_owner <> v_owner then
    raise exception 'owner mismatch';
  end if;
  if v_dealer_active is not true then
    raise exception 'dealer not active';
  end if;

  if p_type = 'delivery' then
    if coalesce(p_quantity, 0) <= 0 or coalesce(p_unit_price, 0) < 0 then
      raise exception 'invalid delivery line';
    end if;
    insert into public.dealer_deliveries(
      owner_id, bakery_id, dealer_id, driver_id, delivery_date, paid_amount, note
    ) values (
      v_owner, v_bakery, p_dealer_id, v_driver, v_at::date, 0, nullif(p_note, '')
    ) returning id into v_id;
    insert into public.dealer_delivery_items(
      delivery_id, owner_id, product_name, quantity, unit_price
    ) values (
      v_id, v_owner, coalesce(p_product_name, ''), p_quantity, coalesce(p_unit_price, 0)
    );
  else
    -- payment / return → dealer_transactions
    if p_amount <= 0 then
      raise exception 'invalid amount';
    end if;
    insert into public.dealer_transactions(
      owner_id, dealer_id, driver_id, type, product_name, quantity,
      unit_price, amount, payment_method, note, created_at
    ) values (
      v_owner, p_dealer_id, v_driver, p_type, p_product_name, p_quantity,
      p_unit_price, p_amount, nullif(p_payment_method, ''), nullif(p_note, ''), v_at
    ) returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function public.driver_add_transaction(
  uuid, text, numeric, integer, numeric, text, text, text, timestamptz
) from public, anon;
grant execute on function public.driver_add_transaction(
  uuid, text, numeric, integer, numeric, text, text, text, timestamptz
) to authenticated;
