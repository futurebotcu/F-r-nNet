-- Tedarikçi Lansman Kampanyası V1 (ADDITIVE).
--
-- Yalnız TEDARİKÇİ/TOPTANCI (wholesaler) hesaplarını etkiler: ortak lansman
-- tarihinden itibaren 1 takvim yılı (Europe/Istanbul) tüm tedarikçi paket
-- limitleri kalkar (effective_supplier_plan = premium). Bireysel/ticari
-- hesapların paket, fiyat ve promo davranışına DOKUNULMAZ.
--
-- Tarih UYDURULMAZ: config anahtarları JSON null ile pasif başlar; kampanya
-- ancak backoffice/service_role app_runtime_config'e gerçek tarih yazınca
-- etkinleşir. Hak kontrolü tamamen server saatiyle (now()) yapılır — cihaz
-- saati değişikliği süreyi etkilemez.
--
-- Ödeme/otomatik abonelik YOK: kampanya hakkı store aboneliği gibi
-- KAYDEDİLMEZ; user_entitlements satırına yazılmaz, yalnız effective plan
-- türetiminde okunur. Kampanya bitince mevcut Free tedarikçi kuralları
-- kendiliğinden geri döner; veri silinmez, hesap kapanmaz.

-- ────────────────────────────────────────────────────────────────────────
-- 1) Merkezi kampanya konfigürasyonu (pasif başlar; operatör doldurur).
--    supplier_launch_free_until boşsa start + 1 takvim yılı (Istanbul).
-- ────────────────────────────────────────────────────────────────────────
insert into public.app_runtime_config (key, value) values
  ('supplier_launch_free_start', 'null'::jsonb),
  ('supplier_launch_free_until', 'null'::jsonb)
on conflict (key) do nothing;

create or replace function public.supplier_launch_free_start()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select public.app_config_timestamptz('supplier_launch_free_start', null);
$$;
revoke execute on function public.supplier_launch_free_start()
  from public, anon;
grant execute on function public.supplier_launch_free_start()
  to authenticated, service_role;

create or replace function public.supplier_launch_free_until()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    public.app_config_timestamptz('supplier_launch_free_until', null),
    ((public.app_config_timestamptz('supplier_launch_free_start', null)
        at time zone 'Europe/Istanbul') + interval '1 year')
      at time zone 'Europe/Istanbul'
  );
$$;
revoke execute on function public.supplier_launch_free_until()
  from public, anon;
grant execute on function public.supplier_launch_free_until()
  to authenticated, service_role;

-- Kampanya penceresi + rol kontrolü. Ortak bitiş: kayıt tarihinden bağımsız,
-- sonradan katılan da aynı bitişe kadar yararlanır.
create or replace function public.is_supplier_launch_free_active(
  p_owner_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := public.supplier_launch_free_start();
  v_until timestamptz := public.supplier_launch_free_until();
begin
  if v_until is null then return false; end if;
  if now() >= v_until then return false; end if;
  if v_start is not null and now() < v_start then return false; end if;
  return exists (
    select 1 from public.profiles p
    where p.id = p_owner_id and p.account_type = 'wholesaler'
  );
end;
$$;
revoke execute on function public.is_supplier_launch_free_active(uuid)
  from public, anon;
grant execute on function public.is_supplier_launch_free_active(uuid)
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 2) Mevcut hak mekanizmasını GENİŞLET (paralel sistem yok): tedarikçi
--    etkin planı kampanya boyunca premium. Ürün/kampanya/cevap limitleri ve
--    ilan muafiyeti zaten effective_supplier_plan üzerinden türediği için
--    tek noktadan açılır; RLS/guard'lar (anonimlik, reply hardening, tek
--    teklif kuralı) aynen yürürlükte kalır.
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.effective_supplier_plan(p_owner_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.is_supplier_launch_free_active(p_owner_id) then 'premium'
    else public.current_business_plan(p_owner_id)
  end;
$$;
revoke execute on function public.effective_supplier_plan(uuid)
  from public, anon;
grant execute on function public.effective_supplier_plan(uuid)
  to authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 3) my_entitlement: kampanya alanları (yalnız sona EK kolon — eski client
--    fazla kolonları yok sayar, davranış değişmez).
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
  supplier_launch_free_until timestamptz
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
    coalesce(me.promo_status, 'not_started') = 'not_started'
      and me.promo_started_at is null,
    public.is_supplier_launch_free_active(auth.uid()),
    case when me.acct = 'wholesaler'
      then public.supplier_launch_free_until() else null end
  from me;
