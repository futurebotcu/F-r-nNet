-- Ticari (İşletmeci) Lansman Modeli V1 (ADDITIVE).
--
-- Yalnız TİCARİ (commercial) hesapları etkiler; tedarikçi kampanyasına ve
-- bireysel hesaplara DOKUNULMAZ.
--
-- Model:
--   * Ücretsiz Premium dönemi OTOMATİKTİR (CTA yok): başlangıç =
--     GREATEST(auth.users.created_at, commercial_launch_start),
--     bitiş = başlangıç + 1 ay (Europe/Istanbul takvimi).
--   * commercial_launch_start null iken bu dal PASİFTİR (mevcut davranış
--     birebir korunur) — tarih uydurulmaz, migration null bırakır.
--   * Eski CTA promosu ticari hesapta YENİ aktivasyon vermez; MEVCUT aktif
--     promo hakkı korunur (effective plan sırasında promo dalı durur).
--   * commercial_launch_price_until yalnız BİLGİLENDİRME içindir (fiyatı
--     mağaza belirler; server fiyat zorlamaz).
--   * Effective plan sırası: ödenmiş abonelik → aktif eski promo →
--     kayıt bazlı ücretsiz ay → free. Legacy Pro = premium kuralı aynen.
--   * Otomatik ücret/abonelik YOK: dönem hakkı entitlement satırına
--     YAZILMAZ, yalnız türetimde okunur; dönem bitince free kurallar döner.

-- ────────────────────────────────────────────────────────────────────────
-- 1) Konfigürasyon (başlangıç kasıtlı null → pasif; bitiş fiyat dönemi
--    bilgilendirmesi için sabit).
-- ────────────────────────────────────────────────────────────────────────
insert into public.app_runtime_config (key, value) values
  ('commercial_launch_start', 'null'::jsonb),
  ('commercial_launch_price_until', '"2027-10-01T00:00:00+03:00"'::jsonb)
on conflict (key) do nothing;

create or replace function public.commercial_launch_start()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select public.app_config_timestamptz('commercial_launch_start', null);
$$;
revoke execute on function public.commercial_launch_start()
  from public, anon;
grant execute on function public.commercial_launch_start()
  to authenticated, service_role;

-- Lansman fiyat döneminin bitişi (bu an HARİÇ) — yalnız bilgilendirme.
create or replace function public.commercial_launch_price_until()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select public.app_config_timestamptz('commercial_launch_price_until', null);
$$;
revoke execute on function public.commercial_launch_price_until()
  from public, anon;
grant execute on function public.commercial_launch_price_until()
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 2) Kayıt bazlı ücretsiz ay penceresi (kişi başına).
--    Başlangıç: kayıt lansmandan ÖNCEyse lansmandan, SONRAysa kayıttan.
--    Süre: 1 takvim ayı (Europe/Istanbul). Bitiş anı HARİÇTİR.
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.commercial_launch_free_start(
  p_owner_id uuid
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_launch timestamptz := public.commercial_launch_start();
  v_created timestamptz;
begin
  if v_launch is null then return null; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_owner_id and p.account_type = 'commercial'
  ) then
    return null;
  end if;
  select u.created_at into v_created from auth.users u
  where u.id = p_owner_id;
  if v_created is null then return null; end if;
  return greatest(v_created, v_launch);
end;
$$;
revoke execute on function public.commercial_launch_free_start(uuid)
  from public, anon;
grant execute on function public.commercial_launch_free_start(uuid)
  to authenticated, service_role;

