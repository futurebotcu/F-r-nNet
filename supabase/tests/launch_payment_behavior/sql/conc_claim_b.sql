-- Eşzamanlı claim testi — oturum B (A'nın transaction'ı açıkken teslim).
set role service_role;
with r as (
  select * from public.claim_store_payment_event(
    'ev-conc-1', 'INITIAL_PURCHASE',
    '00000000-0000-4000-8000-000000000001', 'firinnet_premium_monthly',
    null, 'tx-c1', null, 'production', 'play_store', 9000,
    '{}'::jsonb, true)
)
insert into public.test_results (label, a, b)
select 'conc_claim_b', r.should_process::text, r.current_status from r;
