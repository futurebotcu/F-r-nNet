-- B2B Lead Sonrası Temas + Anlaşma:
--   1) Teklif kabul (accepted_reply_id + reply.accepted) — buyer-only RPC.
--   2) Lead'e bağlı mini takip mesajları (b2b_quote_lead_messages) — definer RPC.
-- Genel chat değil; yalnız ilgili lead bağlamında. Telefon/kişisel bilgi otomatik
-- sızmaz. (Production'a MCP apply_migration ile uygulanacak; repo mirror.)

-- ===== 1) Teklif kabul / anlaşma =====
alter table public.b2b_quote_requests
  add column if not exists accepted_reply_id uuid references public.b2b_quote_replies(id);
alter table public.b2b_quote_replies
  add column if not exists accepted boolean not null default false;

-- Buyer kendi talebindeki bir teklifi kabul eder; tek teklif seçilebilir.
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
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select qr.id, qr.buyer_id, qr.status
    into v_req, v_buyer, v_status
  from public.b2b_quote_replies rep
  join public.b2b_quote_requests qr on qr.id = rep.quote_request_id
  where rep.id = p_reply_id;
  if v_req is null then raise exception 'reply not found'; end if;
  if v_buyer <> v_uid then raise exception 'not your request'; end if;
  if v_status not in ('open', 'answered') then raise exception 'request not active'; end if;

  update public.b2b_quote_requests
     set accepted_reply_id = p_reply_id, updated_at = now()
   where id = v_req;
  update public.b2b_quote_replies
     set accepted = (id = p_reply_id)
   where quote_request_id = v_req;
end;
$$;
revoke execute on function public.b2b_accept_quote_reply(uuid) from public, anon;
grant execute on function public.b2b_accept_quote_reply(uuid) to authenticated;

-- ===== 2) Lead takip mesajları =====
create table if not exists public.b2b_quote_lead_messages (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.b2b_quote_leads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('buyer', 'supplier')),
  message text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_b2b_lead_msg_lead on public.b2b_quote_lead_messages(lead_id, created_at);

alter table public.b2b_quote_lead_messages enable row level security;

-- SELECT: yalnız lead'in tarafları (alıcı veya mağaza sahibi). INSERT yok → RPC.
drop policy if exists b2b_lead_msg_select on public.b2b_quote_lead_messages;
create policy b2b_lead_msg_select on public.b2b_quote_lead_messages
  for select to authenticated
  using (
    lead_id in (
      select id from public.b2b_quote_leads
      where buyer_id = auth.uid()
         or supplier_shop_id in (
           select id from public.b2b_supplier_shops where owner_id = auth.uid()
         )
    )
  );

-- Mesaj gönderme RPC: sender_role UI'dan güvenilmez; lead üyeliğinden türetilir.
create or replace function public.b2b_send_lead_message(
  p_lead_id uuid,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_buyer uuid;
  v_shop uuid;
  v_role text;
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if coalesce(trim(p_message), '') = '' then raise exception 'empty message'; end if;

  select buyer_id, supplier_shop_id into v_buyer, v_shop
  from public.b2b_quote_leads where id = p_lead_id;
  if v_buyer is null then raise exception 'lead not found'; end if;

  if v_buyer = v_uid then
    v_role := 'buyer';
  elsif exists (select 1 from public.b2b_supplier_shops where id = v_shop and owner_id = v_uid) then
    v_role := 'supplier';
  else
    raise exception 'not a participant';
  end if;

  insert into public.b2b_quote_lead_messages(lead_id, sender_id, sender_role, message)
  values (p_lead_id, v_uid, v_role, trim(p_message))
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.b2b_send_lead_message(uuid, text) from public, anon;
grant execute on function public.b2b_send_lead_message(uuid, text) to authenticated;
