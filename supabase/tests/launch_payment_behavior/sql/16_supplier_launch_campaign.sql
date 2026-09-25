-- Tedarikçi Lansman Kampanyası davranış testleri.
-- u9 = wholesaler, u1/u5 = commercial, u10 = individual (şema seed'inde).
-- Kampanya penceresi tamamen server-side config + now() ile hesaplanır;
-- fonksiyonlar client'tan zaman parametresi ALMAZ (S4 bunu kontrat olarak
-- doğrular) — cihaz saati değişikliği hakkı etkileyemez.
--
-- KESİN KURAL: bitiş SABİT config değeridir (2027-10-01T00:00:00+03:00,
-- bu an hariç); start+1yıl türetimi YOKTUR; başlangıç tanımsızken kampanya
-- ve hatırlatmalar pasiftir; tedarikçi kişisel promo başlatamaz ve mevcut
-- aktif promo tedarikçi haklarını açmaz; ödenmiş abonelik korunur.

-- S1) Seed durumu: start null, until SABİT 2027 bitişi → kampanya pasif;
-- free limitler geçerli.
do $$
declare
  v_u9 uuid := '00000000-0000-4000-8000-000000000009';
  v_until timestamptz := public.supplier_launch_free_until();
begin
  if v_until is distinct from '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'S1a: sabit bitiş yanlış: %', v_until;
  end if;
  if public.supplier_launch_free_start() is not null then
    raise exception 'S1b: start seed''i null değil';
  end if;
  if public.is_supplier_launch_free_active(v_u9) then
    raise exception 'S1c: start tanımsızken kampanya aktif';
  end if;
  if public.effective_supplier_plan(v_u9) <> 'free'
     or public.supplier_product_limit(v_u9) <> 1
     or public.supplier_campaign_limit(v_u9) <> 0
     or public.supplier_monthly_reply_limit(v_u9) <> 3 then
    raise exception 'S1d: pasif kampanyada free limitler bozuk';
  end if;
  raise notice 'PASS 16-S1 sabit bitiş + start''sız pasif';
end
$$;

-- S2) Başlangıç gelecekte → yine pasif; bitiş start'tan BAĞIMSIZ sabit
-- kalır (türetim yok).
update public.app_runtime_config
  set value = to_jsonb((now() + interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';

do $$
declare
  v_u9 uuid := '00000000-0000-4000-8000-000000000009';
begin
  if public.supplier_launch_free_until()
     is distinct from '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'S2a: bitiş start''a bağlı değişti (türetim var!)';
  end if;
  if public.is_supplier_launch_free_active(v_u9) then
    raise exception 'S2b: başlangıç öncesi kampanya aktif';
  end if;
  raise notice 'PASS 16-S2 başlangıç öncesi pasif + bitiş sabit';
end
$$;

-- S3) Kampanya açık: yalnız wholesaler premium'a yükselir; ticari/bireysel
-- ve base plan ETKİLENMEZ. Sonradan katılan aynı ortak bitişi kullanır.
update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';

do $$
begin
  insert into auth.users (id)
  values ('00000000-0000-4000-8000-000000000011')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type)
    values ('00000000-0000-4000-8000-000000000011', 'Toptancı Onbir',
            'wholesaler')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type)
    values ('00000000-0000-4000-8000-000000000011', 'wholesaler')
    on conflict do nothing;
  end;
end
$$;

do $$
declare
  v_u9 uuid := '00000000-0000-4000-8000-000000000009';
  v_u11 uuid := '00000000-0000-4000-8000-000000000011';
  v_u1 uuid := '00000000-0000-4000-8000-000000000001';
  v_u10 uuid := '00000000-0000-4000-8000-000000000010';
