-- B2B V1 kapanış: status lifecycle + reply→answered trigger + RPC + kampanya görseli.
-- (Production'a MCP apply_migration ile uygulandı; repo mirror.)

-- 1) status: open/answered/closed/cancelled
update public.b2b_quote_requests set status = 'answered' where status = 'replied';
alter table public.b2b_quote_requests
  drop constraint if exists b2b_quote_requests_status_check;
alter table public.b2b_quote_requests
  add constraint b2b_quote_requests_status_check
  check (status in ('open', 'answered', 'closed', 'cancelled'));

-- 2) tedarikçi cevap insert → talep 'answered' (yalnız 'open' iken)
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

drop trigger if exists trg_b2b_reply_answered on public.b2b_quote_replies;
create trigger trg_b2b_reply_answered
  after insert on public.b2b_quote_replies
  for each row execute function public.b2b_mark_request_answered();

-- trigger fonksiyonu RPC olarak çağrılamasın (trigger yine çalışır)
revoke execute on function public.b2b_mark_request_answered()
  from public, anon, authenticated;

-- 3) Teklif Ağı RPC: closed VE cancelled hariç (anonim; buyer_id YOK)
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
  where status not in ('closed', 'cancelled');
$$;

-- 4) kampanya görseli
alter table public.b2b_campaigns add column if not exists image_url text;