$$;
revoke execute on function public.my_entitlement() from public, anon;
grant execute on function public.my_entitlement() to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- 4) Kampanya bilgilendirme kayıtları: pop-up görüldü işareti kullanıcı +
--    kampanya bazında KALICI (cihaz değişiminde tekrar açılmaz) ve
--    hatırlatma dedup'u aynı tabloda tutulur.
-- ────────────────────────────────────────────────────────────────────────
create table if not exists public.user_campaign_notices (
  user_id uuid not null references auth.users(id) on delete cascade,
  campaign_key text not null,
  notice_key text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, campaign_key, notice_key),
  constraint ucn_campaign_len_chk
    check (char_length(campaign_key) between 1 and 64),
  constraint ucn_notice_len_chk
    check (char_length(notice_key) between 1 and 64)
);

alter table public.user_campaign_notices enable row level security;

drop policy if exists ucn_select_own on public.user_campaign_notices;
create policy ucn_select_own on public.user_campaign_notices
  for select to authenticated
  using (user_id = auth.uid());

-- Client yalnız kendi pop-up onayını yazabilir; hatırlatma kayıtları
-- service_role/cron tarafından üretilir.
drop policy if exists ucn_insert_own_ack on public.user_campaign_notices;
create policy ucn_insert_own_ack on public.user_campaign_notices
  for insert to authenticated
  with check (user_id = auth.uid() and notice_key = 'popup_ack');

revoke all on public.user_campaign_notices from anon, public;
revoke update, delete, truncate, references, trigger
  on public.user_campaign_notices from authenticated;
grant select, insert on public.user_campaign_notices to authenticated;
grant select, insert, update, delete
  on public.user_campaign_notices to service_role;

-- ────────────────────────────────────────────────────────────────────────
-- 5) Hatırlatmalar: bitişten 30 ve 7 gün önce, mevcut bildirim altyapısına
--    (notifications tablosu → in-app zil + push dispatch trigger'ı) entegre.
--    * Aynı kullanıcıya aynı hatırlatma bir kez (notice dedup).
--    * Sonradan katılan yalnız GÜNCEL fazın hatırlatmasını alır; geçmiş
--      fazlar toplu gönderilmez (7 gün penceresi 30 günü gölgeler).
--    * Bildirim izni olmayan kullanıcı in-app bildirimden görür (push
--      dispatch best-effort'tur, in-app kayıt her durumda düşer).
--    * Metinde fiyat YOK (fiyat yayımlama ayrı ürün kararı).
-- ────────────────────────────────────────────────────────────────────────
create or replace function public.enqueue_supplier_launch_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := public.supplier_launch_free_start();
  v_until timestamptz := public.supplier_launch_free_until();
  v_notice text;
  v_title text;
  v_body text;
  v_date_label text;
  v_count int := 0;
  r record;
begin
  if v_until is null or now() >= v_until then return 0; end if;
  if v_start is not null and now() < v_start then return 0; end if;

  if now() >= v_until - interval '7 days' then
    v_notice := 'reminder_7d';
    v_title := 'Tedarikçi ücretsiz dönemi bitmek üzere';
  elsif now() >= v_until - interval '30 days' then
    v_notice := 'reminder_30d';
    v_title := 'Tedarikçi ücretsiz döneminde son 30 gün';
  else
    return 0;
  end if;

  v_date_label := to_char(
    v_until at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  v_body := 'Lansmana özel ücretsiz kullanım ' || v_date_label ||
    ' tarihinde sona eriyor. Dilerseniz size uygun paketi Paketler ' ||
    'ekranından inceleyip ücretli devam edebilirsiniz. Onayınız olmadan ' ||
    'ücret alınmaz veya abonelik başlatılmaz.';

  for r in
    select p.id
    from public.profiles p
    where p.account_type = 'wholesaler'
      and not exists (
        select 1 from public.user_campaign_notices n
        where n.user_id = p.id
          and n.campaign_key = 'supplier_launch_v1'
          and n.notice_key = v_notice
      )
  loop
    insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
    values (r.id, 'supplier_launch_v1', v_notice)
    on conflict do nothing;
    if found then
      insert into public.notifications
        (recipient_id, actor_id, type, title, body, route)
      values (r.id, null, 'supplier_launch_reminder', v_title, v_body,
              '/plans');
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;
revoke execute on function public.enqueue_supplier_launch_reminders()
  from public, anon, authenticated;
grant execute on function public.enqueue_supplier_launch_reminders()
  to service_role;

-- Günlük tetik (pg_cron kuruluysa; tarih yapılandırılmadıkça fonksiyon
-- no-op olduğundan zamanlamak güvenlidir).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job
               where jobname = 'supplier-launch-reminders') then
      perform cron.unschedule('supplier-launch-reminders');
    end if;
    perform cron.schedule(
      'supplier-launch-reminders',
      '23 8 * * *',
      'select public.enqueue_supplier_launch_reminders();'
    );
  end if;
end
$$;
