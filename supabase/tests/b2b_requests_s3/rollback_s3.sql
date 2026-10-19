-- S3 migration GERİ ALMA (çalıştırılabilir). Veri kaybı yok: yalnız S3'ün
-- eklediği trigger/fonksiyon/index'ler düşer, accept ve mark_answered
-- fonksiyonları S3 ÖNCESİ (20260622160000 / 20260618120000) tanımlarına döner.
-- İletişim kolonları KORUNUR (varsayılan; veri silmemek için). Kolonları da
-- kaldırmak istenirse dosya sonundaki yorumlu blok.
--
-- Harness bu dosyayı migration sonrası uygular ve 16_rollback_asserts.sql ile
-- S3 öncesi davranışın geri geldiğini doğrular. Production'da yalnız ürün
-- sahibi onayıyla, migration geri alınacaksa kullanılır.

drop trigger if exists trg_notify_b2b_quote_request_created on public.b2b_quote_requests;
drop function if exists public.notify_b2b_quote_request_created();
drop index if exists public.notifications_b2b_qr_dedupe_idx;

drop function if exists public.b2b_supplier_request_counts();
drop function if exists public.b2b_open_quote_requests_page(text[], text[], boolean, integer, integer);
drop function if exists public.b2b_my_replied_requests();

drop index if exists public.idx_b2b_qr_open_cat_city;
drop index if exists public.idx_b2b_replies_shop_created;
drop index if exists public.idx_b2b_shops_owner_active;

drop trigger if exists trg_b2b_qr_guard_columns on public.b2b_quote_requests;
drop function if exists public.b2b_qr_guard_columns();
drop trigger if exists trg_b2b_replies_guard_insert on public.b2b_quote_replies;
drop function if exists public.b2b_replies_guard_insert();
drop trigger if exists trg_b2b_shops_guard_columns on public.b2b_supplier_shops;
drop function if exists public.b2b_shops_guard_columns();

-- b2b_mark_request_answered → 20260618120000_b2b_v1_closing.sql tanımı
create or replace function public.b2b_mark_request_answered()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.b2b_quote_requests
     set status = 'answered', updated_at = now()
   where id = new.quote_request_id
     and status = 'open';
  return new;
end;
$$;

-- b2b_accept_quote_reply → 20260622160000_b2b_reply_hardening.sql tanımı
-- (DİKKAT: bu tanım S3'te düzeltilen yarış koşulunu geri getirir.)
create or replace function public.b2b_accept_quote_reply(p_reply_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_req uuid;
  v_buyer uuid;
  v_status text;
  v_accepted uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select qr.id, qr.buyer_id, qr.status, qr.accepted_reply_id
    into v_req, v_buyer, v_status, v_accepted
  from public.b2b_quote_replies rep
  join public.b2b_quote_requests qr on qr.id = rep.quote_request_id
  where rep.id = p_reply_id;
  if v_req is null then raise exception 'reply not found'; end if;
  if v_buyer <> v_uid then raise exception 'not your request'; end if;
  if v_status not in ('open', 'answered') then raise exception 'request not active'; end if;
  if v_accepted is not null then raise exception 'already decided'; end if;

  perform set_config('b2b.reply_write', 'on', true);

  update public.b2b_quote_requests
     set accepted_reply_id = p_reply_id, updated_at = now()
   where id = v_req;

  update public.b2b_quote_replies
     set accepted = (id = p_reply_id),
         status   = case when id = p_reply_id then 'accepted' else 'declined' end
   where quote_request_id = v_req;
end;
$$;
revoke execute on function public.b2b_accept_quote_reply(uuid) from public, anon;
grant execute on function public.b2b_accept_quote_reply(uuid) to authenticated;

-- İsteğe bağlı: iletişim kolonlarını da kaldır (VERİ KAYBI: yalnız bu 4 alan).
-- alter table public.b2b_supplier_shops drop constraint if exists b2b_shops_contact_len;
-- alter table public.b2b_supplier_shops
--   drop column if exists phone, drop column if exists whatsapp,
--   drop column if exists website, drop column if exists address;
