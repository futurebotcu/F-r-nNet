-- ============================================================
-- Advisor Security Cleanup (PR-5) — düşük riskli hijyen
-- Audit: advisor P2/P3 (anon/auth executable helpers, public bucket listing,
--        inert pg_net trigger)
-- ADDITIF/odaklı. Production'a apply ONAY ile (bu dosya repo mirror).
-- ============================================================

-- ─────────────────────────────────────────────────────────
-- 1) Trigger-only / event-trigger fonksiyonlarında EXECUTE revoke.
--    Bunlar yalnız trigger olarak çalışır; RPC olarak çağrılmaları gereksiz.
--    Trigger çalışması EXECUTE grant'ından BAĞIMSIZDIR (PG trigger-fire'da
--    EXECUTE kontrolü yapmaz) → revoke trigger'ı bozmaz. Gerçek RPC'lerimiz
--    (driver_add_*, b2b_*, register_push_token…) returns trigger DEĞİL → DOKUNULMAZ.
-- ─────────────────────────────────────────────────────────
revoke execute on function public.b2b_set_updated_at() from public, anon, authenticated;
revoke execute on function public.bump_conversation_updated_at() from public, anon, authenticated;
revoke execute on function public.calculate_dealer_delivery_item() from public, anon, authenticated;
revoke execute on function public.calculate_recipe_calculation() from public, anon, authenticated;
revoke execute on function public.calculate_waste_entry() from public, anon, authenticated;
revoke execute on function public.compute_dealer_delivery_remaining() from public, anon, authenticated;
revoke execute on function public.feed_guard_server_counters() from public, anon, authenticated;
revoke execute on function public.job_conversations_guard_lifecycle() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────
-- 2) Public bucket SELECT policy: toplu listeleme (enumeration) → owner-scoped.
--    Public URL (getPublicUrl) RLS-bağımsızdır → görsel ERİŞİMİ BOZULMAZ.
--    App `.list()` kullanmıyor; SELECT yalnız listeleme içindi. Sahip kendi
--    yüklemelerini API'den listeleyebilir; çapraz-kullanıcı enumeration kapanır.
--    chat-media (private + membership-gated) DEĞİŞMEZ.
-- ─────────────────────────────────────────────────────────
drop policy if exists avatars_storage_select on storage.objects;
create policy avatars_storage_select on storage.objects
  for select to public
  using (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists feed_media_storage_select on storage.objects;
create policy feed_media_storage_select on storage.objects
  for select to public
  using (bucket_id = 'feed-media' and owner = auth.uid());

drop policy if exists market_media_select_authenticated on storage.objects;
create policy market_media_select_authenticated on storage.objects
  for select to authenticated
  using (bucket_id = 'market-media' and owner = auth.uid());

drop policy if exists story_media_select_authenticated on storage.objects;
create policy story_media_select_authenticated on storage.objects
  for select to authenticated
  using (bucket_id = 'story-media' and owner = auth.uid());

-- ─────────────────────────────────────────────────────────
-- 3) İnert pg_net notification trigger temizliği.
--    Vault (push_dispatch_url/key) BOŞ → bu trigger no-op (HTTP yapmaz).
--    Aktif yol: Database Webhook push_dispatch_on_notification_insert (DEĞİŞMEZ).
--    Dedup tablosu (notification_push_deliveries) ve edge function DEĞİŞMEZ.
-- ─────────────────────────────────────────────────────────
drop trigger if exists trg_notifications_push_dispatch on public.notifications;
drop function if exists public.dispatch_notification_push();
