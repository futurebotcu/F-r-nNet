# Push Notifications — Runbook (uygulama-dışı / FCM)

Uygulama-dışı (sistem tepsisi) push notification altyapısı. In-app notification
merkezini (`notifications` tablosu + `notify_*` fonksiyonları) **değiştirmez**;
onun dış katmanıdır.

> **Güvenlik:** Bu dokümana veya repoya **hiçbir secret/key/token değeri**
> yazılmaz. Yalnız secret **adları** ve kurulum adımları belgelenir.

## Mimari (uçtan uca)

```
login → cihaz FCM token → register_push_token RPC → user_push_tokens
notify_* (comment/follow/b2b/...) → INSERT notifications
  → Database Webhook (notifications INSERT)
  → push-dispatch Edge Function
      → FCM HTTP v1 (service account OAuth)
      → user_push_tokens (aktif) → telefona push
      → notification_push_deliveries (dedup + log)
bildirime tıkla → app açılır → data.route'a navigasyon (/notifications)
```

## Parçalar

| Parça | Yer |
|---|---|
| Token tablosu + RPC | migration `user_push_tokens` (PR-1) |
| Flutter token flow + tap | `lib/features/notifications/push/push_notification_service.dart`, `app.dart`, `auth_actions.dart` |
| Android FCM config | `android/settings.gradle.kts` + `app/build.gradle.kts` (google-services, **yalnız `google-services.json` varsa apply**), `AndroidManifest.xml` (POST_NOTIFICATIONS) |
| Delivery log + dedup | migration `notification_push_dispatch` (PR-2) |
| service_role grant'ları | migration `grant_service_role_push_tables` |
| Edge function | `supabase/functions/push-dispatch/index.ts` |
| Dispatch | **Supabase Database Webhook** (aşağıda) |

## Gereken secret'lar (Supabase — repo'da DEĞİL)

CLI/Dashboard veya Management API ile set edilir (değerler asla repo/log'a):
- `FIREBASE_SERVICE_ACCOUNT_JSON` — Firebase service account JSON (FCM HTTP v1).
- `EDGE_SERVICE_ROLE_KEY` — legacy service_role JWT (auto `SUPABASE_SERVICE_ROLE_KEY` yeni `sb_secret` formatında olduğu için fallback; function ikisini de dener).

> `google-services.json` (`.gitignore`'lu) cihaz/release build'inde gereklidir;
> CI'da yokken google-services plugin atlanır (build kırılmaz, push runtime'da
> sessiz devre dışı).

## Database Webhook kurulumu (aktif dispatch yolu)

Supabase Dashboard → **Database → Webhooks → Create**:
- **Table:** `public.notifications`
- **Events:** `INSERT`
- **Type:** Supabase Edge Functions → **`push-dispatch`** (POST)
- Auth: dashboard otomatik ekler (key elle yazılmaz).

Eşdeğeri (Management API ile kuruldu): `supabase_functions` etkinleştirilip
`notifications` üzerine `push_dispatch_on_notification_insert` trigger'ı
(`supabase_functions.http_request`) eklenir. Trigger header'ı **anon
(publishable) key** taşır; function kendi `SUPABASE_SERVICE_ROLE_KEY` env'iyle
ayrıcalıklı işlem yapar.

## Duplicate / tek yöntem notu

- **Aktif tek dispatch yolu = Database Webhook** (`push_dispatch_on_notification_insert`).
- PR-2'deki **pg_net trigger'ı `trg_notifications_push_dispatch` INERT**:
  Vault'ta `push_dispatch_url` / `push_dispatch_key` set EDİLMEDİĞİ için no-op
  döner (HTTP çağrısı yapmaz). Bu yöntem kullanılmıyor → o vault secret'larını
  **oluşturmayın**.
- **Üçüncü güvenlik ağı:** `notification_push_deliveries (notification_id,
  token_id)` unique dedup → aynı bildirim aynı cihaza iki kez gönderilemez
  (mekanizmadan bağımsız).
- İleride pg_net trigger'ı ayrı bir temizlik PR'ında düşürülebilir
  (fonksiyonel olarak zararsız).

## Test (kontrollü)

1 test notification: `insert into notifications(recipient_id, type, title,
body, route) values (<test_user>, 'system_test', '[TEST] ...', '...',
'/notifications')` → webhook → push. Doğrulama: `notification_push_deliveries`
`status='sent'`, cihazda bildirim, tıkla → `/notifications`. Sonra test
notification + delivery satırları silinir (FK cascade); `user_push_tokens`'a
dokunulmaz.