create or replace function public.commercial_launch_free_until(
  p_owner_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.commercial_launch_free_start(p_owner_id) is null then null
    else ((public.commercial_launch_free_start(p_owner_id)
             at time zone 'Europe/Istanbul') + interval '1 month')
           at time zone 'Europe/Istanbul'
  end;
$$;
revoke execute on function public.commercial_launch_free_until(uuid)
  from public, anon;
grant execute on function public.commercial_launch_free_until(uuid)
  to authenticated, service_role;

create or replace function public.is_commercial_launch_free_active(
  p_owner_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := public.commercial_launch_free_start(p_owner_id);
  v_until timestamptz;
begin
  if v_start is null then return false; end if;
  if now() < v_start then return false; end if;
  v_until := public.commercial_launch_free_until(p_owner_id);
  return now() < v_until;
end;
$$;
revoke execute on function public.is_commercial_launch_free_active(uuid)
  from public, anon;
grant execute on function public.is_commercial_launch_free_active(uuid)
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 3) Effective plan sırası: ödenmiş → aktif eski promo → ücretsiz ay → free.
--    is_commercial_launch_free_active yalnız commercial'da true olabildiği
--    için bireysel/toptancı türetimleri DEĞİŞMEZ (toptancı zaten
--    paid_business_plan yolunu kullanır).
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.current_business_plan(p_owner_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(e.plan, 'free') in ('premium', 'pro')
      and (e.current_period_ends_at is null or e.current_period_ends_at > now())
      then 'premium'
    when e.promo_status = 'active' and e.promo_expires_at > now()
      then 'premium'
    when public.is_commercial_launch_free_active(x.id)
      then 'premium'
    else 'free'
  end
  from (select p_owner_id as id) x
  left join public.user_entitlements e on e.owner_id = x.id;
$$;
revoke execute on function public.current_business_plan(uuid) from public, anon;
grant execute on function public.current_business_plan(uuid)
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 4) CTA promosu ticari hesapta YENİ aktivasyon vermez (mevcut durum
--    okunur, activated=false). Tedarikçi dalı 20260925 ile birebir aynı;
--    premium_promo_months anahtarına dokunulmaz; mevcut aktif promolar
--    yukarıdaki promo dalıyla korunur.
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.activate_launch_premium_promo()
returns table (
  promo_status text,
  promo_started_at timestamptz,
  promo_expires_at timestamptz,
  days_left integer,
  activated boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_acct text;
  v_months int;
  v_started timestamptz;
  v_expires timestamptz;
  v_status text;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  perform public.ensure_my_entitlement();

  select p.account_type into v_acct
  from public.profiles p where p.id = v_uid;
  if v_acct in ('wholesaler', 'commercial') then
    select coalesce(e.promo_status, 'not_started'),
           e.promo_started_at, e.promo_expires_at
      into v_status, v_started, v_expires
      from public.user_entitlements e
      where e.owner_id = v_uid;
    return query select
      coalesce(v_status, 'not_started'), v_started, v_expires,
      case when v_status = 'active' and v_expires > now()
        then ceil(extract(epoch from (v_expires - now())) / 86400.0)::int
        else 0 end,
      false;
    return;
  end if;

  v_months := public.app_config_int('premium_promo_months', 3);

  select e.promo_status, e.promo_started_at, e.promo_expires_at
  into v_status, v_started, v_expires
  from public.user_entitlements e
  where e.owner_id = v_uid
  for update;

  if v_status = 'active' and v_expires > now() then
    return query select
      v_status, v_started, v_expires,
      ceil(extract(epoch from (v_expires - now())) / 86400.0)::int,
      false;
    return;
  end if;

  if v_status in ('active', 'used') or v_started is not null then
    update public.user_entitlements e
      set promo_status = case
          when e.promo_expires_at is not null and e.promo_expires_at <= now()
          then 'expired' else e.promo_status end,
          updated_at = now()
      where e.owner_id = v_uid;
    select e.promo_status, e.promo_started_at, e.promo_expires_at
      into v_status, v_started, v_expires
      from public.user_entitlements e
      where e.owner_id = v_uid;
    return query select v_status, v_started, v_expires, 0, false;
    return;
  end if;

  v_started := now();
  v_expires := v_started + make_interval(months => v_months);

  update public.user_entitlements e
    set promo_status = 'active',
        promo_started_at = v_started,
        promo_expires_at = v_expires,
        source = 'system',
        updated_at = now()
    where e.owner_id = v_uid
      and e.promo_status = 'not_started'
      and e.promo_started_at is null;

  return query select
    'active'::text,
    v_started,
    v_expires,
    ceil(extract(epoch from (v_expires - now())) / 86400.0)::int,
    true;
end;
$$;
revoke execute on function public.activate_launch_premium_promo()
  from public, anon;
grant execute on function public.activate_launch_premium_promo()
  to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 5) my_entitlement: ticari lansman alanları (yalnız SONA ek kolon; eski
--    alanlar birebir korunur → eski uygulama uyumu).
-- ────────────────────────────────────────────────────────────────────────
drop function if exists public.my_entitlement();
create function public.my_entitlement()
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
  can_use_dealer_driver_ops boolean,
  supplier_effective_plan text,
  supplier_product_limit int,
  supplier_campaign_limit int,
  supplier_monthly_reply_limit int,
  supplier_can_add_product boolean,
  supplier_can_add_campaign boolean,
  supplier_can_reply_quote boolean,
  supplier_listing_fee_exempt boolean,
  promo_status text,
  promo_started_at timestamptz,
  promo_expires_at timestamptz,
  can_start_promo boolean,
  supplier_launch_free_active boolean,
  supplier_launch_free_until timestamptz,
  subscription_purchase_allowed boolean,
  free_period_active boolean,
  free_period_started_at timestamptz,
  free_period_ends_at timestamptz,
  free_period_days_left int,
  launch_price_until timestamptz
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
      e.promo_status,
      e.promo_started_at,
      e.promo_expires_at,
      p.account_type as acct
    from (select auth.uid() as id) x
    left join public.user_entitlements e on e.owner_id = x.id
    left join public.profiles p on p.id = x.id
  )
  select
    coalesce(me.actual, 'free'),
    me.eff,
    (me.promo_status = 'active' and me.promo_expires_at > now()),
    me.promo_started_at,
    me.promo_expires_at,
    case when me.promo_status = 'active' and me.promo_expires_at > now()
      then ceil(extract(epoch from (me.promo_expires_at - now())) / 86400.0)::int
      else 0 end,
    case me.eff when 'premium' then -1 else 5 end,
    case me.eff when 'premium' then -1 else 0 end,
    public.has_business_feature(auth.uid(), 'branches'),
    public.has_business_feature(auth.uid(), 'debt_expense'),
    public.has_business_feature(auth.uid(), 'dealer_driver_ops'),
    public.effective_supplier_plan(auth.uid()),
    public.supplier_product_limit(auth.uid()),
    public.supplier_campaign_limit(auth.uid()),
    public.supplier_monthly_reply_limit(auth.uid()),
    public.can_add_b2b_product(auth.uid()),
    public.can_add_b2b_campaign(auth.uid()),
    public.can_reply_b2b_quote(auth.uid()),
    (me.acct = 'wholesaler'
      and public.effective_supplier_plan(auth.uid()) = 'premium'),
    coalesce(me.promo_status, 'not_started'),
    me.promo_started_at,
    me.promo_expires_at,
    -- CTA promosu artık yalnız bireyselde "başlatılabilir" görünür (fiilen
    -- ticari/toptancı için kapalı; bireysel plan kullanmaz).
    coalesce(me.promo_status, 'not_started') = 'not_started'
      and me.promo_started_at is null
      and me.acct is distinct from 'wholesaler'
      and me.acct is distinct from 'commercial',
    public.is_supplier_launch_free_active(auth.uid()),
    case when me.acct = 'wholesaler'
      then public.supplier_launch_free_until() else null end,
    case
      when me.acct = 'commercial' then true
      when me.acct = 'wholesaler' then
        (not public.is_supplier_launch_free_active(auth.uid()))
        and public.app_config_bool('supplier_paid_packages_published', false)
      else false
    end,
    -- Ticari kayıt bazlı ücretsiz ay (diğer hesaplarda false/null).
    public.is_commercial_launch_free_active(auth.uid()),
    case when me.acct = 'commercial'
      then public.commercial_launch_free_start(auth.uid()) else null end,
    case when me.acct = 'commercial'
      then public.commercial_launch_free_until(auth.uid()) else null end,
    case when public.is_commercial_launch_free_active(auth.uid())
      then ceil(extract(epoch from
        (public.commercial_launch_free_until(auth.uid()) - now()))
        / 86400.0)::int
      else 0 end,
    case when me.acct = 'commercial'
      then public.commercial_launch_price_until() else null end
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 6) Pop-up görüldü kayıtları: ticari lansman bildirimleri de aynı
--    user_campaign_notices tablosunu kullanır (kullanıcı + kampanya +
--    bildirim türü bazında kalıcı). Client'ın yazabildiği anahtar seti
--    ticari pop-up türleriyle genişletilir; hatırlatma anahtarları yine
--    yalnız service_role'dedir.
-- ────────────────────────────────────────────────────────────────────────
drop policy if exists ucn_insert_own_ack on public.user_campaign_notices;
create policy ucn_insert_own_ack on public.user_campaign_notices
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and notice_key in ('popup_ack', 'welcome_ack', 'ending_ack', 'ended_ack')
  );
