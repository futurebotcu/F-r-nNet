-- 20260619120000_in_app_notification_events.sql'in YALNIZ B2B alt kümesi.
-- Tam dosya feed_posts/feed_comments/profile_follows trigger'ları içerdiği için
-- harness'ta uygulanamaz; buradaki tanımlar canlı DB'den pg_get_functiondef ile
-- birebir alındı (2026-10-17). ASLA production'a çalıştırmayın.

CREATE OR REPLACE FUNCTION public.notify_b2b_accept()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid;
begin
  select s.owner_id into v_owner
  from public.b2b_quote_replies r
  join public.b2b_supplier_shops s on s.id = r.supplier_shop_id
  where r.id = new.accepted_reply_id;
  if v_owner is not null and v_owner is distinct from new.buyer_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values (v_owner, null, 'b2b_quote_reply_accepted', 'Teklifin seçildi',
       'Bir alıcı teklifinle ilerlemek istiyor.', 'quote_request', new.id, '/pazar');
  end if;
  return new;
end; $function$;
revoke execute on function public.notify_b2b_accept() from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_b2b_lead()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid;
begin
  select owner_id into v_owner from public.b2b_supplier_shops where id = new.supplier_shop_id;
  if v_owner is not null and v_owner is distinct from new.buyer_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values (v_owner, null, 'b2b_quote_lead_created', 'Teklifinle ilgilenen var',
       'Bir alıcı teklifinle ilgileniyor.', 'quote_lead', new.id, '/pazar');
  end if;
  return new;
end; $function$;
revoke execute on function public.notify_b2b_lead() from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_b2b_lead_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_buyer uuid; v_shop uuid; v_req uuid; v_owner uuid; v_recipient uuid; v_route text;
begin
  select buyer_id, supplier_shop_id, quote_request_id into v_buyer, v_shop, v_req
  from public.b2b_quote_leads where id = new.lead_id;
  if v_buyer is null then return new; end if;
  select owner_id into v_owner from public.b2b_supplier_shops where id = v_shop;
  if new.sender_role = 'buyer' then
    v_recipient := v_owner; v_route := '/pazar';
  else
    v_recipient := v_buyer; v_route := '/pazar/tekliflerim/' || v_req::text;
  end if;
  if v_recipient is not null and v_recipient is distinct from new.sender_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values (v_recipient, null, 'b2b_quote_lead_message_created', 'Teklif görüşmende yeni mesaj',
       'Teklif görüşmende yeni bir mesaj var.', 'quote_lead', new.lead_id, v_route);
  end if;
  return new;
end; $function$;
revoke execute on function public.notify_b2b_lead_message() from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_b2b_reply()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_buyer uuid; v_owner uuid;
begin
  select buyer_id into v_buyer from public.b2b_quote_requests where id = new.quote_request_id;
  select owner_id into v_owner from public.b2b_supplier_shops where id = new.supplier_shop_id;
  if v_buyer is not null and v_buyer is distinct from v_owner then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values (v_buyer, null, 'b2b_quote_reply_created', 'Talebine yeni teklif geldi',
       'Bir tedarikçi talebine teklif verdi.', 'quote_request', new.quote_request_id,
       '/pazar/tekliflerim/' || new.quote_request_id::text);
  end if;
  return new;
end; $function$;
revoke execute on function public.notify_b2b_reply() from public, anon, authenticated;

drop trigger if exists trg_notify_b2b_reply on public.b2b_quote_replies;
CREATE TRIGGER trg_notify_b2b_reply AFTER INSERT ON public.b2b_quote_replies FOR EACH ROW EXECUTE FUNCTION notify_b2b_reply();
drop trigger if exists trg_notify_b2b_lead on public.b2b_quote_leads;
CREATE TRIGGER trg_notify_b2b_lead AFTER INSERT ON public.b2b_quote_leads FOR EACH ROW EXECUTE FUNCTION notify_b2b_lead();
drop trigger if exists trg_notify_b2b_lead_message on public.b2b_quote_lead_messages;
CREATE TRIGGER trg_notify_b2b_lead_message AFTER INSERT ON public.b2b_quote_lead_messages FOR EACH ROW EXECUTE FUNCTION notify_b2b_lead_message();
drop trigger if exists trg_notify_b2b_accept on public.b2b_quote_requests;
CREATE TRIGGER trg_notify_b2b_accept AFTER UPDATE ON public.b2b_quote_requests FOR EACH ROW WHEN (((new.accepted_reply_id IS DISTINCT FROM old.accepted_reply_id) AND (new.accepted_reply_id IS NOT NULL))) EXECUTE FUNCTION notify_b2b_accept();
