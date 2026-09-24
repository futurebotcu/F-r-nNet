-- Eşzamanlı promo aktivasyonu — oturum A (uzun tutulan transaction).
begin;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-4000-8000-000000000006', true);
set local role authenticated;
with r as (
  select * from public.activate_launch_premium_promo()
)
insert into public.test_results (label, a, b, c)
select 'conc_promo_a', r.activated::text, r.promo_started_at::text,
       r.promo_expires_at::text
from r;
select pg_sleep(3);
commit;
