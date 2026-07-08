-- Tedarikçi / Toptancı Ücretlendirme Server-side Foundation V1 (ADDITIVE).
--
-- Amaç: B2B tedarikçi (account_type='wholesaler') tarafında Free/Pro/Premium
-- limitlerini SERVER-SIDE kur. Paywall UI + ödeme YOK (sonraki PR/faz).
--
-- Model kararları (audit'ten):
--   * user_entitlements YENİDEN KULLANILIR (ayrı supplier_entitlements yok).
--     Kullanıcı tek account_type'a sahip → commercial XOR wholesaler; plan
--     tier'ı account_type'a göre yorumlanır, çakışma yok.
--   * Tedarikçi TRIAL = PRO-benzeri (Premium DEĞİL) — sınırsız ürün/kampanya/
--     cevap public marketplace'e yayılır → sınırsız trial spam riski.
--   * Limitler: ürün Free 1 / Pro 5 / Premium ∞ · kampanya Free 0 / Pro 3 /
--     Premium ∞ · teklif cevabı Free 3/ay / Pro 20/ay / Premium ∞.
--   * İlan ücreti: Free wholesaler 50 TL; Pro/Premium/trial wholesaler muaf.
--   * B2B ALICI/fırıncı tarafı ücretsiz — hiçbir gate eklenmez.
--
-- Commercial/bireysel davranışı DEĞİŞMEZ (ayrı effective_supplier_plan;
-- current_business_plan/has_business_feature/can_add_dealer/recipe aynen).
-- Mevcut b2b_request_accepts_reply hardening AND ile korunur.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. SUPPLIER EFFECTIVE PLAN — trial→PRO (commercial'dan farklı; ayrı helper)
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.effective_supplier_plan(p_owner_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_trial timestamptz;
begin
  select plan, trial_ends_at into v_plan, v_trial
  from public.user_entitlements where owner_id = p_owner_id;
  if v_plan is null then
    return 'free';
  end if;
  -- Tedarikçi trial'ı PRO gibi davranır (Premium değil — spam koruması).
  if v_trial is not null and v_trial > now() then
    return 'pro';
  end if;
  return v_plan;
end;
$$;
revoke execute on function public.effective_supplier_plan(uuid) from public, anon;
grant execute on function public.effective_supplier_plan(uuid) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 2. LIMIT HELPER'LARI (-1 = sınırsız)
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.supplier_product_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 when 'pro' then 5 else 1 end;
$$;
revoke execute on function public.supplier_product_limit(uuid) from public, anon;
grant execute on function public.supplier_product_limit(uuid) to authenticated;

create or replace function public.supplier_campaign_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 when 'pro' then 3 else 0 end;
$$;
revoke execute on function public.supplier_campaign_limit(uuid) from public, anon;
grant execute on function public.supplier_campaign_limit(uuid) to authenticated;

create or replace function public.supplier_monthly_reply_limit(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.effective_supplier_plan(p_owner_id)
    when 'premium' then -1 when 'pro' then 20 else 3 end;
$$;
revoke execute on function public.supplier_monthly_reply_limit(uuid)
  from public, anon;
grant execute on function public.supplier_monthly_reply_limit(uuid)
  to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 3. CAN-ADD HELPER'LARI (policy WITH CHECK içinde kullanılır)
-- ────────────────────────────────────────────────────────────────────────

-- Ürün: owner'ın mağazasındaki TÜM ürünler sayılır (published+draft).
create or replace function public.can_add_b2b_product(p_owner_id uuid)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare v_limit int; v_count int;
begin
  v_limit := public.supplier_product_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  select count(*) into v_count
  from public.b2b_products p
  join public.b2b_supplier_shops s on s.id = p.shop_id
  where s.owner_id = p_owner_id;
  return v_count < v_limit;
end;
$$;
revoke execute on function public.can_add_b2b_product(uuid) from public, anon;
grant execute on function public.can_add_b2b_product(uuid) to authenticated;

-- Kampanya: AKTİF kampanya sayılır (published + valid_until null/gelecek).
-- Süresi geçmiş/yayından kaldırılmış kampanya slotu boşaltır.
create or replace function public.can_add_b2b_campaign(p_owner_id uuid)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare v_limit int; v_count int; v_today date;
begin
  v_limit := public.supplier_campaign_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  if v_limit = 0 then return false; end if;
  v_today := (now() at time zone 'Europe/Istanbul')::date;
  select count(*) into v_count
  from public.b2b_campaigns c
  join public.b2b_supplier_shops s on s.id = c.shop_id
  where s.owner_id = p_owner_id
    and c.published = true
    and (c.valid_until is null or c.valid_until >= v_today);
  return v_count < v_limit;
end;
$$;
revoke execute on function public.can_add_b2b_campaign(uuid) from public, anon;
grant execute on function public.can_add_b2b_campaign(uuid) to authenticated;

-- Teklif cevabı: içinde bulunulan AY (Europe/Istanbul) cevap sayısı.
create or replace function public.can_reply_b2b_quote(p_owner_id uuid)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare v_limit int; v_count int; v_month_start timestamptz;
begin
  v_limit := public.supplier_monthly_reply_limit(p_owner_id);
  if v_limit < 0 then return true; end if;
  -- Yerel (İstanbul) ay başını timestamptz olarak hesapla.
  v_month_start := (
    date_trunc('month', (now() at time zone 'Europe/Istanbul'))
  ) at time zone 'Europe/Istanbul';
  select count(*) into v_count
  from public.b2b_quote_replies r
  join public.b2b_supplier_shops s on s.id = r.supplier_shop_id
  where s.owner_id = p_owner_id
    and r.created_at >= v_month_start;
  return v_count < v_limit;
end;
$$;
revoke execute on function public.can_reply_b2b_quote(uuid) from public, anon;
grant execute on function public.can_reply_b2b_quote(uuid) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 4. POLICY GATE'LERİ — INSERT WITH CHECK'e AND-le (hardening korunur)
--    SELECT/UPDATE/DELETE policy'lerine DOKUNULMAZ.
-- ────────────────────────────────────────────────────────────────────────

drop policy if exists b2b_products_insert on public.b2b_products;
create policy b2b_products_insert on public.b2b_products
  for insert to authenticated
  with check (
    (shop_id in (
      select b2b_supplier_shops.id from public.b2b_supplier_shops
      where b2b_supplier_shops.owner_id = auth.uid()))
    and public.can_add_b2b_product(auth.uid())
  );

drop policy if exists b2b_campaigns_insert on public.b2b_campaigns;
create policy b2b_campaigns_insert on public.b2b_campaigns
  for insert to authenticated
  with check (
    (shop_id in (
      select b2b_supplier_shops.id from public.b2b_supplier_shops
      where b2b_supplier_shops.owner_id = auth.uid()))
    and public.can_add_b2b_campaign(auth.uid())
  );

-- KRİTİK: b2b_request_accepts_reply hardening AND ile aynen korunur.
drop policy if exists b2b_replies_insert on public.b2b_quote_replies;
create policy b2b_replies_insert on public.b2b_quote_replies
  for insert to authenticated
  with check (
    (supplier_shop_id in (
      select b2b_supplier_shops.id from public.b2b_supplier_shops
      where b2b_supplier_shops.owner_id = auth.uid()))
    and public.b2b_request_accepts_reply(quote_request_id)
    and public.can_reply_b2b_quote(auth.uid())
  );

-- ────────────────────────────────────────────────────────────────────────
-- 5. İLAN ÜCRETİ MUAFİYETİ — wholesaler Pro/Premium/trial → 0
--    Commercial/bireysel kuralları AYNEN.
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.get_listing_fee_amount_cents(
  p_owner_id uuid, p_listing_type text)
returns integer language plpgsql stable security definer set search_path = ''
as $$
declare v_acct text;
begin
  if p_listing_type = 'job_seek' then return 0; end if;
  select account_type into v_acct from public.profiles where id = p_owner_id;
  if v_acct = 'commercial'
     and public.current_business_plan(p_owner_id) in ('pro', 'premium') then
    return 0;
  end if;
  -- YENİ: tedarikçi Pro/Premium (trial→pro) ilan muafiyeti.
  if v_acct = 'wholesaler'
     and public.effective_supplier_plan(p_owner_id) in ('pro', 'premium') then
    return 0;
  end if;
  return 5000;
end;
$$;
revoke execute on function public.get_listing_fee_amount_cents(uuid, text)
  from public, anon;
grant execute on function public.get_listing_fee_amount_cents(uuid, text)
  to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 6. ensure_my_entitlement — wholesaler'a da 30 gün trial.
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.ensure_my_entitlement()
returns void language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_acct text;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if exists (select 1 from public.user_entitlements where owner_id = v_uid) then
    return;
  end if;
  select account_type into v_acct from public.profiles where id = v_uid;
  if v_acct in ('commercial', 'wholesaler') then
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
-- 7. my_entitlement — supplier alanları eklenir (signature değişir → drop).
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
  supplier_listing_fee_exempt boolean
)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select
      public.current_business_plan(auth.uid()) as eff,
      e.plan as actual, e.trial_started_at, e.trial_ends_at,
      p.account_type as acct
    from (select auth.uid() as id) x
    left join public.user_entitlements e on e.owner_id = x.id
    left join public.profiles p on p.id = x.id
  )
  select
    coalesce(me.actual, 'free'),
    me.eff,
    (me.trial_ends_at is not null and me.trial_ends_at > now()),
    me.trial_started_at,
    me.trial_ends_at,
    case when me.trial_ends_at is not null and me.trial_ends_at > now()
      then ceil(extract(epoch from (me.trial_ends_at - now())) / 86400.0)::int
      else 0 end,
    case me.eff when 'premium' then -1 when 'pro' then 50 else 5 end,
    case me.eff when 'free' then 0 else -1 end,
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
      and public.effective_supplier_plan(auth.uid()) in ('pro', 'premium'))
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 8. BACKFILL — mevcut wholesaler'lara 30 gün trial (mevcut satır bozulmaz).
-- ────────────────────────────────────────────────────────────────────────

insert into public.user_entitlements
  (owner_id, plan, trial_started_at, trial_ends_at, source)
select p.id, 'free', now(), now() + interval '30 days', 'system'
from public.profiles p
where p.account_type = 'wholesaler'
on conflict (owner_id) do nothing;