begin
  if not public.is_supplier_launch_free_active(v_u9) then
    raise exception 'S3a: kampanya penceresinde wholesaler aktif değil';
  end if;
  if public.effective_supplier_plan(v_u9) <> 'premium'
     or public.supplier_product_limit(v_u9) <> -1
     or public.supplier_campaign_limit(v_u9) <> -1
     or public.supplier_monthly_reply_limit(v_u9) <> -1 then
    raise exception 'S3b: kampanyada tedarikçi limitleri kalkmadı';
  end if;
  -- Base plan/entitlement satırına YAZILMAZ (mağaza aboneliği gibi
  -- kaydedilmez): current_business_plan hâlâ free.
  if public.current_business_plan(v_u9) <> 'free' then
    raise exception 'S3c: kampanya base planı değiştirdi';
  end if;
  -- Diğer roller etkilenmez.
  if public.is_supplier_launch_free_active(v_u1)
     or public.is_supplier_launch_free_active(v_u10) then
    raise exception 'S3d: kampanya wholesaler dışına taştı';
  end if;
  -- u5: promosu süresi dolmuş TEMİZ ticari hesap (u1 önceki testlerde
  -- gerçek abonelikle premium oldu — kampanyayla ilgisi yok).
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000005') <> 'free'
     or public.has_business_feature(
       '00000000-0000-4000-8000-000000000005', 'branches') then
    raise exception 'S3e: ticari hesap davranışı değişti';
  end if;
  -- Sonradan katılan (u11) ortak bitişe kadar yararlanır (kayıt tarihinden
  -- bağımsız — tek global pencere).
  if not public.is_supplier_launch_free_active(v_u11)
     or public.effective_supplier_plan(v_u11) <> 'premium' then
    raise exception 'S3f: sonradan katılan wholesaler yararlanamıyor';
  end if;
  raise notice 'PASS 16-S3 rol izolasyonu + ortak bitiş + limitler';
end
$$;

-- my_entitlement kampanya + satın alma uygunluğu alanları.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
set local role authenticated;
do $$
declare r record;
begin
  select supplier_launch_free_active, supplier_launch_free_until,
         supplier_effective_plan, can_start_promo,
         subscription_purchase_allowed
  into r from public.my_entitlement();
  if r.supplier_launch_free_active is distinct from true
     or r.supplier_launch_free_until is distinct from
        '2027-10-01T00:00:00+03:00'::timestamptz
     or r.supplier_effective_plan <> 'premium' then
    raise exception 'S3g: my_entitlement kampanya alanları yanlış: %', r;
  end if;
  -- Tedarikçi: promo başlatamaz; kampanyada satın alma kapalı.
  if r.can_start_promo or r.subscription_purchase_allowed then
    raise exception 'S3g2: tedarikçi promo/satın alma açık görünüyor: %', r;
  end if;
end
$$;
commit;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
set local role authenticated;
do $$
declare r record;
begin
  select supplier_launch_free_active, supplier_launch_free_until,
         subscription_purchase_allowed
  into r from public.my_entitlement();
  if r.supplier_launch_free_active
     or r.supplier_launch_free_until is not null then
    raise exception 'S3h: commercial my_entitlement kampanya gösteriyor: %', r;
  end if;
  -- Ticari satın alma serbest kalır.
  if not r.subscription_purchase_allowed then
    raise exception 'S3h2: commercial satın alma kapandı';
  end if;
  raise notice 'PASS 16-S3g/h my_entitlement alanları + satın alma uygunluğu';
end
$$;
commit;

-- S4) Kontrat: hak fonksiyonları client'tan zaman/parametre almaz — süre
-- yalnız server config + now() (cihaz saati etkisiz).
do $$
begin
  if (select pronargs from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'is_supplier_launch_free_active') <> 1 then
    raise exception 'S4a: is_supplier_launch_free_active imzası değişmiş';
  end if;
  if (select pronargs from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'supplier_launch_free_until') <> 0 then
    raise exception 'S4b: supplier_launch_free_until parametre almamalı';
  end if;
  raise notice 'PASS 16-S4 server-saat kontratı';
end
$$;

-- S4b) İstanbul saat sınırı: bitiş anı HARİÇTİR (until == now → kapalı).
update public.app_runtime_config
  set value = to_jsonb(now()::text), updated_at = now()
  where key = 'supplier_launch_free_until';
do $$
begin
  if public.is_supplier_launch_free_active(
       '00000000-0000-4000-8000-000000000009') then
    raise exception 'S4c: bitiş anında erişim hâlâ açık (sınır dahil olmuş)';
  end if;
  raise notice 'PASS 16-S4b bitiş anı hariç';
end
$$;

