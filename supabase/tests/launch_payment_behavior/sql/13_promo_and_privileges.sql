-- Launch promo + yetki/güvenlik davranış testleri.

-- P1) Promo aktivasyonu idempotent; ikinci çağrı aynı bitişi döner.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
declare
  r1 record;
  r2 record;
begin
  select * into r1 from public.activate_launch_premium_promo();
  if r1.activated is distinct from true or r1.promo_status <> 'active' then
    raise exception 'P1a: ilk aktivasyon başarısız: % %',
      r1.activated, r1.promo_status;
  end if;
  if r1.promo_expires_at is distinct from
     (r1.promo_started_at + interval '3 months') then
    raise exception 'P1b: promo süresi 3 takvim ayı değil';
  end if;

  select * into r2 from public.activate_launch_premium_promo();
  if r2.activated then
    raise exception 'P1c: ikinci aktivasyon yeniden başlattı';
  end if;
  if r2.promo_expires_at is distinct from r1.promo_expires_at then
    raise exception 'P1d: ikinci çağrı farklı bitiş döndürdü';
  end if;
end
$$;
commit;

-- P2) Promo aktifken effective plan premium; my_entitlement tutarlı.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
declare
  r record;
begin
  select * into r from public.my_entitlement();
  if r.effective_plan <> 'premium' or r.can_start_promo then
    raise exception 'P2a: my_entitlement promo durumunu yansıtmıyor: % %',
      r.effective_plan, r.can_start_promo;
  end if;
end
$$;
commit;

-- P3) Süresi dolan promo yeniden BAŞLAMAZ.
update public.user_entitlements
  set promo_expires_at = now() - interval '1 hour'
  where owner_id = '00000000-0000-4000-8000-000000000005';

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
declare
  r record;
begin
  select * into r from public.activate_launch_premium_promo();
  if r.activated then
    raise exception 'P3a: süresi dolan promo yeniden başladı';
  end if;
  if r.promo_status <> 'expired' then
    raise exception 'P3b: promo_status expired değil: %', r.promo_status;
  end if;
end
$$;
commit;

do $$
begin
  if public.current_business_plan(
       '00000000-0000-4000-8000-000000000005') <> 'free' then
    raise exception 'P3c: süresi dolan promo hâlâ premium veriyor';
  end if;
  raise notice 'PASS 13-P1/P2/P3 promo yaşam döngüsü';
end
$$;

-- P4) authenticated kullanıcı kendi entitlement/promo alanlarını DOĞRUDAN
-- değiştiremez (grant yok → insufficient_privilege).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
set local role authenticated;
do $$
begin
  begin
    update public.user_entitlements
      set plan = 'premium', promo_expires_at = now() + interval '10 years';
    raise exception 'P4a: authenticated entitlement update edebildi!';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.user_entitlements (owner_id, plan)
    values ('00000000-0000-4000-8000-000000000005', 'premium');
    raise exception 'P4b: authenticated entitlement insert edebildi!';
  exception when insufficient_privilege then
    null;
  end;
  begin
    delete from public.user_entitlements;
    raise exception 'P4c: authenticated entitlement delete edebildi!';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'PASS 13-P4 direct write engelli';
end
$$;
commit;

-- P5) RPC grant matrisi.
do $$
declare
  bad text := '';
begin
  if has_function_privilege(
       'anon', 'public.activate_launch_premium_promo()', 'execute') then
    bad := bad || ' anon:activate';
  end if;
  if not has_function_privilege(
       'authenticated', 'public.activate_launch_premium_promo()',
       'execute') then
    bad := bad || ' authenticated:activate-yok';
  end if;
  if has_function_privilege(
       'authenticated',
       'public.apply_store_subscription(uuid,text,text,text,text,text,text,'
       || 'timestamptz,bigint,uuid,jsonb)',
       'execute') then
    bad := bad || ' authenticated:apply';
  end if;
  if not has_function_privilege(
       'service_role',
       'public.apply_store_subscription(uuid,text,text,text,text,text,text,'
       || 'timestamptz,bigint,uuid,jsonb)',
       'execute') then
    bad := bad || ' service_role:apply-yok';
  end if;
  if has_function_privilege(
       'authenticated',
       'public.claim_store_payment_event(text,text,uuid,text,text,text,text,'
       || 'text,text,bigint,jsonb,boolean)',
       'execute') then
    bad := bad || ' authenticated:claim';
  end if;
  if has_function_privilege(
       'authenticated',
       'public.complete_store_payment_event(text,text,text)', 'execute') then
    bad := bad || ' authenticated:complete';
  end if;
  if has_function_privilege(
       'authenticated', 'public.expire_old_listings()', 'execute') then
    bad := bad || ' authenticated:expire';
  end if;
  if bad <> '' then
    raise exception 'P5: grant matrisi hatalı:%', bad;
  end if;
  raise notice 'PASS 13-P5 grant matrisi';
end
$$;

-- P6) Launch fonksiyonları SECURITY DEFINER + sabit search_path.
do $$
declare
  bad text;
begin
  select string_agg(p.proname, ', ') into bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'app_config_int', 'app_config_bool', 'app_config_timestamptz',
      'claim_store_payment_event', 'complete_store_payment_event',
      'is_launch_promo_active', 'current_business_plan',
      'effective_supplier_plan', 'ensure_my_entitlement',
      'activate_launch_premium_promo', 'has_business_feature',
      'can_add_dealer', 'can_add_recipe', 'supplier_product_limit',
      'supplier_campaign_limit', 'supplier_monthly_reply_limit',
      'my_entitlement', 'store_product_mapping', 'apply_store_subscription',
      'is_listing_payment_enabled', 'get_listing_fee_amount_cents',
      'normalize_listing_fee', 'expire_old_listings', 'republish_listing')
    and (not p.prosecdef
         or coalesce(array_to_string(p.proconfig, ','), '')
            not like '%search_path=%');
  if bad is not null then
    raise exception
      'P6: security definer/search_path eksik: %', bad;
  end if;
  raise notice 'PASS 13-P6 security definer + search_path';
end
$$;
