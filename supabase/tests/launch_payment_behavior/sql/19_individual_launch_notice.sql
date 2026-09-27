-- Bireysel Lansman Bilgilendirmesi: bireyselde satın alma/ücret yok,
-- individual_free_until tek kaynaktan; tedarikçi/ticari davranışı DEĞİŞMEZ.

-- I0) Bilinen config durumu + taze kullanıcılar (24 bireysel, 25 toptancı,
--     26 ticari) — replica modda da kendi kullanıcılarını kurar.
update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';
update public.app_runtime_config
  set value = '"2027-10-01T00:00:00+03:00"'::jsonb, updated_at = now()
  where key = 'supplier_launch_free_until';
update public.app_runtime_config
  set value = 'false'::jsonb, updated_at = now()
  where key = 'supplier_paid_packages_published';
update public.app_runtime_config
  set value = to_jsonb((now() - interval '10 days')::text), updated_at = now()
  where key = 'commercial_launch_start';

do $$
begin
  insert into auth.users (id) values
    ('00000000-0000-4000-8000-000000000024'),
    ('00000000-0000-4000-8000-000000000025'),
    ('00000000-0000-4000-8000-000000000026')
  on conflict do nothing;
  begin
    insert into public.profiles (id, display_name, account_type) values
      ('00000000-0000-4000-8000-000000000024', 'Bireysel Yirmidört',
       'individual'),
      ('00000000-0000-4000-8000-000000000025', 'Toptancı Yirmibeş',
       'wholesaler'),
      ('00000000-0000-4000-8000-000000000026', 'Ticari Yirmialtı',
       'commercial')
    on conflict do nothing;
  exception when undefined_column then
    insert into public.profiles (id, account_type) values
      ('00000000-0000-4000-8000-000000000024', 'individual'),
      ('00000000-0000-4000-8000-000000000025', 'wholesaler'),
      ('00000000-0000-4000-8000-000000000026', 'commercial')
    on conflict do nothing;
  end;
end
$$;

-- I1) Tek kaynak bitiş tarihi: config değeri + okuyucu fonksiyon +
--     server-saat kontratı (parametre almaz) + kolon SONA eklendi.
do $$
declare
  v_until timestamptz;
  v_last text;
begin
  if (select value from public.app_runtime_config
      where key = 'individual_launch_free_until')
     is distinct from '"2027-10-01T00:00:00+03:00"'::jsonb then
    raise exception 'I1a: individual_launch_free_until config değeri yanlış';
  end if;
  v_until := public.individual_launch_free_until();
  if v_until is distinct from '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'I1b: okuyucu fonksiyon config''i döndürmüyor (%)',
      v_until;
  end if;
  if (select pronargs from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'individual_launch_free_until') <> 0 then
    raise exception 'I1c: individual_launch_free_until parametre almamalı';
  end if;
  -- Eski sürüm uyumu: yeni kolon my_entitlement çıktısının SONUNDA.
  select proargnames[array_length(proargnames, 1)] into v_last
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'my_entitlement';
  if v_last is distinct from 'individual_free_until' then
    raise exception 'I1d: individual_free_until son kolon değil (%)', v_last;
  end if;
  raise notice 'PASS 19-I1 tek kaynak tarih + kontratlar';
end
$$;

-- I2) Bireysel my_entitlement: satın alma HER KOŞULDA kapalı, ücretsiz dönem
--     tarihi dolu, ücretli kilit yok; iş kampanya alanları boş/false.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000024', true);
set local role authenticated;
do $$
declare r record;
begin
  select subscription_purchase_allowed, individual_free_until,
         can_use_branches, can_use_debt_expense, can_use_dealer_driver_ops,
         supplier_launch_free_active, supplier_launch_free_until,
         free_period_active, launch_price_until
    into r from public.my_entitlement();
  if r.subscription_purchase_allowed then
    raise exception 'I2a: bireyselde satın alma açık görünüyor';
  end if;
  if r.individual_free_until is distinct from
     '2027-10-01T00:00:00+03:00'::timestamptz then
    raise exception 'I2b: individual_free_until yanlış (%)',
      r.individual_free_until;
  end if;
  -- Bireyselde ücretli kilit yok: feature gate''ler yalnız ticariye uygulanır.
  if not (r.can_use_branches and r.can_use_debt_expense
          and r.can_use_dealer_driver_ops) then
    raise exception 'I2c: bireyselde özellik kilidi görünüyor: %', r;
  end if;
  if r.supplier_launch_free_active
     or r.supplier_launch_free_until is not null
     or r.free_period_active
     or r.launch_price_until is not null then
    raise exception 'I2d: bireyselde iş kampanya alanları dolu: %', r;
  end if;
  raise notice 'PASS 19-I2 bireysel entitlement';