-- S5) Bitiş sonrası: erişim kapanır, free kurallar geri döner; otomatik
-- ücret/abonelik OLUŞMAZ.
update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 second')::text), updated_at = now()
  where key = 'supplier_launch_free_until';

do $$
declare
  v_u9 uuid := '00000000-0000-4000-8000-000000000009';
begin
  if public.is_supplier_launch_free_active(v_u9) then
    raise exception 'S5a: bitiş sonrası kampanya hâlâ aktif';
  end if;
  if public.effective_supplier_plan(v_u9) <> 'free'
     or public.supplier_product_limit(v_u9) <> 1
     or public.supplier_campaign_limit(v_u9) <> 0
     or public.supplier_monthly_reply_limit(v_u9) <> 3 then
    raise exception 'S5b: bitiş sonrası free limitler dönmedi';
  end if;
  if exists (select 1 from public.store_subscription_transactions
             where user_id = v_u9)
     or exists (select 1 from public.user_entitlements
                where owner_id = v_u9 and plan <> 'free') then
    raise exception 'S5c: kampanya ücretli abonelik/ödeme kaydı üretti';
  end if;
  raise notice 'PASS 16-S5 bitişte erişim kapanır, otomatik ücret yok';
end
$$;

-- S8) Promo ve ödenmiş abonelik kuralları (kampanya bitmişken).
-- S8a: tedarikçi kişisel promo BAŞLATAMAZ.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
set local role authenticated;
do $$
declare r record;
begin
  select * into r from public.activate_launch_premium_promo();
  if r.activated then
    raise exception 'S8a: tedarikçi promo başlatabildi';
  end if;
  if r.promo_status <> 'not_started' then
    raise exception 'S8a2: tedarikçi promo durumu bozuldu: %', r.promo_status;
  end if;
end
$$;
commit;

do $$
begin
  if exists (select 1 from public.user_entitlements
             where owner_id = '00000000-0000-4000-8000-000000000009'
               and (promo_status <> 'not_started'
                    or promo_started_at is not null)) then
    raise exception 'S8a3: tedarikçi promo alanları yazıldı';
  end if;
  raise notice 'PASS 16-S8a tedarikçi promo başlatma engeli';
end
$$;

-- S8b: ticari hesap promo davranışı DEĞİŞMEDİ (taze ticari u13 başlatır).
do $$
begin
  insert into auth.users (id)
  values ('00000000-0000-4000-8000-000000000013')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type)
    values ('00000000-0000-4000-8000-000000000013', 'Ticari Onüç',
            'commercial')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type)
    values ('00000000-0000-4000-8000-000000000013', 'commercial')
    on conflict do nothing;
  end;
end
$$;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
set local role authenticated;
do $$
declare r record;
begin
  select * into r from public.activate_launch_premium_promo();
  if r.activated is distinct from true or r.promo_status <> 'active' then
    raise exception 'S8b: ticari promo başlatılamadı: %', r;
  end if;
  raise notice 'PASS 16-S8b ticari promo korunuyor';
end
$$;
commit;

-- S8c: MEVCUT AKTİF kişisel promo tedarikçi haklarını AÇMAZ (ortak bitişi
-- uzatamaz); aynı promo ticari hesapta premium açmaya devam eder.
set role service_role;
update public.user_entitlements
  set promo_status = 'active',
      promo_started_at = now() - interval '1 day',
      promo_expires_at = now() + interval '60 days'
  where owner_id = '00000000-0000-4000-8000-000000000009';
reset role;

do $$
begin
  -- Kampanya bitmiş + tedarikçide aktif kişisel promo → yine FREE.
  if public.effective_supplier_plan(
       '00000000-0000-4000-8000-000000000009') <> 'free'
     or public.supplier_product_limit(
       '00000000-0000-4000-8000-000000000009') <> 1 then
    raise exception 'S8c: aktif promo tedarikçi haklarını açtı (uzatma!)';
  end if;
  -- Aynı mekanizma ticaride çalışmaya devam eder (u13 promo aktif).
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000013') <> 'premium' then
    raise exception 'S8c2: ticari promo etkisi bozuldu';
  end if;
  raise notice 'PASS 16-S8c promo ortak bitişi uzatamaz';
end
$$;

set role service_role;
update public.user_entitlements
  set promo_status = 'not_started',
      promo_started_at = null,
      promo_expires_at = null
  where owner_id = '00000000-0000-4000-8000-000000000009';
