-- 13) Sunucu tarafı sayfalama/filtre + sayaç tutarlılığı.
-- Açık (karar yok, open/answered) talepler: R3 (Un/Ankara, A cevapladı),
-- R4 (Ambalaj/İzmir), R5 (shop→B, Un/Konya), R71-R74 (Ambalaj/İzmir).
-- R1 (karar), R2 (open; 11-G6 rollback), R6 (closed).
-- → açık: R2, R3, R4, R5, R71, R72, R73, R74 = 8.

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
declare
  n int; tot bigint; c record;
begin
  -- Tüm açık (p_exclude_replied=false) = 8
  select count(*), max(total_count) into n, tot
    from public.b2b_open_quote_requests_page(null, null, false, 100, 0);
  if n <> 8 or tot <> 8 then raise exception 'P1: açık % / total % (8 bekleniyor)', n, tot; end if;

  -- Yeni (cevapladıklarım hariç: R2, R3) = 6
  select count(*), max(total_count) into n, tot
    from public.b2b_open_quote_requests_page(null, null, true, 100, 0);
  if n <> 6 or tot <> 6 then raise exception 'P2: yeni % / total % (6 bekleniyor)', n, tot; end if;

  -- Sayaç RPC aynı sayıları verir.
  select * into c from public.b2b_supplier_request_counts();
  if c.fresh_count <> 6 or c.network_open_count <> 8 then
    raise exception 'P3: counts fresh=% network=% (6/8)', c.fresh_count, c.network_open_count;
  end if;

  -- Kategori filtresi: Ambalaj = R4 + R71..74 = 5 (hepsi yeni)
  select count(*) into n from public.b2b_open_quote_requests_page(array['Ambalaj'], null, true, 100, 0);
  if n <> 5 then raise exception 'P4: Ambalaj % (5)', n; end if;

  -- İl filtresi: Konya = R5
  select count(*) into n from public.b2b_open_quote_requests_page(null, array['Konya'], true, 100, 0);
  if n <> 1 then raise exception 'P5: Konya % (1)', n; end if;

  -- Sayfalama: limit 2 offset 0 → 2 satır, total 6; offset 4 → 2; offset 6 → 0.
  select count(*), max(total_count) into n, tot from public.b2b_open_quote_requests_page(null, null, true, 2, 0);
  if n <> 2 or tot <> 6 then raise exception 'P6: sayfa1 %/% (2/6)', n, tot; end if;
  select count(*) into n from public.b2b_open_quote_requests_page(null, null, true, 2, 4);
  if n <> 2 then raise exception 'P7: sayfa3 % (2)', n; end if;
  select count(*) into n from public.b2b_open_quote_requests_page(null, null, true, 2, 6);
  if n <> 0 then raise exception 'P8: sayfa4 % (0)', n; end if;

  -- Birleşik filtre: kategori + il (Ambalaj ∧ İzmir = R4 + R71..74 = 5;
  -- Ambalaj ∧ Konya = 0); exclude_replied + filtre birlikte (Un ∧ yeni: R5
  -- yalnız — R3 cevaplandı); filtre + sayfalama (limit 2 → total 5).
  select count(*) into n from public.b2b_open_quote_requests_page(array['Ambalaj'], array['İzmir'], true, 100, 0);
  if n <> 5 then raise exception 'P4b: Ambalaj∧İzmir % (5)', n; end if;
  select count(*) into n from public.b2b_open_quote_requests_page(array['Ambalaj'], array['Konya'], true, 100, 0);
  if n <> 0 then raise exception 'P4c: Ambalaj∧Konya % (0)', n; end if;
  select count(*) into n from public.b2b_open_quote_requests_page(array['Un'], null, true, 100, 0);
  if n <> 1 then raise exception 'P4d: Un∧yeni % (1: R5)', n; end if;
  select count(*) into n from public.b2b_open_quote_requests_page(array['Un'], null, false, 100, 0);
  if n <> 2 then raise exception 'P4e: Un∧tümü % (2: R3,R5)', n; end if;
  select count(*), max(total_count) into n, tot from public.b2b_open_quote_requests_page(array['Ambalaj'], array['İzmir'], true, 2, 4);
  if n <> 1 or tot <> 5 then raise exception 'P4f: filtre+sayfa %/% (1/5)', n, tot; end if;
  -- Çoklu kategori / il dizileri.
  select count(*) into n from public.b2b_open_quote_requests_page(array['Un','Maya'], array['Konya','Bursa'], false, 100, 0);
  if n <> 2 then raise exception 'P4g: çoklu dizi % (2: R2 Maya/Bursa, R5 Un/Konya)', n; end if;

  -- Limit üst sınırı 100, negatif offset 0'a çekilir (hata yok).
  select count(*) into n from public.b2b_open_quote_requests_page(null, null, true, 100000, -5);
  if n <> 6 then raise exception 'P9: sınır normalizasyonu % (6)', n; end if;

  -- Sıralama: en yeni önce (created_at desc).
  if exists (
    select 1 from (
      select created_at, lag(created_at) over (order by created_at desc) prev
      from public.b2b_open_quote_requests_page(null, null, false, 100, 0)) t
    where prev is not null and prev < created_at) then
    raise exception 'P10: sıralama created_at desc değil';
  end if;

  -- Eski RPC ile tutarlılık (exclude=false aynı küme).
  if (select count(*) from public.b2b_open_quote_requests()) <> 8 then
    raise exception 'P11: eski RPC % (8)', (select count(*) from public.b2b_open_quote_requests());
  end if;
  raise notice 'PASS 13 sayfalama + filtre + sayaçlar';
end $$;
rollback;

-- Kimlik sızıntısı yok: sayfalama RPC kolonlarında buyer_id yok.
do $$
declare v_cols text;
begin
  select string_agg(a.attname, ',') into v_cols
    from pg_proc p, unnest(p.proargnames) with ordinality a(attname, i)
   where p.proname = 'b2b_open_quote_requests_page';
  if v_cols ilike '%buyer_id%' then raise exception 'P12: buyer_id sızıyor'; end if;
  raise notice 'PASS 13 anonimlik kolon kontrolü';
end $$;
