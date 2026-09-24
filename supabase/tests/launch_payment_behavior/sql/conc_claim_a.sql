-- Eşzamanlı claim testi — oturum A (uzun tutulan transaction).
set role service_role;
begin;
with r as (
  select * from public.claim_store_payment_event(
    'ev-conc-1', 'INITIAL_PURCHASE',
    '00000000-0000-4000-8000-000000000001', 'firinnet_premium_monthly',
    null, 'tx-c1', null, 'production', 'play_store', 9000,
    '{}'::jsonb, true)
)
insert into public.test_results (label, a, b)
select 'conc_claim_a', r.should_process::text, r.current_status from r;
select pg_sleep(3);
commit;
