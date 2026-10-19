-- Eşzamanlı çift teklif A: u9 (mağaza A) R81'e cevap verir, 3 sn açık tutar.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message)
values ('40000000-0000-4000-8000-000000000811', '30000000-0000-4000-8000-000000000081',
        '20000000-0000-4000-8000-000000000009', 'A → R81 (oturum 1)');
select pg_sleep(3);
commit;
