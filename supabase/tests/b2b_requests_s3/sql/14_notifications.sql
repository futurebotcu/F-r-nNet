-- 14) Yeni talep bildirimi: hedefleme, kendi mağazası hariç, dedupe, yoğunluk.
-- Mağaza kategorileri: A(u9)=Un,Maya · B(u11)=Un · C(u12)=Ambalaj.

-- N1) Kategori talebi (Maya) → yalnız A; Un → A ve B; Ambalaj → C.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, target_id, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000081', auth.uid(), 'category', null, 'Maya', '5 koli', 'Bursa', 'open'),
  ('30000000-0000-4000-8000-000000000082', auth.uid(), 'category', null, 'Un', '5 çuval', 'Bursa', 'open'),
  ('30000000-0000-4000-8000-000000000083', auth.uid(), 'shop', '20000000-0000-4000-8000-000000000011', 'Un', '1', 'Konya', 'open');
commit;

do $$
declare n int;
begin
  select count(*) into n from public.notifications
   where type = 'b2b_quote_request_created' and entity_id = '30000000-0000-4000-8000-000000000081';
  if n <> 1 or not exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000081'
       and recipient_id = '00000000-0000-4000-8000-000000000009') then
    raise exception 'N1a: Maya talebi yalnız A almalı (%)', n;
  end if;
  select count(*) into n from public.notifications
   where type = 'b2b_quote_request_created' and entity_id = '30000000-0000-4000-8000-000000000082';
  if n <> 2 then raise exception 'N1b: Un talebi A+B almalı (%)', n; end if;
  -- Mağaza hedefli → yalnız B (kategori eşleşen A almaz).
  select count(*) into n from public.notifications
   where type = 'b2b_quote_request_created' and entity_id = '30000000-0000-4000-8000-000000000083';
  if n <> 1 or not exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000083'
       and recipient_id = '00000000-0000-4000-8000-000000000011') then
    raise exception 'N1c: mağaza hedefli talep yalnız B almalı (%)', n;
  end if;
  -- Metin generic: alıcı adı/telefon yok; route Talepler sekmesi.
  if exists (select 1 from public.notifications where type = 'b2b_quote_request_created'
             and (actor_id is not null or route <> '/pazar?tab=talepler')) then
    raise exception 'N1d: bildirim actor/route sözleşmesi bozuk';
  end if;
  raise notice 'PASS 14-N1 hedefleme';
end $$;

-- N2) Alıcı aynı zamanda toptancıysa kendi mağazası bildirim almaz.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000084', auth.uid(), 'category', 'Un', '1', 'Konya', 'open');
commit;
do $$
begin
  if exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000084'
             and recipient_id = '00000000-0000-4000-8000-000000000009') then
    raise exception 'N2: alıcı kendi mağazasına bildirim aldı';
  end if;
  if not exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000084'
             and recipient_id = '00000000-0000-4000-8000-000000000011') then
    raise exception 'N2b: B bildirim almalıydı';
  end if;
  raise notice 'PASS 14-N2 kendi mağazası hariç';
end $$;

-- N3) Dedupe: aynı (alıcı, talep) için ikinci insert sessizce atlanır.
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
insert into public.notifications (recipient_id, type, title, body, entity_type, entity_id, route)
values ('00000000-0000-4000-8000-000000000011', 'b2b_quote_request_created', 'x', 'x',
        'quote_request', '30000000-0000-4000-8000-000000000084', '/pazar?tab=talepler')
on conflict do nothing;
do $$
declare n int;
begin
  select count(*) into n from public.notifications
   where type = 'b2b_quote_request_created' and entity_id = '30000000-0000-4000-8000-000000000084'
     and recipient_id = '00000000-0000-4000-8000-000000000011';
  if n <> 1 then raise exception 'N3: dedupe çalışmadı (%)', n; end if;
  raise notice 'PASS 14-N3 dedupe';
end $$;
rollback;

-- N4) Yoğunluk kapağı: B son 1 saatte 10 talep bildirimi aldıysa yenisi atlanır.
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
insert into public.notifications (recipient_id, type, title, body, entity_type, entity_id, route)
select '00000000-0000-4000-8000-000000000011', 'b2b_quote_request_created', 'y', 'y',
       'quote_request', gen_random_uuid(), '/pazar?tab=talepler'
from generate_series(1, 10);
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000085', auth.uid(), 'category', 'Un', '1', 'Bursa', 'open');
commit;
do $$
begin
  if exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000085'
             and recipient_id = '00000000-0000-4000-8000-000000000011') then
    raise exception 'N4a: yoğunluk kapağı çalışmadı (B yine aldı)';
  end if;
  -- A kapakta değil → alır.
  if not exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000085'
             and recipient_id = '00000000-0000-4000-8000-000000000009') then
    raise exception 'N4b: A bildirim almalıydı';
  end if;
  raise notice 'PASS 14-N4 yoğunluk kapağı';
end $$;

-- N5) Pasif mağaza bildirim almaz.
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
update public.b2b_supplier_shops set is_active = false where id = '20000000-0000-4000-8000-000000000012';
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000086', auth.uid(), 'category', 'Ambalaj', '1', 'İzmir', 'open');
commit;
do $$
begin
  if exists (select 1 from public.notifications where entity_id = '30000000-0000-4000-8000-000000000086') then
    raise exception 'N5: pasif mağaza bildirim aldı';
  end if;
  raise notice 'PASS 14-N5 pasif mağaza';
end $$;
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
update public.b2b_supplier_shops set is_active = true where id = '20000000-0000-4000-8000-000000000012';
commit;
