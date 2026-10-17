-- 10) Seed: 3 toptancı mağazası, alıcı talepleri, cevaplar, karar/kapanış.
-- Kullanıcılar: u9/u11/u12 wholesaler; u1/u13 commercial (alıcı).
-- Sabit UUID'ler: mağaza 2000…, talep 3000…, cevap 4000….
-- Lansman kampanyası AÇIK (seed boyunca sınırsız reply/ürün); kota testi
-- 11'de kampanyayı kapatıp yeniden açar.

update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';

-- ── Mağazalar (sahip olarak, RLS altında) ──
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_supplier_shops (id, owner_id, shop_name, categories, service_regions, is_active)
values ('20000000-0000-4000-8000-000000000009', auth.uid(), 'Mağaza A (u9)',
        array['Un','Maya'], array['Marmara'], true);
commit;

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_supplier_shops (id, owner_id, shop_name, categories, service_regions, is_active)
values ('20000000-0000-4000-8000-000000000011', auth.uid(), 'Mağaza B (u11)',
        array['Un'], array['İç Anadolu'], true);
commit;

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000012', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_supplier_shops (id, owner_id, shop_name, categories, service_regions, is_active)
values ('20000000-0000-4000-8000-000000000012', auth.uid(), 'Mağaza C (u12)',
        array['Ambalaj'], array['Ege'], true);
commit;

-- ── Alıcı u1 talepleri ──
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, target_id, category, quantity, city, district, buyer_type, status) values
  ('30000000-0000-4000-8000-000000000001', auth.uid(), 'category', null, 'Un',      '300 çuval', 'İstanbul', 'Bağcılar', 'Fırın', 'open'),
  ('30000000-0000-4000-8000-000000000002', auth.uid(), 'category', null, 'Maya',    '40 koli',   'Bursa',    '',         'Fırın', 'open'),
  ('30000000-0000-4000-8000-000000000003', auth.uid(), 'category', null, 'Un',      '50 çuval',  'Ankara',   '',         'Fırın', 'open'),
  ('30000000-0000-4000-8000-000000000004', auth.uid(), 'category', null, 'Ambalaj', '10.000',    'İzmir',    '',         'Pastane','open'),
  ('30000000-0000-4000-8000-000000000005', auth.uid(), 'shop', '20000000-0000-4000-8000-000000000011', 'Un', '100 çuval', 'Konya', '', 'Fırın', 'open'),
  ('30000000-0000-4000-8000-000000000006', auth.uid(), 'category', null, 'Un',      '20 çuval',  'İstanbul', '',         'Fırın', 'open');
commit;

-- ── Cevaplar ──
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message, price_note, status) values
  ('40000000-0000-4000-8000-000000000091', '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000009', 'A → R1', '₺640', 'sent'),
  ('40000000-0000-4000-8000-000000000092', '30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000009', 'A → R2', null, 'sent'),
  ('40000000-0000-4000-8000-000000000096', '30000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000009', 'A → R6', null, 'sent');
commit;

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message, status) values
  ('40000000-0000-4000-8000-000000000111', '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000011', 'B → R1', 'sent');
commit;

-- ── Alıcı kararı: R1'de B seçilir; R6 kapatılır ──
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
select public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000111');
update public.b2b_quote_requests set status = 'closed'
  where id = '30000000-0000-4000-8000-000000000006';
commit;

do $$
declare v int;
begin
  select count(*) into v from public.b2b_quote_requests;
  if v <> 6 then raise exception 'seed: talep sayısı % (beklenen 6)', v; end if;
  select count(*) into v from public.b2b_quote_replies;
  if v <> 4 then raise exception 'seed: cevap sayısı % (beklenen 4)', v; end if;
  if (select status from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000001') <> 'answered' then
    raise exception 'seed: R1 answered olmalı (trigger open→answered guard ile uyumlu değil)';
  end if;
  if (select accepted_reply_id from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000001')
     <> '40000000-0000-4000-8000-000000000111' then
    raise exception 'seed: R1 accepted_reply_id yanlış';
  end if;
  if not (select accepted from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000111') then
    raise exception 'seed: B cevabı accepted olmalı';
  end if;
  if (select status from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000091') <> 'declined' then
    raise exception 'seed: A cevabı R1 declined olmalı';
  end if;
  raise notice 'PASS 10 seed';
end $$;
