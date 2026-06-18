-- B2B lead kanalı: teklif cevabı üzerinden "İlgileniyorum / Uygun değil".
-- Telefon yalnız alıcı açık onay verirse paylaşılır (otomatik sızmaz).
-- (Production'a MCP apply_migration ile uygulandı; repo mirror.)

create table if not exists public.b2b_quote_leads (
  id uuid primary key default gen_random_uuid(),
  quote_request_id uuid not null references public.b2b_quote_requests(id) on delete cascade,
  quote_reply_id uuid not null references public.b2b_quote_replies(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  supplier_shop_id uuid not null references public.b2b_supplier_shops(id) on delete cascade,
  status text not null default 'interested' check (status in ('interested', 'rejected')),
  buyer_message text,
  shared_phone text,
  phone_shared boolean not null default false,
  -- Denormalize: tedarikçi RLS ile b2b_quote_requests okuyamaz; RPC (definer)
  -- talep özetini lead'e kopyalar ki "İlgilenenler" kartı gösterebilsin.
  request_category text,
  request_quantity text,
  request_city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (quote_reply_id, buyer_id)
);

create index if not exists idx_b2b_leads_shop on public.b2b_quote_leads(supplier_shop_id);
create index if not exists idx_b2b_leads_request on public.b2b_quote_leads(quote_request_id);
create index if not exists idx_b2b_leads_buyer on public.b2b_quote_leads(buyer_id);

drop trigger if exists trg_b2b_leads_updated on public.b2b_quote_leads;
create trigger trg_b2b_leads_updated before update on public.b2b_quote_leads
  for each row execute function public.b2b_set_updated_at();

alter table public.b2b_quote_leads enable row level security;

-- SELECT: alıcı kendi lead'i; tedarikçi yalnız kendi mağazasına geleni.
drop policy if exists b2b_leads_select on public.b2b_quote_leads;
create policy b2b_leads_select on public.b2b_quote_leads
  for select to authenticated
  using (
    buyer_id = auth.uid()
    or supplier_shop_id in (
      select id from public.b2b_supplier_shops where owner_id = auth.uid()
    )
  );

-- UPDATE: yalnız alıcı kendi lead'ini (interested/rejected). INSERT yok →
-- yalnız güvenli RPC ile eklenir.
drop policy if exists b2b_leads_update on public.b2b_quote_leads;
create policy b2b_leads_update on public.b2b_quote_leads
  for update to authenticated
  using (buyer_id = auth.uid())
  with check (buyer_id = auth.uid());

-- Güvenli lead oluşturma RPC'si: buyer_id ve supplier_shop_id UI'dan
-- güvenilmez; reply + request üzerinden doğrulanır. Telefon yalnız
-- p_phone_shared true ise yazılır.
create or replace function public.create_b2b_quote_lead(
  p_quote_reply_id uuid,
  p_status text default 'interested',
  p_buyer_message text default null,
  p_phone_shared boolean default false,
  p_shared_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_req_id uuid;
  v_buyer uuid;
  v_status text;
  v_shop uuid;
  v_cat text;
  v_qty text;
  v_city text;
  v_lead uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_status not in ('interested', 'rejected') then
    raise exception 'invalid status';
  end if;

  select qr.id, qr.buyer_id, qr.status, rep.supplier_shop_id,
         qr.category, qr.quantity, qr.city
    into v_req_id, v_buyer, v_status, v_shop, v_cat, v_qty, v_city
  from public.b2b_quote_replies rep
  join public.b2b_quote_requests qr on qr.id = rep.quote_request_id
  where rep.id = p_quote_reply_id;

  if v_req_id is null then
    raise exception 'reply not found';
  end if;
  if v_buyer <> v_uid then
    raise exception 'not your request';
  end if;
  if v_status not in ('open', 'answered') then
    raise exception 'request not active';
  end if;

  insert into public.b2b_quote_leads(
    quote_request_id, quote_reply_id, buyer_id, supplier_shop_id,
    status, buyer_message, phone_shared, shared_phone,
    request_category, request_quantity, request_city)
  values (
    v_req_id, p_quote_reply_id, v_uid, v_shop,
    p_status, nullif(p_buyer_message, ''),
    coalesce(p_phone_shared, false),
    case when coalesce(p_phone_shared, false) then nullif(p_shared_phone, '') else null end,
    v_cat, v_qty, v_city)
  returning id into v_lead;

  return v_lead;
end;
$$;

revoke execute on function public.create_b2b_quote_lead(uuid, text, text, boolean, text)
  from public, anon;
grant execute on function public.create_b2b_quote_lead(uuid, text, text, boolean, text)
  to authenticated;
