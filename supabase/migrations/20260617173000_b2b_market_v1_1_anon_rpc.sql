-- ============================================================
-- FırınNet — B2B Pazar V1.1: Teklif Ağı anonimliği RPC'ye taşındı
-- Tarih: 2026-06-17
-- Amaç:
--   • V1'deki security-definer VIEW (b2b_open_quote_requests) advisor 0010'da
--     ERROR seviyesinde işaretleniyordu. Aynı anonimlik garantisini (buyer_id
--     ASLA dönmez) korumak için VIEW yerine security-definer RPC FONKSİYONU
--     kullanılır — bu, projenin mevcut RPC desenine uygundur (0029 WARN, ERROR
--     değil; public_profile_detail vb. ile aynı sınıf).
--   • Tablo RLS değişmez: b2b_quote_requests SELECT yalnız buyer_id=auth.uid().
--     Tedarikçiler talepleri yalnız bu RPC'den (buyer_id'siz) okur.
-- ============================================================

drop view if exists public.b2b_open_quote_requests;

create or replace function public.b2b_open_quote_requests()
returns table (
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
  where status <> 'closed';
$$;

revoke all on function public.b2b_open_quote_requests() from public, anon;
grant execute on function public.b2b_open_quote_requests() to authenticated;
