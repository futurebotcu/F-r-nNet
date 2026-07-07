-- Bayi Pro anlam düzeltmesi (Foundation V1 sonrası fix).
--
-- YANLIŞ (PR #92): can_add_dealer Pro'da "aktif bayi sayısı < 1" limiti
-- koyuyordu → Pro yalnız 1 bayi açabiliyordu.
--
-- DOĞRU ürün kararı:
--   * Free   : Bayi Defteri KAPALI (bayi oluşturamaz).
--   * Pro    : Bayi Defteri AÇIK, SAYI LİMİTİ YOK — patron/owner tek kullanıcı
--              olarak sınırsız bayi + tüm bayi işlemleri (hareket/tahsilat/
--              iade/fiyat/not). Şoför daveti/atama YOK.
--   * Premium: Pro + şoförlü/çok kullanıcılı bayi operasyonu.
--   * Trial  : Premium gibi.
--
-- Ayrım artık "bayi sayısı" DEĞİL, "şoförlü/çok kullanıcılı operasyon"dur
-- (dealer_driver_ops). Şoför gate'leri (create_driver_invite +
-- dealer_drivers_insert = Premium) AYNEN KALIR.
--
-- Bu migration yalnız iki fonksiyonu düzeltir; tablo/SELECT policy/veri
-- DEĞİŞMEZ. dealers_insert policy hâlâ can_add_dealer'ı çağırır — helper
-- düzeldiği için Pro artık geçer.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ── can_add_dealer: Pro sayı limiti kaldırıldı (Free hariç herkes true) ──
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
begin
  select account_type into v_acct from public.profiles where id = p_owner_id;
  -- Ticari olmayan (bireysel/toptancı) → pass-through (mevcut davranış).
  if v_acct is distinct from 'commercial' then
    return true;
  end if;
  v_plan := public.current_business_plan(p_owner_id);
  -- Free hariç: Pro da Premium/trial da bayi oluşturabilir (sayı limiti YOK).
  return v_plan in ('pro', 'premium');
end;
$$;
revoke execute on function public.can_add_dealer(uuid) from public, anon;
grant execute on function public.can_add_dealer(uuid) to authenticated;

-- ── my_entitlement: dealer_limit Pro 1 → -1 (sınırsız). Free 0 (kapalı).
--    Signature değişmez; yalnız CASE değeri düzeltilir. ──
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
    -- dealer_limit: Free 0 (kapalı) · Pro/Premium -1 (sınırsız). Ayrım
    -- şoförlü operasyonda (can_use_dealer_driver_ops).
    case me.eff when 'free' then 0 else -1 end,
    public.has_business_feature(auth.uid(), 'branches'),
    public.has_business_feature(auth.uid(), 'debt_expense'),
    public.has_business_feature(auth.uid(), 'dealer_driver_ops')
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;
