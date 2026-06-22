-- ============================================================
-- B2B Hardening (PR-2) — teklif (reply) bütünlüğü + kabul lifecycle + dedup
-- Audit: FN-AUDIT-003 / FN-AUDIT-014 / FN-AUDIT-015
-- ADDITIF. Drop/delete YOK (yalnız idempotent create-or-replace + 1 unique).
-- Production'a apply ONAY ile yapılır (bu dosya repo mirror).
-- ============================================================

-- ── FN-AUDIT-015: aynı talebe (quote_request_id) aynı mağazadan (supplier_shop_id)
--    yalnız TEK teklif. Mükerrer reply + spam bildirim engellenir.
--    NOT: Apply öncesi mevcut mükerrer satır kontrolü gerekir (boşsa sorunsuz).
alter table public.b2b_quote_replies
  add constraint b2b_quote_replies_unique_supplier
  unique (quote_request_id, supplier_shop_id);

-- ── FN-AUDIT-003: b2b_quote_replies.status/accepted yalnız buyer-only accept
--    RPC üzerinden değişebilir. Postgres RLS kolon-bazlı kısıt yapamadığı için
--    BEFORE UPDATE trigger ile korunur. Tedarikçi kendi reply'ında
--    message/price_note/delivery_note değiştirebilir AMA status/accepted'i DEĞİL.
--    Accept RPC, transaction-local `b2b.reply_write=on` flag'i ile izinlidir.
create or replace function public.b2b_replies_guard_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.status is distinct from old.status
       or new.accepted is distinct from old.accepted)
     and coalesce(current_setting('b2b.reply_write', true), '') <> 'on' then
    raise exception 'reply status/accepted is buyer-controlled';
  end if;
  return new;
end;
$$;
revoke execute on function public.b2b_replies_guard_status()
  from public, anon, authenticated;

drop trigger if exists trg_b2b_replies_guard_status on public.b2b_quote_replies;
create trigger trg_b2b_replies_guard_status
  before update on public.b2b_quote_replies
  for each row execute function public.b2b_replies_guard_status();

-- ── FN-AUDIT-003 + 014: kabul = tek meşru status/accepted yazarı. Seçilen
--    teklif accepted+status='accepted', diğerleri 'declined'. accepted_reply_id
--    ile talep "karara bağlandı" işaretlenir (status DEĞİŞMEZ → kabul-sonrası
--    lead/iletişim create_b2b_quote_lead'in open/answered şartını bozmaz).
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

  -- guard trigger için yetki (yalnız bu transaction).
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

-- ── FN-AUDIT-014: karara bağlanmış (accepted_reply_id) talep YENİ teklif kabul
--    etmez. b2b_replies_insert with-check bu helper'ı kullanır → kabul sonrası
--    tedarikçiler artık teklif veremez.
create or replace function public.b2b_request_accepts_reply(p_request_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists(
    select 1 from public.b2b_quote_requests
    where id = p_request_id
      and status in ('open', 'answered')
      and accepted_reply_id is null
  );
$$;
revoke execute on function public.b2b_request_accepts_reply(uuid) from public, anon;
grant execute on function public.b2b_request_accepts_reply(uuid) to authenticated;

-- ── FN-AUDIT-014: Teklif Ağı'ndan karara bağlanmışları çıkar (function + view).
--    Tedarikçi açık talepler listesinde decided talep görünmez → ağ kirlenmez.
create or replace function public.b2b_open_quote_requests()
returns table(
  id uuid, target_type text, target_id uuid, category text, quantity text,
  city text, district text, buyer_type text, delivery_time text, note text,
  status text, created_at timestamptz, updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select id, target_type, target_id, category, quantity, city, district,
         buyer_type, delivery_time, note, status, created_at, updated_at
  from public.b2b_quote_requests
  where status not in ('closed', 'cancelled')
    and accepted_reply_id is null;
$$;

create or replace view public.b2b_open_quote_requests
  with (security_invoker = false) as
  select id, target_type, target_id, category, quantity, city, district,
         buyer_type, delivery_time, note, status, created_at, updated_at
  from public.b2b_quote_requests
  where status not in ('closed', 'cancelled')
    and accepted_reply_id is null;
grant select on public.b2b_open_quote_requests to authenticated;
