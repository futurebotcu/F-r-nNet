-- 11) Kolon guard'ları, durum geçişleri, çift teklif, yetkisiz kabul, kota.
-- Beklenen hata sınıfları: insufficient_privilege (42501: guard + RLS),
-- unique_violation (çift teklif), diğer RPC hataları SQLERRM ile.

-- G1) Mağaza sahibi is_verified / owner_id yazamaz; diğer alanları yazabilir.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    update public.b2b_supplier_shops set is_verified = true
      where id = '20000000-0000-4000-8000-000000000009';
    raise exception 'G1a: sahip is_verified yazabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.b2b_supplier_shops set owner_id = '00000000-0000-4000-8000-000000000011'
      where id = '20000000-0000-4000-8000-000000000009';
    raise exception 'G1b: sahip owner_id değiştirebildi';
  exception when insufficient_privilege then null;
  end;
  update public.b2b_supplier_shops
     set description = 'Güncel', phone = '0532 000 00 00', whatsapp = '905320000000',
         website = 'https://a.example', address = 'Konya OSB'
   where id = '20000000-0000-4000-8000-000000000009';
  if (select phone from public.b2b_supplier_shops where id = '20000000-0000-4000-8000-000000000009') <> '0532 000 00 00' then
    raise exception 'G1c: iletişim alanları yazılamadı';
  end if;
  begin
    update public.b2b_supplier_shops set phone = repeat('9', 40)
      where id = '20000000-0000-4000-8000-000000000009';
    raise exception 'G1d: uzunluk CHECK çalışmadı';
  exception when check_violation then null;
  end;
  raise notice 'PASS 11-G1 mağaza kolon guard + iletişim alanları';
end $$;
rollback;

-- G1e) service_role is_verified yazabilir (backoffice yolu).
begin;
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
update public.b2b_supplier_shops set is_verified = true
  where id = '20000000-0000-4000-8000-000000000012';
do $$ begin
  if not (select is_verified from public.b2b_supplier_shops where id = '20000000-0000-4000-8000-000000000012') then
    raise exception 'G1e: service_role is_verified yazamadı';
  end if;
  raise notice 'PASS 11-G1e service_role is_verified';
end $$;
rollback;

-- G1f) Doğrudan DB oturumu (Dashboard SQL Editor / cron; SET ROLE yok)
-- backoffice olarak is_verified yazabilir.
begin;
update public.b2b_supplier_shops set is_verified = true
  where id = '20000000-0000-4000-8000-000000000011';
do $$ begin
  if not (select is_verified from public.b2b_supplier_shops where id = '20000000-0000-4000-8000-000000000011') then
    raise exception 'G1f: postgres oturumu is_verified yazamadı';
  end if;
  raise notice 'PASS 11-G1f postgres oturumu (backoffice) is_verified';
end $$;
rollback;

-- G1g) authenticated: helper'ı çağıramaz; SECURITY DEFINER trigger içinde
-- `role` GUC'u çağıranınki (authenticated) kalır → guard reddeder.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$ begin
  begin
    perform public.b2b_is_privileged_session();
    raise exception 'G1g: helper authenticated rolüne açık';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.b2b_supplier_shops set is_verified = true
      where id = '20000000-0000-4000-8000-000000000011';
    raise exception 'G1g: authenticated sahip is_verified yazabildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 11-G1g authenticated ayrıcalıksız (helper kapalı + guard)';
end $$;
rollback;

-- G2) Tedarikçi INSERT'te accepted/status zorla yazamaz → sent/false'a çekilir.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message, status, accepted)
values ('40000000-0000-4000-8000-000000000093', '30000000-0000-4000-8000-000000000003',
        '20000000-0000-4000-8000-000000000009', 'A → R3 sahte kabul', 'accepted', true);
do $$
declare r record;
begin
  select status, accepted into r from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000093';
  if r.status <> 'sent' or r.accepted then
    raise exception 'G2: insert guard çalışmadı (status=% accepted=%)', r.status, r.accepted;
  end if;
  -- open → answered geçişi (trigger, GUC ile) guard'a takılmadı:
  if (select status from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000003') <> 'answered' then
    raise exception 'G2b: open→answered geçişi kırıldı';
  end if;
  raise notice 'PASS 11-G2 reply insert guard + open→answered';
end $$;
commit;

-- G3) Alıcı accepted_reply_id / buyer_id / geçersiz status yazamaz; kapatabilir.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    update public.b2b_quote_requests set accepted_reply_id = '40000000-0000-4000-8000-000000000092'
      where id = '30000000-0000-4000-8000-000000000002';
    raise exception 'G3a: alıcı accepted_reply_id yazabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.b2b_quote_requests set buyer_id = '00000000-0000-4000-8000-000000000013'
      where id = '30000000-0000-4000-8000-000000000002';
    raise exception 'G3b: alıcı buyer_id değiştirebildi';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.b2b_quote_requests set status = 'answered'
      where id = '30000000-0000-4000-8000-000000000004';
    raise exception 'G3c: alıcı doğrudan answered yazabildi';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.b2b_quote_requests set status = 'open'
      where id = '30000000-0000-4000-8000-000000000006';
    raise exception 'G3d: kapalı talep yeniden açılabildi';
  exception when insufficient_privilege then null;
  end;
  update public.b2b_quote_requests set status = 'cancelled'
    where id = '30000000-0000-4000-8000-000000000004';
  if (select status from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000004') <> 'cancelled' then
    raise exception 'G3e: alıcı iptal edemedi';
  end if;
  raise notice 'PASS 11-G3 talep kolon/durum guard';
end $$;
rollback;

-- G4) Çift teklif (aynı mağaza, aynı talep) → unique_violation.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message)
    values ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000009', 'tekrar');
    raise exception 'G4: çift teklif kabul edildi';
  exception when unique_violation then null;
  end;
  -- Karar verilmiş talebe (R1) yeni teklif → RLS (b2b_request_accepts_reply=false).
  begin
    insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message)
    values ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000012', 'geç');
    raise exception 'G4b: karar verilmiş talebe teklif kabul edildi';
  exception when insufficient_privilege then null;
  end;
  -- Başka mağaza adına teklif → RLS.
  begin
    insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message)
    values ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000011', 'sahte');
    raise exception 'G4c: başka mağaza adına teklif kabul edildi';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 11-G4 çift / geç / sahte teklif reddi';
