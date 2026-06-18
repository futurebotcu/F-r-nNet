-- B2B hardening: kapalı/iptal talebe teklif (reply) insert engeli.
-- (Production'a MCP apply_migration ile uygulandı; repo mirror.)
--
-- Sorun: b2b_quote_replies insert policy yalnız supplier_shop_id sahipliğini
-- kontrol ediyordu; talep status'unu kontrol etmiyordu. UI/RPC kapalı talepleri
-- gizliyor ama doğrudan API ile closed/cancelled bir talebe reply atılabilirdi.
--
-- Çözüm: SECURITY DEFINER helper ile talep status'unu RLS-bağımsız kontrol et
-- (supplier b2b_quote_requests'i normalde okuyamaz). Insert WITH CHECK'e ekle.

-- Talep yeni teklif kabul ediyor mu? (open/answered) — anonim, yalnız boolean.
create or replace function public.b2b_request_accepts_reply(p_request_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists(
    select 1 from public.b2b_quote_requests
    where id = p_request_id and status in ('open', 'answered')
  );
$$;

-- RLS policy ifadesinde çağrılabilmesi için authenticated execute gerekir.
revoke execute on function public.b2b_request_accepts_reply(uuid) from public, anon;
grant execute on function public.b2b_request_accepts_reply(uuid) to authenticated;

-- Insert policy: mağaza sahipliği + talep aktif (open/answered).
drop policy if exists b2b_replies_insert on public.b2b_quote_replies;
create policy b2b_replies_insert on public.b2b_quote_replies
  for insert to authenticated
  with check (
    supplier_shop_id in (
      select id from public.b2b_supplier_shops where owner_id = auth.uid()
    )
    and public.b2b_request_accepts_reply(quote_request_id)
  );
