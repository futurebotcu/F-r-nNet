-- B2B S3 harness ek katmanı (prod_replica_schema.sql ÜZERİNE uygulanır).
--
-- * Replikadaki B2B stub tabloları gerçek migration zinciri için düşürülür.
-- * auth.role() mock'u (Supabase'de JWT role claim'i; burada GUC).
-- * Ek test kullanıcıları: u11/u12 = ikinci/üçüncü toptancı, u13 = ticari alıcı.
-- ASLA production'a çalıştırmayın.

drop table if exists public.b2b_quote_replies cascade;
drop table if exists public.b2b_campaigns cascade;
drop table if exists public.b2b_products cascade;
drop table if exists public.b2b_supplier_shops cascade;

create or replace function auth.role()
returns text language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.role', true), '');
$$;
grant execute on function auth.role() to public;

insert into auth.users (id) values
  ('00000000-0000-4000-8000-000000000011'),
  ('00000000-0000-4000-8000-000000000012'),
  ('00000000-0000-4000-8000-000000000013')
on conflict do nothing;

insert into public.profiles (id, display_name, account_type) values
  ('00000000-0000-4000-8000-000000000011', 'Toptancı On Bir', 'wholesaler'),
  ('00000000-0000-4000-8000-000000000012', 'Toptancı On İki', 'wholesaler'),
  ('00000000-0000-4000-8000-000000000013', 'Alıcı On Üç', 'commercial')
on conflict do nothing;

-- Bazı replika fonksiyonları (my_entitlement vb.) feed/notification stub'larına
-- değinebilir; B2B testleri için gerekli minimum: notifications (replikada var).
