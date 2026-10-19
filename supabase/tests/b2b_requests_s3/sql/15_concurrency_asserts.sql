-- 15) Eşzamanlılık sonuçları.
do $$
declare v text; n int;
begin
  select a into v from public.test_results where label = 'conc_accept_b' order by recorded_at desc limit 1;
  if v is null then raise exception 'C1: conc_accept_b sonucu yok'; end if;
  if v not like '%already decided%' then raise exception 'C1: ikinci kabul reddedilmedi: %', v; end if;
  select count(*) into n from public.b2b_quote_replies
   where quote_request_id = '30000000-0000-4000-8000-000000000082' and accepted;
  if n <> 1 then raise exception 'C2: R82''de accepted cevap sayısı % (1)', n; end if;
  if (select accepted_reply_id from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000082')
     <> '40000000-0000-4000-8000-000000000821' then
    raise exception 'C3: R82 kabul edilen cevap yanlış';
  end if;

  select a into v from public.test_results where label = 'conc_dup_reply_b' order by recorded_at desc limit 1;
  if v is null then raise exception 'C4: conc_dup_reply_b sonucu yok'; end if;
  if v <> 'unique_violation' then raise exception 'C4: çift teklif engellenmedi: %', v; end if;
  select count(*) into n from public.b2b_quote_replies
   where quote_request_id = '30000000-0000-4000-8000-000000000081'
     and supplier_shop_id = '20000000-0000-4000-8000-000000000009';
  if n <> 1 then raise exception 'C5: R81''de A cevabı % (1)', n; end if;
  raise notice 'PASS 15 eşzamanlılık (kabul yarışı + çift teklif)';
end $$;
