-- ============================================================
-- D-1 (PR-6) — Şoför / davet-edilen kullanıcı hesabını silebilsin
-- Audit: account-deletion FK RESTRICT blocker (KVKK / Play compliance)
-- ============================================================
-- Sorun: dealer_drivers.driver_user_id ve dealer_driver_invites.invited_user_id
-- FK'leri ON DELETE RESTRICT idi → bir patrona şoför olarak atanmış VEYA bekleyen
-- daveti olan kullanıcı "Hesabımı Sil" deyince auth.admin.deleteUser FK RESTRICT'e
-- takılıp fail ediyordu (delete-account → delete_failed).
--
-- Çözüm: bu iki FK → ON DELETE CASCADE. Kullanıcı silinince:
--   * dealer_drivers kaydı silinir → dealer_driver_assignments CASCADE ile gider,
--   * dealer_transactions / dealer_deliveries.driver_id ZATEN ON DELETE SET NULL
--     → patronun geçmiş finansal kayıtları KORUNUR (yalnız şofor atfı null olur),
--   * dealer_driver_invites (invited_user_id) kaydı silinir.
--
-- Bu yalnız FK delete-action değişimidir (Postgres'te drop+add gerekir); VERİ/TABLO/
-- KOLON drop'u DEĞİL. owner_id FK'leri (patron) değişmez.
-- (Production'a apply ONAY ile; bu dosya repo mirror.)

-- dealer_drivers.driver_user_id → profiles  (RESTRICT → CASCADE)
alter table public.dealer_drivers
  drop constraint if exists dealer_drivers_driver_user_id_fkey;
alter table public.dealer_drivers
  add constraint dealer_drivers_driver_user_id_fkey
  foreign key (driver_user_id) references public.profiles(id) on delete cascade;

-- dealer_driver_invites.invited_user_id → profiles  (RESTRICT → CASCADE)
alter table public.dealer_driver_invites
  drop constraint if exists dealer_driver_invites_invited_user_id_fkey;
alter table public.dealer_driver_invites
  add constraint dealer_driver_invites_invited_user_id_fkey
  foreign key (invited_user_id) references public.profiles(id) on delete cascade;