end
$$;
commit;

-- I3) Bireysel ilan ücreti yok (mevcut lansman config''i: ödemeler kapalı).
do $$
declare v_u uuid := '00000000-0000-4000-8000-000000000024';
begin
  -- is_listing_fee_required harness zincirinde yok (20260712090000 zincir
  -- dışı); replica modda vardır → varsa doğrula (plpgsql lazy plan).
  if to_regprocedure('public.is_listing_fee_required(uuid,text)')
     is not null then
    if public.is_listing_fee_required(v_u, 'job_seek')
       or public.is_listing_fee_required(v_u, 'job_offer')
       or public.is_listing_fee_required(v_u, 'market') then
      raise exception 'I3a: bireyselde ilan ücreti gerekli görünüyor';
    end if;
  end if;
  if public.get_listing_fee_amount_cents(v_u, 'job_offer') <> 0
     or public.get_listing_fee_amount_cents(v_u, 'market') <> 0 then
    raise exception 'I3b: bireyselde ilan ücreti tutarı sıfır değil';
  end if;
  raise notice 'PASS 19-I3 bireysel ilan ücreti yok';
end
$$;

-- I4) Pop-up görüldü kaydı RLS: bireysel kendi popup_ack''ini yazar
--     (idempotent, tek satır); başkası adına ve service-role anahtarı reddi.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000024', true);
set local role authenticated;
insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
values ('00000000-0000-4000-8000-000000000024', 'individual_launch_v1',
        'popup_ack')
on conflict do nothing;
insert into public.user_campaign_notices (user_id, campaign_key, notice_key)
values ('00000000-0000-4000-8000-000000000024', 'individual_launch_v1',
        'popup_ack')
on conflict do nothing;
do $$
begin
  if (select count(*) from public.user_campaign_notices
      where user_id = '00000000-0000-4000-8000-000000000024'
        and campaign_key = 'individual_launch_v1'
        and notice_key = 'popup_ack') <> 1 then
    raise exception 'I4a: popup_ack idempotent tek satır değil';
  end if;
  begin
    insert into public.user_campaign_notices
      (user_id, campaign_key, notice_key)
    values ('00000000-0000-4000-8000-000000000025', 'individual_launch_v1',
            'popup_ack');
    raise exception 'I4b: başkası adına ack yazılabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.user_campaign_notices
      (user_id, campaign_key, notice_key)
    values ('00000000-0000-4000-8000-000000000024', 'individual_launch_v1',
            'reminder_30d');
    raise exception 'I4c: client reminder anahtarı yazabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 19-I4 ack RLS';
end
$$;
commit;

-- I5) Tedarikçi ve ticari davranış BİREBİR AYNI: kampanya/satın alma
--     alanları önceki kurallarla; yeni alan iş hesaplarında NULL.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000025', true);
set local role authenticated;
do $$
declare r record;
begin
  select subscription_purchase_allowed, individual_free_until,
         supplier_launch_free_active, supplier_launch_free_until,
         supplier_effective_plan, can_start_promo
    into r from public.my_entitlement();
  if r.subscription_purchase_allowed or r.can_start_promo then
    raise exception 'I5a: tedarikçi satın alma/promo davranışı değişti: %', r;
  end if;
  if r.supplier_launch_free_active is distinct from true
     or r.supplier_launch_free_until is distinct from
        '2027-10-01T00:00:00+03:00'::timestamptz
     or r.supplier_effective_plan <> 'premium' then
    raise exception 'I5b: tedarikçi kampanya alanları değişti: %', r;
  end if;
  if r.individual_free_until is not null then
    raise exception 'I5c: tedarikçide individual_free_until dolu';
  end if;
  raise notice 'PASS 19-I5a-c tedarikçi değişmedi';
end
$$;
commit;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000026', true);
set local role authenticated;
do $$
declare r record;
begin
  select subscription_purchase_allowed, individual_free_until,
         free_period_active, effective_plan, launch_price_until
    into r from public.my_entitlement();
  if not r.subscription_purchase_allowed then
    raise exception 'I5d: ticari satın alma kapandı';
  end if;
  if r.free_period_active is distinct from true
     or r.effective_plan <> 'premium'
     or r.launch_price_until is null then
    raise exception 'I5e: ticari ücretsiz ay/fiyat alanları değişti: %', r;
  end if;
  if r.individual_free_until is not null then
    raise exception 'I5f: ticaride individual_free_until dolu';
  end if;
  raise notice 'PASS 19-I5d-f ticari değişmedi';
end
$$;
commit;

-- Temizlik: 17 sonrası beklenen duruma dön (start null → kampanya pasif).
update public.app_runtime_config
  set value = 'null'::jsonb, updated_at = now()
  where key = 'commercial_launch_start';
