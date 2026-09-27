-- =============================================================================
-- Bireysel Lansman Bilgilendirmesi — V1
-- =============================================================================
-- Bireysel (individual) hesaplarda 30 Eylül 2027 günü sonuna kadar (sunucu
-- sınırı 2027-10-01T00:00:00+03:00, bu an HARİÇ) hiçbir ücretli özellik veya
-- satın alma yoktur. Bu migration YENİ bir kilit/ücret AÇMAZ:
--   - subscription_purchase_allowed bireysel için zaten her koşulda false
--     (my_entitlement else dalı) — davranış AYNEN korunur.
--   - İlan ücreti fonksiyonları hesap türünden bağımsız config'e bağlıdır ve
--     lansmanda kapalıdır (listing_payments_enabled=false).
-- Eklenenler: tek kaynak bitiş tarihi (config), my_entitlement'a SONA ek
-- individual_free_until kolonu (eski alanlar birebir korunur) ve bilgilendirme
-- pop-up'ının görüldü kaydı için mevcut user_campaign_notices deseni.
--
-- NOT (ack/policy): ucn_insert_own_ack policy'si notice_key bazlıdır ve
-- 'popup_ack' zaten izinlidir; campaign_key kısıtlamaz. Bireysel pop-up
-- campaign_key='individual_launch_v1', notice_key='popup_ack' kullanır →
-- YENİ policy değişikliği GEREKMEZ (testle kanıtlanır).

-- 1) Tek kaynak bitiş tarihi. on conflict do nothing → mevcut değer korunur.
insert into public.app_runtime_config (key, value) values
  ('individual_launch_free_until', '"2027-10-01T00:00:00+03:00"'::jsonb)
on conflict (key) do nothing;

-- 2) Config okuyucu (tedarikçi/ticari sarmalayıcılarla aynı desen).
create or replace function public.individual_launch_free_until()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select public.app_config_timestamptz('individual_launch_free_until', null);
$$;
revoke execute on function public.individual_launch_free_until()
  from public, anon;
grant execute on function public.individual_launch_free_until()
  to authenticated, service_role;

-- 3) my_entitlement: bireysel için individual_free_until (yalnız SONA ek
--    kolon; eski alanlar ve sıraları BİREBİR korunur → eski sürüm uyumu).
--    subscription_purchase_allowed hesabı DEĞİŞMEDİ: bireysel her koşulda
--    false (ödeme servisi de satın alma çağrısından önce bunu okur).
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
  launch_price_until timestamptz,
  individual_free_until timestamptz
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
      then public.commercial_launch_price_until() else null end,
    -- Bireysel ücretsiz dönem bitişi (yalnız bireyselde dolu; profil yoksa
    -- misafir=bireysel varsayımıyla da dolu). İş hesaplarında null.
    case when me.acct is distinct from 'commercial'
          and me.acct is distinct from 'wholesaler'
      then public.individual_launch_free_until() else null end
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;
