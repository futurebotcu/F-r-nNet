-- Anlaşmalı İş Yerleri — service_role grant mirror (hotfix kalıcılaştırma).
--
-- Bulgu (2026-07-06 mail kontrol testi): Bu projede MCP/migration ile açılan
-- yeni tablolara default privileges service_role'e İŞLEMİYOR (emsal:
-- grant_service_role_push_tables). partner_* tablolarında service_role
-- yetkisizdi → send-partner-business-application-email edge function'ı
-- "not found" dönüyor, backoffice/service-role yayınlama akışı çalışmıyordu.
-- Hotfix canlıya execute_sql ile uygulandı; bu migration repo mirror'ıdır
-- (idempotent — grant tekrarları zararsız).
--
-- KAPSAM SINIRI: yalnız service_role. anon/public/authenticated grant'ları,
-- RLS policy'leri, RPC'ler ve edge function DEĞİŞMEZ (client güvenliği aynı;
-- service_role zaten RLS'i baypas eden backoffice roldür).
--
-- DERS: yeni tablo açan her migration'a service_role grant'ı eklenmeli.

grant select, insert, update, delete
  on table public.partner_businesses to service_role;
grant select, insert, update, delete
  on table public.partner_business_applications to service_role;
