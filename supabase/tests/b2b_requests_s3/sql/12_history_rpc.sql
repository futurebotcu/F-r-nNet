-- 12) b2b_my_replied_requests(): yalnız çağıranın cevapladığı talepler;
-- karar/kapanış doğru; alıcı kimliği ve diğer tedarikçi cevapları YOK.
-- Seed durumu (10 + 11-G2/G6 commit): A(u9) → R1 (lost: B seçildi), R2
-- (pending), R3 (pending), R6 (closed), R8 (won). B(u11) → R1 (won).

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
declare
  n int;
  v_dec text;
  v_cols text;
begin
  select count(*) into n from public.b2b_my_replied_requests();
  if n <> 5 then raise exception 'H1: u9 için % satır (beklenen 5)', n; end if;

  select decision into v_dec from public.b2b_my_replied_requests()
   where request_id = '30000000-0000-4000-8000-000000000008';
  if v_dec <> 'won' then raise exception 'H1b: R8 decision % (won bekleniyor)', v_dec; end if;

  select decision into v_dec from public.b2b_my_replied_requests()
   where request_id = '30000000-0000-4000-8000-000000000001';
  if v_dec <> 'lost' then raise exception 'H2: R1 decision % (lost bekleniyor)', v_dec; end if;

  select decision into v_dec from public.b2b_my_replied_requests()
   where request_id = '30000000-0000-4000-8000-000000000006';
  if v_dec <> 'closed' then raise exception 'H3: R6 decision % (closed bekleniyor)', v_dec; end if;

  select decision into v_dec from public.b2b_my_replied_requests()
   where request_id = '30000000-0000-4000-8000-000000000003';
  if v_dec <> 'pending' then raise exception 'H4: R3 decision % (pending bekleniyor)', v_dec; end if;

  -- Kapalı talebin ayrıntısı artık geçmişte okunabiliyor (S2 sınırı kapandı).
  if (select category from public.b2b_my_replied_requests()
       where request_id = '30000000-0000-4000-8000-000000000006') <> 'Un' then
    raise exception 'H5: kapalı talebin kategori ayrıntısı gelmedi';
  end if;

  -- Diğer mağazanın cevabı (B → R1) satırlarda YOK; my_reply_id yalnız benim.
  if exists (select 1 from public.b2b_my_replied_requests()
              where my_reply_id = '40000000-0000-4000-8000-000000000111') then
    raise exception 'H6: başka mağazanın cevabı sızdı';
  end if;

  -- Dönüş kolonlarında kimlik/iletişim alanı yok.
  select string_agg(a.attname, ',') into v_cols
    from pg_proc p, unnest(p.proargnames) with ordinality a(attname, i)
   where p.proname = 'b2b_my_replied_requests';
  if v_cols ilike '%buyer_id%' or v_cols ilike '%phone%' or v_cols ilike '%accepted_reply_id%' then
    raise exception 'H7: RPC kimlik/karar id kolonu döndürüyor: %', v_cols;
  end if;
  raise notice 'PASS 12 geçmiş RPC (u9)';
end $$;
rollback;

-- u11 yalnız kendi (won) satırını görür.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
declare n int; v_dec text;
begin
  select count(*) into n from public.b2b_my_replied_requests();
  if n <> 1 then raise exception 'H8: u11 için % satır (beklenen 1)', n; end if;
  select decision into v_dec from public.b2b_my_replied_requests();
  if v_dec <> 'won' then raise exception 'H9: u11 decision % (won)', v_dec; end if;
  raise notice 'PASS 12 geçmiş RPC (u11 won)';
end $$;
rollback;

-- Mağazası olmayan alıcı → boş; anon → EXECUTE yok.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
declare n int;
begin
  select count(*) into n from public.b2b_my_replied_requests();
  if n <> 0 then raise exception 'H10: mağazasız kullanıcı % satır gördü', n; end if;
  raise notice 'PASS 12 mağazasız → boş';
end $$;
rollback;

begin;
select set_config('request.jwt.claim.role', 'anon', true);
set local role anon;
do $$
begin
  begin
    perform public.b2b_my_replied_requests();
    raise exception 'H11: anon RPC çağırabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.b2b_open_quote_requests_page();
    raise exception 'H12: anon sayfalama RPC çağırabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 12 anon reddi';
end $$;
rollback;
