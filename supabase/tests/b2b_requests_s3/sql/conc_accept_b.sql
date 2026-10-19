-- Eşzamanlı kabul B: A'nın transaction'ı açıkken aynı alıcı B'nin cevabını
-- kabul etmeye çalışır → satır kilidinde bekler, A commit edince
-- 'already decided' ile reddedilir. Sonuç test_results'a yazılır.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    perform public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000822');
    insert into public.test_results (label, a) values ('conc_accept_b', 'accepted');
  exception when others then
    insert into public.test_results (label, a) values ('conc_accept_b', sqlerrm);
  end;
end $$;
commit;
