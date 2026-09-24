-- MİGRATION SONRASI eski uygulama uyumluluğu (yalnız replica modunda).
-- u7 = eski backend'de pending ilan bırakan free ticari kullanıcı.

-- O1) Backfill: eski pending ilan waived oldu ve herkese görünür.
do $$
declare r record;
begin
  select fee_status, fee_required, fee_amount_cents, expires_at into r
  from public.job_offer_posts
  where id = '00000000-0000-4000-8000-00000000aa07';
  if r.fee_status <> 'waived' or r.fee_required or r.fee_amount_cents <> 0 then
    raise exception 'O1a: pending ilan waived olmadı: % % %',
      r.fee_status, r.fee_required, r.fee_amount_cents;
  end if;
  if r.expires_at is null or r.expires_at <= now() then
    raise exception 'O1b: backfill expires_at geçersiz: %', r.expires_at;
  end if;
end
$$;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000008', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.job_offer_posts
      where id = '00000000-0000-4000-8000-00000000aa07') <> 1 then
    raise exception 'O1c: waived ilan başka kullanıcıya görünmüyor';
  end if;
  raise notice 'PASS 15-O1 pending→waived backfill + görünürlük';
end
$$;
commit;

-- O2) Eski app "öde ve yayınla" akışı: waived ilana intent açılamaz
-- (satın alma intent'siz başlayamaz → 50 TL tahsilat yolu kapalı).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
set local role authenticated;
do $$
begin
  begin
    perform * from public.create_listing_payment_intent(
      'job_offer', '00000000-0000-4000-8000-00000000aa07');
    raise exception 'O2a: waived ilana intent açılabildi!';
  exception when raise_exception then
    if sqlerrm like '%O2a%' then raise; end if;
  end;
  raise notice 'PASS 15-O2 waived ilana intent reddi';
end
$$;
commit;

-- O3) Guard: ilan bir şekilde pending kalsa bile lansman bayrağı kapalıyken
-- intent açmak server tarafından reddedilir.
begin;
select set_config('app.listing_fee_admin', 'on', true);
update public.job_offer_posts
  set fee_status = 'pending'
  where id = '00000000-0000-4000-8000-00000000aa07';
select set_config('app.listing_fee_admin', 'off', true);
commit;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
set local role authenticated;
do $$
begin
  begin
    perform * from public.create_listing_payment_intent(
      'job_offer', '00000000-0000-4000-8000-00000000aa07');
    raise exception 'O3a: ödeme kapalıyken intent açılabildi!';
  exception when raise_exception then
    if sqlerrm like '%O3a%' then raise; end if;
    if sqlerrm not like '%listing payments disabled%' then
      raise exception 'O3b: beklenmeyen hata: %', sqlerrm;
    end if;
  end;
  if exists (select 1 from public.listing_payment_intents
             where listing_id = '00000000-0000-4000-8000-00000000aa07') then
    raise exception 'O3c: intent satırı oluştu!';
  end if;
  raise notice 'PASS 15-O3 lansman bayrağı intent guard';
end
$$;
commit;

begin;
select set_config('app.listing_fee_admin', 'on', true);
update public.job_offer_posts
  set fee_status = 'waived'
  where id = '00000000-0000-4000-8000-00000000aa07';
select set_config('app.listing_fee_admin', 'off', true);
commit;

-- O4) Eski app my_entitlement çağrısı: eski kolon adları aynen dönüyor
-- (yeni fonksiyon superset döner; eski client fazla kolonları yok sayar).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
set local role authenticated;
do $$
declare r record;
begin
  select plan, effective_plan, is_trial_active, days_left, recipe_limit,
         dealer_limit, can_use_branches, supplier_effective_plan
  into r from public.my_entitlement();
  if r.plan is null or r.effective_plan not in ('free', 'premium') then
    raise exception 'O4a: my_entitlement eski kolonları bozuk: %', r;
  end if;
  raise notice 'PASS 15-O4 my_entitlement eski app uyumu (%: %)',
    r.plan, r.effective_plan;
end
$$;
commit;

-- O5) Yeni ilan: lansmanda ücretsiz (waived), server 30 gün expiry atar,
-- diğer kullanıcıya anında görünür.
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000007', true);
set local role authenticated;
insert into public.job_offer_posts (id, owner_id, title, role_title)
values ('00000000-0000-4000-8000-00000000aa08',
        '00000000-0000-4000-8000-000000000007', 'Yeni lansman ilanı', 'Usta');
commit;

do $$
declare r record;
begin
  select fee_status, fee_required, fee_amount_cents, expires_at into r
  from public.job_offer_posts
  where id = '00000000-0000-4000-8000-00000000aa08';
  if r.fee_status <> 'waived' or r.fee_required or r.fee_amount_cents <> 0 then
    raise exception 'O5a: yeni ilan ücretsiz yayınlanmadı: %', r.fee_status;
  end if;
  if r.expires_at is null
     or r.expires_at > now() + interval '31 days'
     or r.expires_at < now() + interval '29 days' then
    raise exception 'O5b: yeni ilan expiry ~30 gün değil: %', r.expires_at;
  end if;
end
$$;

begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000008', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.job_offer_posts
      where id = '00000000-0000-4000-8000-00000000aa08') <> 1 then
    raise exception 'O5c: yeni ilan diğer kullanıcıya görünmüyor';
  end if;
  raise notice 'PASS 15-O5 yeni ilan ücretsiz + 30 gün + görünür';
end
$$;
commit;