reset role;

-- S8d: GEÇERLİ ÖDENMİŞ abonelik kampanyadan bağımsız korunur.
set role service_role;
update public.user_entitlements
  set plan = 'premium', source = 'iap',
      current_period_started_at = now() - interval '1 day',
      current_period_ends_at = now() + interval '30 days'
  where owner_id = '00000000-0000-4000-8000-000000000009';
reset role;

do $$
begin
  if public.effective_supplier_plan(
       '00000000-0000-4000-8000-000000000009') <> 'premium'
     or public.supplier_product_limit(
       '00000000-0000-4000-8000-000000000009') <> -1 then
    raise exception 'S8d: ödenmiş tedarikçi aboneliği korunmadı';
  end if;
  raise notice 'PASS 16-S8d ödenmiş abonelik korunur';
end
$$;

set role service_role;
update public.user_entitlements
  set plan = 'free', source = 'system',
      current_period_started_at = null, current_period_ends_at = null
  where owner_id = '00000000-0000-4000-8000-000000000009';
reset role;

-- S8e: paketler yayımlanınca (kampanya dışı) tedarikçi satın alma açılır.
update public.app_runtime_config
  set value = 'true'::jsonb, updated_at = now()
  where key = 'supplier_paid_packages_published';

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
set local role authenticated;
do $$
declare r record;
begin
  select subscription_purchase_allowed into r from public.my_entitlement();
  if not r.subscription_purchase_allowed then
    raise exception 'S8e: paket yayımlandı ama satın alma kapalı';
  end if;
  raise notice 'PASS 16-S8e yayımlanınca satın alma açılır';
end
$$;
commit;

update public.app_runtime_config
  set value = 'false'::jsonb, updated_at = now()
  where key = 'supplier_paid_packages_published';

-- S6) Hatırlatmalar: 30g ve 7g fazları, dedup, geç katılana geçmiş faz yok.
set role service_role;

-- Faz dışı (kampanya bitmiş) → 0.
do $$
begin
  if public.enqueue_supplier_launch_reminders() <> 0 then
    raise exception 'S6a: kampanya bitmişken hatırlatma üretildi';
  end if;
end
$$;

-- Start tanımsızken de hatırlatma üretilmez.
reset role;
update public.app_runtime_config
  set value = 'null'::jsonb, updated_at = now()
  where key = 'supplier_launch_free_start';
update public.app_runtime_config
  set value = to_jsonb((now() + interval '20 days')::text), updated_at = now()
  where key = 'supplier_launch_free_until';
set role service_role;
do $$
begin
  if public.enqueue_supplier_launch_reminders() <> 0 then
    raise exception 'S6a2: start tanımsızken hatırlatma üretildi';
  end if;
end
$$;

-- 30 gün penceresi (start geçmiş, until = now()+20g).
reset role;
update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';
set role service_role;

do $$
declare v_count int;
begin
  v_count := public.enqueue_supplier_launch_reminders();
  if v_count < 2 then
    raise exception 'S6b: 30g fazında beklenen hatırlatma yok (%)', v_count;
  end if;
  if not exists (select 1 from public.user_campaign_notices
      where user_id = '00000000-0000-4000-8000-000000000009'
        and notice_key = 'reminder_30d')
     or not exists (select 1 from public.notifications
      where recipient_id = '00000000-0000-4000-8000-000000000009'
        and type = 'supplier_launch_reminder') then
    raise exception 'S6c: wholesaler 30g bildirimi almadı';
  end if;
  -- Yalnız wholesaler alır.
  if exists (select 1 from public.notifications
      where recipient_id in ('00000000-0000-4000-8000-000000000001',
                             '00000000-0000-4000-8000-000000000010',
                             '00000000-0000-4000-8000-000000000013')
        and type = 'supplier_launch_reminder') then
    raise exception 'S6d: wholesaler dışı hesaba hatırlatma gitti';
  end if;
  -- Metin son ücretsiz GÜNÜ söyler ("günü sonunda") ve fiyat içermez.
  if exists (select 1 from public.notifications
      where type = 'supplier_launch_reminder'
        and (body not like '%günü sonunda%' or body like '%TL%')) then
    raise exception 'S6d2: hatırlatma metni bitiş/fiyat kuralına aykırı';
  end if;
  -- Tekrar koşum → yinelenmez.
  if public.enqueue_supplier_launch_reminders() <> 0 then
    raise exception 'S6e: 30g hatırlatması yinelendi';
  end if;
  raise notice 'PASS 16-S6b-e 30g fazı + dedup + rol izolasyonu';
