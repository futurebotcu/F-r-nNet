-- 16) Rollback sonrası: S3 nesneleri yok, S3 öncesi akış çalışıyor, veri duruyor.
do $$
declare n int;
begin
  if exists (select 1 from pg_proc where proname in (
      'b2b_my_replied_requests','b2b_open_quote_requests_page','b2b_supplier_request_counts',
      'notify_b2b_quote_request_created','b2b_qr_guard_columns','b2b_replies_guard_insert',
      'b2b_shops_guard_columns')) then
    raise exception 'RB1: S3 fonksiyonları hâlâ var';
  end if;
  if exists (select 1 from pg_trigger where tgname in (
      'trg_notify_b2b_quote_request_created','trg_b2b_qr_guard_columns',
      'trg_b2b_replies_guard_insert','trg_b2b_shops_guard_columns')) then
    raise exception 'RB2: S3 trigger''ları hâlâ var';
  end if;
  if exists (select 1 from pg_indexes where indexname in (
      'notifications_b2b_qr_dedupe_idx','idx_b2b_qr_open_cat_city',
      'idx_b2b_replies_shop_created','idx_b2b_shops_owner_active')) then
    raise exception 'RB3: S3 index''leri hâlâ var';
  end if;
  -- S3 öncesi nesneler duruyor.
  if not exists (select 1 from pg_trigger where tgname = 'trg_b2b_replies_guard_status') then
    raise exception 'RB4: S3 öncesi reply guard kayboldu';
  end if;
  if not exists (select 1 from pg_proc where proname = 'b2b_open_quote_requests') then
    raise exception 'RB5: eski açık talep RPC''si kayboldu';
  end if;
  -- Veri korunur.
  select count(*) into n from public.b2b_quote_requests;
  if n < 6 then raise exception 'RB6: talep verisi kayboldu (%)', n; end if;
  select count(*) into n from public.b2b_quote_replies;
  if n < 4 then raise exception 'RB7: cevap verisi kayboldu (%)', n; end if;
  -- İletişim kolonları (varsayılan rollback'te) korunur.
  if not exists (select 1 from information_schema.columns
                  where table_name = 'b2b_supplier_shops' and column_name = 'phone') then
    raise exception 'RB8: iletişim kolonları beklenmedik şekilde düştü';
  end if;
  raise notice 'PASS 16-RB nesneler ve veri';
end $$;

-- S3 öncesi akış: teklif ver → answered; kabul RPC çalışır.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000099', auth.uid(), 'category', 'Un', '1', 'Bursa', 'open');
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message)
values ('40000000-0000-4000-8000-000000000099', '30000000-0000-4000-8000-000000000099',
        '20000000-0000-4000-8000-000000000009', 'rollback sonrası teklif');
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
select public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000099');
commit;
do $$
begin
  if (select status from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000099') <> 'answered' then
    raise exception 'RB9: rollback sonrası open→answered çalışmıyor';
  end if;
  if not (select accepted from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000099') then
    raise exception 'RB10: rollback sonrası kabul çalışmıyor';
  end if;
  raise notice 'PASS 16-RB S3 öncesi akış';
end $$;
