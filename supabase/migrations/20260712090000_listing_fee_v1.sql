-- İlan Ücretlendirme V1 (ADDITIVE).
--
-- Amaç: ücretli ilan kurallarını SERVER-SIDE güvenli kur. Ödeme entegrasyonu
-- YOK — ücretli ilan `fee_status='pending'` olur ve ödeme (service_role
-- mark_listing_fee_paid) yapılana kadar PUBLIC görünmez. Ücretsiz yayın
-- bypass'ı REST/RPC ile mümkün DEĞİL (fee alanları trigger'da set edilir,
-- client değerleri yok sayılır; public SELECT fee_status<>'pending' ister).
--
-- Fiyat V1: sabit 50 TL = 5000 kuruş, TRY.
-- Kural:
--   * job_seek_posts (iş arıyorum)          → HER ZAMAN ÜCRETSİZ (dokunulmaz).
--   * job_offer_posts (eleman arıyorum) +
--     market_listings (ekipman/devir)       → commercial + effective plan
--       pro/premium/trial ise 0; aksi (commercial free / bireysel / toptancı)
--       50 TL.
--   * Eski ilanlar grandfathered (public kalır, ödeme istenmez).
--
-- Ayrım "bayi sayısı" gibi değil; muafiyet YALNIZ ticari pro/premium/trial.
-- (Production'a MCP apply_migration ile uygulanır; repo mirror.)

-- ────────────────────────────────────────────────────────────────────────
-- 1. FEE KOLONLARI (yalnız ücretli olabilen 2 tablo; job_seek dokunulmaz)
-- ────────────────────────────────────────────────────────────────────────

do $$
declare
  t text;
begin
  foreach t in array array['job_offer_posts', 'market_listings'] loop
    execute format(
      'alter table public.%I
         add column if not exists fee_required boolean not null default false,
         add column if not exists fee_amount_cents integer not null default 0,
         add column if not exists fee_currency text not null default ''TRY'',
         add column if not exists fee_status text not null default ''not_required'',
         add column if not exists paid_at timestamptz,
         add column if not exists payment_reference text', t);
    -- fee_status CHECK (idempotent)
    execute format(
      'alter table public.%I drop constraint if exists %I', t, t || '_fee_status_chk');
    execute format(
      'alter table public.%I add constraint %I check (fee_status in
        (''not_required'',''pending'',''paid'',''waived'',''grandfathered''))',
      t, t || '_fee_status_chk');
  end loop;
end $$;

-- ────────────────────────────────────────────────────────────────────────
-- 2. FEE HELPER'LARI (SECURITY DEFINER, search_path='')
-- ────────────────────────────────────────────────────────────────────────

-- İlan yayın ücreti (kuruş). Muafiyet yalnız ticari pro/premium/trial.
create or replace function public.get_listing_fee_amount_cents(
  p_owner_id uuid,
  p_listing_type text
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acct text;
begin
  -- İş arama ilanı her zaman ücretsiz.
  if p_listing_type = 'job_seek' then
    return 0;
  end if;
  select account_type into v_acct from public.profiles where id = p_owner_id;
  -- Ticari + etkin plan pro/premium (trial→premium) → muaf.
  if v_acct = 'commercial'
     and public.current_business_plan(p_owner_id) in ('pro', 'premium') then
    return 0;
  end if;
  -- Diğer tüm ücretli ilan türleri (commercial free / bireysel ekipman-devir /
  -- toptancı) → 50 TL. Bilinmeyen tür de güvenli tarafta ücretli sayılır.
  return 5000;
end;
$$;
revoke execute on function public.get_listing_fee_amount_cents(uuid, text)
  from public, anon;
grant execute on function public.get_listing_fee_amount_cents(uuid, text)
  to authenticated;

create or replace function public.is_listing_fee_required(
  p_owner_id uuid,
  p_listing_type text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.get_listing_fee_amount_cents(p_owner_id, p_listing_type) > 0;
$$;
revoke execute on function public.is_listing_fee_required(uuid, text)
  from public, anon;
grant execute on function public.is_listing_fee_required(uuid, text)
  to authenticated;

create or replace function public.can_publish_listing_without_payment(
  p_owner_id uuid,
  p_listing_type text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.get_listing_fee_amount_cents(p_owner_id, p_listing_type) = 0;
$$;
revoke execute on function public.can_publish_listing_without_payment(uuid, text)
  from public, anon;
grant execute on function public.can_publish_listing_without_payment(uuid, text)
  to authenticated;

-- Çağıranın belirli tür için ücreti (UI bilgilendirme). Güvenli alan.
create or replace function public.my_listing_fee(p_listing_type text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select public.get_listing_fee_amount_cents(auth.uid(), p_listing_type);
$$;
revoke execute on function public.my_listing_fee(text) from public, anon;
grant execute on function public.my_listing_fee(text) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 3. NORMALIZE TRIGGER — client fee/publish bypass'ını kapatır
--    INSERT: fee owner planına göre hesaplanır, client fee_* yok sayılır.
--    UPDATE: fee alanları OLD'a dondurulur (client self-pay edemez).
--    Admin bypass: mark_listing_fee_paid GUC bayrağıyla atlar.
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.normalize_listing_fee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
  v_fee int;
begin
  -- Backoffice/service ödeme yolu → normalizasyonu atla.
  if current_setting('app.listing_fee_admin', true) = 'on' then
    return new;
  end if;

  v_kind := case tg_table_name
    when 'job_offer_posts' then 'job_offer'
    when 'market_listings' then 'market'
    else 'market'
  end;

  if tg_op = 'INSERT' then
    v_fee := public.get_listing_fee_amount_cents(new.owner_id, v_kind);
    new.fee_currency := 'TRY';
    new.paid_at := null;
    new.payment_reference := null;
    if v_fee = 0 then
      new.fee_required := false;
      new.fee_amount_cents := 0;
      new.fee_status := 'not_required';
    else
      new.fee_required := true;
      new.fee_amount_cents := v_fee;
      new.fee_status := 'pending';
    end if;
    return new;
  end if;

  -- UPDATE: fee alanlarını dondur (client hiçbir fee alanını değiştiremez).
  new.fee_required := old.fee_required;
  new.fee_amount_cents := old.fee_amount_cents;
  new.fee_currency := old.fee_currency;
  new.fee_status := old.fee_status;
  new.paid_at := old.paid_at;
  new.payment_reference := old.payment_reference;
  return new;
end;
$$;

-- Trigger fonksiyonu doğrudan çağrılmamalı (yalnız trigger bağlamında).
revoke execute on function public.normalize_listing_fee()
  from public, anon, authenticated;

drop trigger if exists trg_normalize_listing_fee on public.job_offer_posts;
create trigger trg_normalize_listing_fee
before insert or update on public.job_offer_posts
for each row execute function public.normalize_listing_fee();

drop trigger if exists trg_normalize_listing_fee on public.market_listings;
create trigger trg_normalize_listing_fee
before insert or update on public.market_listings
for each row execute function public.normalize_listing_fee();

-- ────────────────────────────────────────────────────────────────────────
-- 4. PUBLIC SELECT GATE — ödenmeyen (pending) ilan public görünmez.
--    owner kendi pending ilanını görür (ödeme bekliyor). SELECT-only
--    genişletme; yazma/silme policy'lerine dokunulmaz.
-- ────────────────────────────────────────────────────────────────────────

drop policy if exists job_offer_posts_select_active_or_own
  on public.job_offer_posts;
create policy job_offer_posts_select_active_or_own on public.job_offer_posts
  for select
  using (
    ((is_active = true) and (fee_status <> 'pending'))
    or (owner_id = auth.uid())
  );

drop policy if exists market_listings_select_active_or_own
  on public.market_listings;
create policy market_listings_select_active_or_own on public.market_listings
  for select
  using (
    ((status = 'active') and (is_deleted = false) and (fee_status <> 'pending'))
    or (owner_id = auth.uid())
  );

-- ────────────────────────────────────────────────────────────────────────
-- 5. mark_listing_fee_paid — YALNIZ service_role/backoffice.
--    Ödemeyi onaylar (pending → paid), ilan public'e çıkar.
-- ────────────────────────────────────────────────────────────────────────

create or replace function public.mark_listing_fee_paid(
  p_listing_id uuid,
  p_payment_reference text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done int := 0;
begin
  perform set_config('app.listing_fee_admin', 'on', true);
  update public.job_offer_posts
    set fee_status = 'paid', paid_at = now(),
        payment_reference = nullif(p_payment_reference, '')
    where id = p_listing_id and fee_status = 'pending';
  get diagnostics v_done = row_count;
  if v_done = 0 then
    update public.market_listings
      set fee_status = 'paid', paid_at = now(),
          payment_reference = nullif(p_payment_reference, '')
      where id = p_listing_id and fee_status = 'pending';
    get diagnostics v_done = row_count;
  end if;
  perform set_config('app.listing_fee_admin', 'off', true);
  return v_done > 0;
end;
$$;
-- Client (authenticated/anon) ÇAĞIRAMAZ → self-pay imkânsız.
revoke execute on function public.mark_listing_fee_paid(uuid, text)
  from public, anon, authenticated;
grant execute on function public.mark_listing_fee_paid(uuid, text)
  to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 6. BACKFILL — mevcut ilanlar grandfathered (public kalır, ücret istenmez).
--    is_active/status/is_deleted DEĞİŞMEZ. Admin GUC ile trigger normalizasyonu
--    atlanır (aksi halde UPDATE trigger'ı fee_status'u OLD'a dondurur).
-- ────────────────────────────────────────────────────────────────────────

select set_config('app.listing_fee_admin', 'on', true);

update public.job_offer_posts
  set fee_status = 'grandfathered', fee_required = false,
      fee_amount_cents = 0, fee_currency = 'TRY'
  where fee_status = 'not_required';

update public.market_listings
  set fee_status = 'grandfathered', fee_required = false,
      fee_amount_cents = 0, fee_currency = 'TRY'
  where fee_status = 'not_required';

select set_config('app.listing_fee_admin', 'off', true);
