-- Eşzamanlı çift teklif B: aynı mağaza, aynı talep, ikinci oturum → unique
-- index kilidinde bekler; A commit edince unique_violation.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message)
    values ('30000000-0000-4000-8000-000000000081', '20000000-0000-4000-8000-000000000009', 'A → R81 (oturum 2)');
    insert into public.test_results (label, a) values ('conc_dup_reply_b', 'inserted');
  exception when unique_violation then
    insert into public.test_results (label, a) values ('conc_dup_reply_b', 'unique_violation');
  when others then
    insert into public.test_results (label, a) values ('conc_dup_reply_b', sqlerrm);
  end;
end $$;
commit;
