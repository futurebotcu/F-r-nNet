-- Birleşik In-App Bildirim Merkezi — event üretimi (server-side trigger'lar).
--
-- Altyapı zaten mevcut: public.notifications tablosu + RLS (select_own/update_own)
-- + Flutter notification merkezi/zil/badge/route navigasyon + 1 çalışan event
-- (group_join_request). Bu migration EKSİK olan 6 olayın üretimini ekler.
--
-- Tasarım:
--  * Tüm trigger fonksiyonları SECURITY DEFINER + search_path='' → notifications'a
--    güvenli INSERT (tablonun INSERT policy'si yok; client başkası adına üretemez).
--  * actor != recipient ise üretilir (kendine bildirim yok).
--  * GÜVENLİK/ANONİMLİK: B2B bildirimlerinde actor_id = NULL ve metin generic
--    (telefon/ad/açık adres/mesaj içeriği YAZILMAZ). Sosyal (yorum/takip)
--    bildirimlerinde actor_id set (sosyal anonim değil).
--  * route alanı mevcut navigasyon için doldurulur (alıcı → derin teklif detayı).
-- (Production'a MCP apply_migration ile uygulanacak; repo mirror.)

-- ===== 1) B2B teklif geldi → alıcıya =====
create or replace function public.notify_b2b_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid;
  v_owner uuid;
begin
  select buyer_id into v_buyer from public.b2b_quote_requests where id = new.quote_request_id;
  select owner_id into v_owner from public.b2b_supplier_shops where id = new.supplier_shop_id;
  if v_buyer is not null and v_buyer is distinct from v_owner then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_buyer, null, 'b2b_quote_reply_created', 'Talebine yeni teklif geldi',
       'Bir tedarikçi talebine teklif verdi.', 'quote_request', new.quote_request_id,
       '/pazar/tekliflerim/' || new.quote_request_id::text);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_b2b_reply on public.b2b_quote_replies;
create trigger trg_notify_b2b_reply
  after insert on public.b2b_quote_replies
  for each row execute function public.notify_b2b_reply();

-- ===== 2) B2B lead (ilgi) geldi → tedarikçiye =====
create or replace function public.notify_b2b_lead()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.b2b_supplier_shops where id = new.supplier_shop_id;
  if v_owner is not null and v_owner is distinct from new.buyer_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_owner, null, 'b2b_quote_lead_created', 'Teklifinle ilgilenen var',
       'Bir alıcı teklifinle ilgileniyor.', 'quote_lead', new.id, '/pazar');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_b2b_lead on public.b2b_quote_leads;
create trigger trg_notify_b2b_lead
  after insert on public.b2b_quote_leads
  for each row execute function public.notify_b2b_lead();

-- ===== 3) B2B lead mesajı → karşı tarafa =====
create or replace function public.notify_b2b_lead_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid;
  v_shop uuid;
  v_req uuid;
  v_owner uuid;
  v_recipient uuid;
  v_route text;
begin
  select buyer_id, supplier_shop_id, quote_request_id
    into v_buyer, v_shop, v_req
  from public.b2b_quote_leads where id = new.lead_id;
  if v_buyer is null then return new; end if;
  select owner_id into v_owner from public.b2b_supplier_shops where id = v_shop;

  if new.sender_role = 'buyer' then
    v_recipient := v_owner;
    v_route := '/pazar';
  else
    v_recipient := v_buyer;
    v_route := '/pazar/tekliflerim/' || v_req::text;
  end if;

  if v_recipient is not null and v_recipient is distinct from new.sender_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_recipient, null, 'b2b_quote_lead_message_created', 'Teklif görüşmende yeni mesaj',
       'Teklif görüşmende yeni bir mesaj var.', 'quote_lead', new.lead_id, v_route);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_b2b_lead_message on public.b2b_quote_lead_messages;
create trigger trg_notify_b2b_lead_message
  after insert on public.b2b_quote_lead_messages
  for each row execute function public.notify_b2b_lead_message();

-- ===== 4) Teklif kabul edildi → tedarikçiye =====
create or replace function public.notify_b2b_accept()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select s.owner_id into v_owner
  from public.b2b_quote_replies r
  join public.b2b_supplier_shops s on s.id = r.supplier_shop_id
  where r.id = new.accepted_reply_id;
  if v_owner is not null and v_owner is distinct from new.buyer_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_owner, null, 'b2b_quote_reply_accepted', 'Teklifin seçildi',
       'Bir alıcı teklifinle ilerlemek istiyor.', 'quote_request', new.id, '/pazar');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_b2b_accept on public.b2b_quote_requests;
create trigger trg_notify_b2b_accept
  after update on public.b2b_quote_requests
  for each row
  when (new.accepted_reply_id is distinct from old.accepted_reply_id
        and new.accepted_reply_id is not null)
  execute function public.notify_b2b_accept();

-- ===== 5) Sosyal yorum → paylaşım sahibine =====
create or replace function public.notify_social_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.feed_posts where id = new.post_id;
  if v_owner is not null and v_owner is distinct from new.owner_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (v_owner, new.owner_id, 'social_comment_created', 'Paylaşımına yorum geldi',
       'Bir paylaşımına yeni yorum yapıldı.', 'feed_post', new.post_id, '/community');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_social_comment on public.feed_comments;
create trigger trg_notify_social_comment
  after insert on public.feed_comments
  for each row execute function public.notify_social_comment();

-- ===== 6) Takip → takip edilen kullanıcıya =====
create or replace function public.notify_social_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.following_id is distinct from new.follower_id then
    insert into public.notifications
      (recipient_id, actor_id, type, title, body, entity_type, entity_id, route)
    values
      (new.following_id, new.follower_id, 'social_follow_created', 'Yeni takipçin var',
       'Biri seni takip etmeye başladı.', 'profile', new.follower_id, null);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notify_social_follow on public.profile_follows;
create trigger trg_notify_social_follow
  after insert on public.profile_follows
  for each row execute function public.notify_social_follow();

-- Hijyen: trigger fonksiyonları RPC olarak çağrılmaya AÇIK kalmasın. Trigger
-- ateşlemesi EXECUTE iznine bağlı değildir; revoke güvenliği artırır, davranışı
-- bozmaz.
revoke execute on function public.notify_b2b_reply() from public, anon, authenticated;
revoke execute on function public.notify_b2b_lead() from public, anon, authenticated;
revoke execute on function public.notify_b2b_lead_message() from public, anon, authenticated;
revoke execute on function public.notify_b2b_accept() from public, anon, authenticated;
revoke execute on function public.notify_social_comment() from public, anon, authenticated;
revoke execute on function public.notify_social_follow() from public, anon, authenticated;
