-- Eşzamanlı kabul A: alıcı u13, R82'de A'nın cevabını kabul eder; 3 sn açık tutar.
-- Önce R82'ye A ve B cevap vermiş olmalı (bu dosya hazırlar).
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message)
values ('40000000-0000-4000-8000-000000000821', '30000000-0000-4000-8000-000000000082',
        '20000000-0000-4000-8000-000000000009', 'A → R82')
on conflict do nothing;
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message)
values ('40000000-0000-4000-8000-000000000822', '30000000-0000-4000-8000-000000000082',
        '20000000-0000-4000-8000-000000000011', 'B → R82')
on conflict do nothing;
commit;

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
select public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000821');
select pg_sleep(3);
commit;
