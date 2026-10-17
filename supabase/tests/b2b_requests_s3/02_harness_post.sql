-- Migration'lar uygulandıktan SONRA: Supabase'de service_role tüm tablolara
-- varsayılan privilege ile erişir (bypassrls + grant). Harness'ta aynı durumu
-- kurar. ASLA production'a çalıştırmayın.
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