end
$$;

-- 7 gün penceresi (until = now()+5g) + geç katılan yalnız güncel fazı alır.
reset role;
update public.app_runtime_config
  set value = to_jsonb((now() + interval '5 days')::text), updated_at = now()
  where key = 'supplier_launch_free_until';

do $$
begin
  insert into auth.users (id)
  values ('00000000-0000-4000-8000-000000000012')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type)
    values ('00000000-0000-4000-8000-000000000012', 'Toptancı Oniki',
            'wholesaler')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type)
    values ('00000000-0000-4000-8000-000000000012', 'wholesaler')
    on conflict do nothing;
  end;
end
$$;
set role service_role;

do $$
declare v_count int;
begin
  v_count := public.enqueue_supplier_launch_reminders();
  if v_count < 3 then
    raise exception 'S6f: 7g fazında beklenen hatırlatma yok (%)', v_count;
  end if;
  -- Geç katılan (u12) yalnız 7g alır; 30g toplu gönderilmez.
  if not exists (select 1 from public.user_campaign_notices
      where user_id = '00000000-0000-4000-8000-000000000012'
        and notice_key = 'reminder_7d')
     or exists (select 1 from public.user_campaign_notices
      where user_id = '00000000-0000-4000-8000-000000000012'
        and notice_key = 'reminder_30d') then
    raise exception 'S6g: geç katılan yanlış fazları aldı';
  end if;
  if public.enqueue_supplier_launch_reminders() <> 0 then
    raise exception 'S6h: 7g hatırlatması yinelendi';
  end if;
  -- Kullanıcı başına her fazdan en fazla bir kayıt.
  if exists (
    select 1 from public.user_campaign_notices
    group by user_id, campaign_key, notice_key having count(*) > 1) then
    raise exception 'S6i: notice dedup bozuk';
  end if;
  raise notice 'PASS 16-S6f-i 7g fazı + geç katılan + dedup';
end
$$;
reset role;

-- S7) Pop-up görüldü kaydı: yalnız kendi popup_ack'i; hatırlatma anahtarı
-- ve başkası adına yazma RLS ile reddedilir.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
set local role authenticated;
do $$
begin
  insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
  values ('00000000-0000-4000-8000-000000000009', 'supplier_launch_v1',
          'popup_ack')
  on conflict do nothing;
  -- Idempotent tekrar (cihaz değişimi senaryosu) → hata yok, ikinci satır yok.
  insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
  values ('00000000-0000-4000-8000-000000000009', 'supplier_launch_v1',
          'popup_ack')
  on conflict do nothing;
  if (select count(*) from public.user_campaign_notices
      where user_id = '00000000-0000-4000-8000-000000000009'
        and notice_key = 'popup_ack') <> 1 then
    raise exception 'S7a: popup_ack tekil değil';
  end if;

  begin
    insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
    values ('00000000-0000-4000-8000-000000000001', 'supplier_launch_v1',
            'popup_ack');
    raise exception 'S7b: başkası adına ack yazılabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
    values ('00000000-0000-4000-8000-000000000009', 'supplier_launch_v1',
            'reminder_30d');
    raise exception 'S7c: client hatırlatma kaydı yazabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 16-S7 popup ack RLS';
end
$$;
commit;

-- Temizlik: kampanya config'ini seed durumuna döndür (start tanımsız,
-- bitiş sabit) — sonraki testler etkilenmesin.
update public.app_runtime_config
  set value = 'null'::jsonb, updated_at = now()
  where key = 'supplier_launch_free_start';
update public.app_runtime_config
  set value = '"2027-10-01T00:00:00+03:00"'::jsonb, updated_at = now()
  where key = 'supplier_launch_free_until';
update public.app_runtime_config
  set value = 'false'::jsonb, updated_at = now()
  where key = 'supplier_paid_packages_published';
