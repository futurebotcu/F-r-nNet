-- Ticari Lansman Modeli davranış testleri.
-- Durum mirası: u1 = ödenmiş premium (test 10), u5 = süresi dolmuş promo
-- (test 13), u13 = AKTİF promo (test 16'da manuel set), u9 = wholesaler,
-- u10 = individual. u5/u13 şema yüklenirken (dakikalar önce) oluştu →
-- "kayıt lansmandan sonra" örnekleri.

-- C1) commercial_launch_start null (seed) → dal pasif; mevcut davranış
-- birebir: ödenmiş premium ve aktif promo premium, diğer ticari free.
do $$
declare
  v_u5 uuid := '00000000-0000-4000-8000-000000000005';
begin
  if (select value from public.app_runtime_config
      where key = 'commercial_launch_start') <> 'null'::jsonb then
    raise exception 'C1a: commercial_launch_start seed''i null değil';
  end if;
  if public.commercial_launch_price_until()
     is distinct from '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'C1b: lansman fiyat bitişi sabit değil';
  end if;
  if public.is_commercial_launch_free_active(v_u5) then
    raise exception 'C1c: start null iken ücretsiz ay aktif';
  end if;
  if public.current_business_plan(v_u5) <> 'free' then
    raise exception 'C1d: pasif dalda ticari free değil';
  end if;
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000001') <> 'premium' then
    raise exception 'C1e: ödenmiş abonelik premium değil';
  end if;
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000013') <> 'premium' then
    raise exception 'C1f: mevcut aktif promo premium vermiyor';
  end if;
  raise notice 'PASS 17-C1 start null → pasif + mevcut davranış korunur';
end
$$;

-- C2/C3) Lansman açık: kayıt lansmandan SONRA → kayıttan; ÖNCE →
-- lansmandan başlar; süre 1 takvim ayı (Europe/Istanbul).
update public.app_runtime_config
  set value = to_jsonb((now() - interval '10 days')::text), updated_at = now()
  where key = 'commercial_launch_start';

do $$
begin
  insert into auth.users (id, created_at)
  values ('00000000-0000-4000-8000-000000000016', now() - interval '60 days')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type)
    values ('00000000-0000-4000-8000-000000000016', 'Ticari Onaltı',
            'commercial')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type)
    values ('00000000-0000-4000-8000-000000000016', 'commercial')
    on conflict do nothing;
  end;
end
$$;

do $$
declare
  v_u5 uuid := '00000000-0000-4000-8000-000000000005';
  v_u16 uuid := '00000000-0000-4000-8000-000000000016';
  v_launch timestamptz := public.commercial_launch_start();
  v_created5 timestamptz;
begin
  select created_at into v_created5 from auth.users where id = v_u5;
  -- Kayıt lansmandan sonra (u5) → dönem kayıttan başlar.
  if public.commercial_launch_free_start(v_u5)
     is distinct from greatest(v_created5, v_launch)
     or public.commercial_launch_free_start(v_u5)
        is distinct from v_created5 then
    raise exception 'C2a: sonradan kayıt dönemi kayıttan başlamıyor';
  end if;
  -- Kayıt lansmandan önce (u16) → dönem lansmandan başlar.
  if public.commercial_launch_free_start(v_u16)
     is distinct from v_launch then
    raise exception 'C2b: eski kayıt dönemi lansmandan başlamıyor';
  end if;
  -- 1 takvim ayı Istanbul.
  if public.commercial_launch_free_until(v_u16) is distinct from
     (((v_launch at time zone 'Europe/Istanbul') + interval '1 month')
       at time zone 'Europe/Istanbul') then
    raise exception 'C3a: bitiş = başlangıç + 1 Istanbul ayı değil';
  end if;
  if not public.is_commercial_launch_free_active(v_u5)
     or not public.is_commercial_launch_free_active(v_u16) then
    raise exception 'C2c: dönem içindeki ticari aktif görünmüyor';
  end if;
  raise notice 'PASS 17-C2/C3 başlangıç kuralı + 1 takvim ayı';
end
$$;

-- C4) Dönem içinde premium; dönem bitmiş kullanıcıda free (bitiş HARİÇ).
do $$
begin
  insert into auth.users (id, created_at)
  values ('00000000-0000-4000-8000-000000000017', now() - interval '90 days')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type)
    values ('00000000-0000-4000-8000-000000000017', 'Ticari Onyedi',
            'commercial')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type)
    values ('00000000-0000-4000-8000-000000000017', 'commercial')
    on conflict do nothing;
  end;
end
$$;

-- Lansmanı 2 ay öncesine çek: u17 dönemi (lansman+1ay) 1 ay önce BİTTİ;
-- u5 (yeni kayıt) hâlâ dönem içinde — pencere kişi bazlı.
update public.app_runtime_config
  set value = to_jsonb((now() - interval '2 months')::text), updated_at = now()
  where key = 'commercial_launch_start';

do $$
declare
  v_u5 uuid := '00000000-0000-4000-8000-000000000005';
  v_u17 uuid := '00000000-0000-4000-8000-000000000017';
begin
  if public.is_commercial_launch_free_active(v_u17)
     or public.current_business_plan(v_u17) <> 'free'
     or public.has_business_feature(v_u17, 'branches') then
    raise exception 'C4a: dönemi biten ticari free''ye dönmedi';
  end if;
  if not public.is_commercial_launch_free_active(v_u5)
     or public.current_business_plan(v_u5) <> 'premium'
     or not public.has_business_feature(v_u5, 'branches') then
    raise exception 'C4b: dönem içindeki ticari premium değil';
  end if;
  -- Otomatik ücret/abonelik oluşmadı.
  if exists (select 1 from public.user_entitlements
             where owner_id in (v_u5, v_u17) and plan <> 'free') then
    raise exception 'C4c: ücretsiz ay entitlement planına yazıldı';
  end if;
  raise notice 'PASS 17-C4 dönem içi premium / bitince free / yazım yok';