end $$;
rollback;

-- G5) Yetkisiz kabul: tedarikçi veya başka alıcı accept RPC'sini çağıramaz.
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    perform public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000092');
    raise exception 'G5a: tedarikçi kendi teklifini kabul edebildi';
  exception when others then
    if sqlerrm not like '%not your request%' then raise; end if;
  end;
  raise notice 'PASS 11-G5a tedarikçi kabul edemez';
end $$;
rollback;

begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000013', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    perform public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000092');
    raise exception 'G5b: başka alıcı kabul edebildi';
  exception when others then
    if sqlerrm not like '%not your request%' and sqlerrm not like '%reply not found%' then raise; end if;
  end;
  raise notice 'PASS 11-G5b başka alıcı kabul edemez';
end $$;
rollback;

-- G6) Meşru kabul: R8 (yeni, Maya) → A cevaplar, alıcı seçer → accepted +
-- bildirim (postgres ile sayılır; RLS alıcıya başkasının bildirimini göstermez)
-- + ikinci kabul reddi. KALICI (12: u9 için 'won' satırı).
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000008', auth.uid(), 'category', 'Maya', '10 koli', 'Bursa', 'open');
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_replies (id, quote_request_id, supplier_shop_id, message)
values ('40000000-0000-4000-8000-000000000098', '30000000-0000-4000-8000-000000000008',
        '20000000-0000-4000-8000-000000000009', 'A → R8');
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  perform public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000098');
  begin
    perform public.b2b_accept_quote_reply('40000000-0000-4000-8000-000000000098');
    raise exception 'G6d: ikinci kabul kabul edildi';
  exception when others then
    if sqlerrm not like '%already decided%' then raise; end if;
  end;
end $$;
commit;
do $$
declare n int;
begin
  if (select accepted_reply_id from public.b2b_quote_requests where id = '30000000-0000-4000-8000-000000000008')
     <> '40000000-0000-4000-8000-000000000098' then
    raise exception 'G6a: accepted_reply_id yazılmadı';
  end if;
  if not (select accepted from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000098')
     or (select status from public.b2b_quote_replies where id = '40000000-0000-4000-8000-000000000098') <> 'accepted' then
    raise exception 'G6b: reply accepted/status olmadı';
  end if;
  select count(*) into n from public.notifications
   where recipient_id = '00000000-0000-4000-8000-000000000009'
     and type = 'b2b_quote_reply_accepted' and entity_id = '30000000-0000-4000-8000-000000000008';
  if n <> 1 then raise exception 'G6c: kabul bildirimi % (1)', n; end if;
  raise notice 'PASS 11-G6 meşru kabul + bildirim + idempotent red';
end $$;

-- G7) Kota: lansman kapalıyken Free toptancı (u12) ayda 3 cevap; 4. reddedilir.
update public.app_runtime_config set value = 'null'::jsonb, updated_at = now()
  where key = 'supplier_launch_free_start';
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
insert into public.b2b_quote_requests (id, buyer_id, target_type, category, quantity, city, status) values
  ('30000000-0000-4000-8000-000000000071', auth.uid(), 'category', 'Ambalaj', '1', 'İzmir', 'open'),
  ('30000000-0000-4000-8000-000000000072', auth.uid(), 'category', 'Ambalaj', '1', 'İzmir', 'open'),
  ('30000000-0000-4000-8000-000000000073', auth.uid(), 'category', 'Ambalaj', '1', 'İzmir', 'open'),
  ('30000000-0000-4000-8000-000000000074', auth.uid(), 'category', 'Ambalaj', '1', 'İzmir', 'open');
commit;
begin;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000012', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  if public.effective_supplier_plan(auth.uid()) <> 'free' then
    raise exception 'G7 ön koşul: u12 free olmalı (%)', public.effective_supplier_plan(auth.uid());
  end if;
  insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message) values
    ('30000000-0000-4000-8000-000000000071', '20000000-0000-4000-8000-000000000012', '1'),
    ('30000000-0000-4000-8000-000000000072', '20000000-0000-4000-8000-000000000012', '2'),
    ('30000000-0000-4000-8000-000000000073', '20000000-0000-4000-8000-000000000012', '3');
  begin
    insert into public.b2b_quote_replies (quote_request_id, supplier_shop_id, message) values
      ('30000000-0000-4000-8000-000000000074', '20000000-0000-4000-8000-000000000012', '4');
    raise exception 'G7: aylık 3 kota aşıldı';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS 11-G7 aylık cevap kotası';
end $$;
rollback;
update public.app_runtime_config
  set value = to_jsonb((now() - interval '1 day')::text), updated_at = now()
  where key = 'supplier_launch_free_start';
