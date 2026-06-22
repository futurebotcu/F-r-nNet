-- ============================================================
-- Push notifications — service_role DML grants (ADDITIVE)
-- ============================================================
-- Bu projede `service_role` push tablolarinda DML grant'ina sahip degildi
-- (yalniz REFERENCES/TRIGGER/TRUNCATE) → push-dispatch edge function (service-
-- role ile calisir) "permission denied for table notifications" aliyordu.
-- Bu migration least-privilege grant'lari ekler. GRANT idempotenttir (drop yok).
--
-- NOT: Bu grant'lar A34 push smoke sirasinda canliya zaten uygulandi; bu dosya
-- repo<->DB drift'ini kapatir (yeniden uygulansa no-op).
-- notification_push_deliveries.id default gen_random_uuid() (sequence yok) →
-- ayrica sequence USAGE grant'i gerekmez.

grant select on public.notifications to service_role;
grant select, update on public.user_push_tokens to service_role;
grant select, insert, update on public.notification_push_deliveries
  to service_role;