end
$$;

-- C5) Ödenmiş abonelik dönem SONRASINDA da korunur; eski aktif promo da.
set role service_role;
insert into public.user_entitlements
  (owner_id, plan, source, current_period_started_at, current_period_ends_at)
values ('00000000-0000-4000-8000-000000000017', 'premium', 'iap',
        now() - interval '1 day', now() + interval '30 days')
on conflict (owner_id) do update set
  plan = excluded.plan, source = excluded.source,
  current_period_started_at = excluded.current_period_started_at,
  current_period_ends_at = excluded.current_period_ends_at;
reset role;

do $$
begin
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000017') <> 'premium' then
    raise exception 'C5a: dönem sonrası ödenmiş abonelik premium değil';
  end if;
  -- u13: aktif promo (16'da set) — ücretsiz ay dalından bağımsız premium.
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000013') <> 'premium' then
    raise exception 'C5b: aktif promo hakkı korunmadı';
  end if;
  raise notice 'PASS 17-C5 ödenmiş abonelik + aktif promo korunur';
end
$$;

set role service_role;
update public.user_entitlements
  set plan = 'free', source = 'system',
      current_period_started_at = null, current_period_ends_at = null
  where owner_id = '00000000-0000-4000-8000-000000000017';
reset role;

-- C6) Tedarikçi ve bireysel birebir aynı: ticari lansman dalı onlara
-- sızmaz; tedarikçi kampanya anahtarı da ticariden etkilenmez.
do $$
declare
  v_u9 uuid := '00000000-0000-4000-8000-000000000009';
  v_u10 uuid := '00000000-0000-4000-8000-000000000010';
begin
  if public.is_commercial_launch_free_active(v_u9)
     or public.is_commercial_launch_free_active(v_u10) then
    raise exception 'C6a: ücretsiz ay wholesaler/individual''a sızdı';
  end if;
  -- 16 temizliği sonrası tedarikçi kampanyası pasif (start null) → paid yol.
  if public.is_supplier_launch_free_active(v_u9)
     or public.effective_supplier_plan(v_u9) <> 'free' then
    raise exception 'C6b: tedarikçi davranışı değişti';
  end if;
  if public.current_business_plan(v_u10) <> 'free' then
    raise exception 'C6c: bireysel davranışı değişti';
  end if;
  raise notice 'PASS 17-C6 rol izolasyonu';
end
$$;

-- C7) my_entitlement: yeni alanlar + eski alanlar (ticari u5 dönem içinde).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
declare r record;
begin
  select plan, effective_plan, recipe_limit, can_use_branches,
         can_start_promo, subscription_purchase_allowed,
         free_period_active, free_period_started_at, free_period_ends_at,
         free_period_days_left, launch_price_until
  into r from public.my_entitlement();
  if r.effective_plan <> 'premium' or r.recipe_limit <> -1
     or not r.can_use_branches then
    raise exception 'C7a: dönem içinde my_entitlement premium değil: %', r;
  end if;
  if r.free_period_active is distinct from true
     or r.free_period_started_at is null
     or r.free_period_ends_at is null
     or r.free_period_days_left < 1 or r.free_period_days_left > 31 then
    raise exception 'C7b: free_period alanları yanlış: %', r;
  end if;
  if r.launch_price_until is distinct from
     '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'C7c: launch_price_until yanlış: %', r.launch_price_until;
  end if;
  if r.can_start_promo then
    raise exception 'C7d: ticari CTA promosu açık görünüyor';
  end if;
  if not r.subscription_purchase_allowed then
    raise exception 'C7e: ticari satın alma kapandı';
  end if;
end
$$;
commit;

-- Wholesaler: yeni ticari alanlar false/null (rol izolasyonu, alan düzeyi).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
set local role authenticated;
do $$
declare r record;
begin
  select free_period_active, free_period_ends_at, launch_price_until
  into r from public.my_entitlement();
  if r.free_period_active or r.free_period_ends_at is not null
     or r.launch_price_until is not null then
    raise exception 'C7f: wholesaler ticari lansman alanı taşıdı: %', r;
  end if;
  raise notice 'PASS 17-C7 my_entitlement yeni + eski alanlar';
end
$$;
commit;

-- C8) Ticari pop-up ack anahtarları client'a açık; hatırlatma anahtarı
-- yine kapalı.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
begin
  insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
  values ('00000000-0000-4000-8000-000000000005', 'commercial_launch_v1',
          'welcome_ack')
  on conflict do nothing;
  insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
  values ('00000000-0000-4000-8000-000000000005', 'commercial_launch_v1',
          'ended_ack')
  on conflict do nothing;
  begin
    insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
    values ('00000000-0000-4000-8000-000000000005', 'commercial_launch_v1',
            'reminder_30d');
    raise exception 'C8a: client hatırlatma anahtarı yazabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 17-C8 ticari ack anahtarları';
end
$$;
commit;

-- Temizlik: ticari lansman start'ı seed durumuna (null) döndür.
update public.app_runtime_config
  set value = 'null'::jsonb, updated_at = now()
  where key = 'commercial_launch_start';
delete from public.user_campaign_notices
  where campaign_key = 'commercial_launch_v1';
