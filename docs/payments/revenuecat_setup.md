# RevenueCat + Store Billing — Kurulum Rehberi (V1)

FırınNet resmi ödeme modeli: **iOS App Store IAP + Android Google Play Billing**,
orkestrasyon **RevenueCat**, backend **RevenueCat webhook + Supabase**.
Havale/EFT/İyzico/Stripe/manuel/sahte ödeme **YOK**.

Bu PR kod altyapısını kurar (migration + edge functions + client SDK + config +
tests). Canlı ödeme aşağıdaki **elle (dashboard) kurulum** tamamlanınca başlar.
Secret'lar set edilene kadar ödeme butonları "Mağaza ödemeleri hazırlanıyor"
gösterir; sahte purchase üretilmez.

## 1. Product ID listesi

Subscription (auto-renewing monthly):
| Product ID | Paket | Fiyat |
|---|---|---|
| `firinnet_bakery_pro_monthly` | Fırıncı Pro (commercial/pro) | 299 TL/ay |
| `firinnet_bakery_premium_monthly` | Fırıncı Premium (commercial/premium) | 799 TL/ay |
| `firinnet_supplier_pro_monthly` | Tedarikçi Pro (wholesaler/pro) | 999 TL/ay |
| `firinnet_supplier_premium_monthly` | Tedarikçi Premium (wholesaler/premium) | 2.999 TL/ay |

Consumable (one-time):
| Product ID | Ürün | Fiyat |
|---|---|---|
| `firinnet_listing_fee_50` | Ücretli ilan yayın ücreti | 50 TL |

Product ID mapping backend'de tek kaynak: `store_product_mapping()` SQL
fonksiyonu + client `StoreProductConfig`. RevenueCat entitlement adları değişse
bile mapping **product_id** üzerinden sabittir.

## 2. App Store Connect

1. App > Subscriptions: 4 auto-renewable subscription oluştur (yukarıdaki
   product id'lerle), fiyat TRY.
2. App > In-App Purchases: `firinnet_listing_fee_50` **Consumable** oluştur (50 TL).
3. Subscription grubu: bakery (pro/premium) + supplier (pro/premium) ayrı
   gruplarda önerilir (upgrade/downgrade doğru çalışsın).
4. App-Specific Shared Secret üret (RevenueCat'e girilecek).
5. Sandbox test hesabı oluştur.

## 3. Google Play Console

1. Monetize > Subscriptions: 4 subscription (aynı product id'ler), base plan
   monthly, fiyat TRY.
2. Monetize > In-app products: `firinnet_listing_fee_50` (50 TL).
3. Play Billing için service account + RevenueCat'e Play credentials bağla.
4. License test hesapları ekle (sandbox).
5. `com.android.vending.BILLING` izni manifest'te mevcut (bu PR).

## 4. RevenueCat

1. Project + iOS app (bundle: `com.firinnet.firinDefter`) + Android app
   (package: `com.firinnet.firin_defter`).
2. App Store shared secret + Play credentials gir.
3. **Entitlements** (öneri): `bakery_pro`, `bakery_premium`, `supplier_pro`,
   `supplier_premium` — her product'ı ilgili entitlement'a bağla. (Backend
   asıl kararı product_id mapping ile verir; entitlement adı esnektir.)
4. **Offerings**: her hesap türü için offering (bakery / supplier) + packages.
5. **Public SDK keys**: iOS + Android app'ten al → client dart-define.
6. **Webhook**: URL =
   `https://<PROJECT>.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization header = `Bearer <REVENUECAT_WEBHOOK_AUTH_TOKEN>` (kendi
     ürettiğin gizli token; Supabase secret ile AYNI olmalı).
   - (Opsiyonel) HMAC signing secret aktifse `REVENUECAT_WEBHOOK_SIGNING_SECRET`
     ile eşleşmeli.
7. **REST API key** (v1 secret) → Supabase secret `REVENUECAT_REST_API_KEY`
   (subscriber doğrulama + listing fee confirm için).

## 5. Client dart-define (public keys)

```
flutter build appbundle \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
```

Key yoksa `AppConfig.storePaymentsEnabled=false` → ödeme UI "hazırlanıyor".

## 6. Supabase secrets (edge env)

```
supabase secrets set REVENUECAT_WEBHOOK_AUTH_TOKEN=...
supabase secrets set REVENUECAT_WEBHOOK_SIGNING_SECRET=...   # opsiyonel HMAC
supabase secrets set REVENUECAT_REST_API_KEY=...
```

Secret yoksa: webhook event'i kaydeder ama **apply etmez** (fail-closed);
sync/confirm doğrulama yapmaz. Fake success ÜRETİLMEZ.

## 7. ⚠️ Webhook verify_jwt = OFF (ZORUNLU)

`revenuecat-webhook` fonksiyonu RevenueCat'in kendi Authorization token'ıyla
çağrılır (Supabase JWT değil). Supabase Dashboard > Edge Functions >
`revenuecat-webhook` > Details > **"Verify JWT" KAPALI** yap. Aksi halde gateway
webhook'u 401 ile reddeder. (`sync`/`confirm` fonksiyonları authenticated →
verify_jwt AÇIK kalır.)

## 8. Sandbox test

1. iOS: sandbox hesabıyla cihazda satın al → webhook `INITIAL_PURCHASE` →
   `user_entitlements.plan` = pro/premium.
2. Android: license test hesabıyla satın al.
3. Restore purchases → `revenuecat-sync-my-entitlements` → plan geri gelir.
4. Ücretli ilan: pending ilan → 50 TL satın al → `revenuecat-confirm-listing-
   payment` (REST doğrulama) → ilan public.
5. Cancel/expire → webhook `EXPIRATION` → plan free.

## 9. App Review notu (kısa)

> FırınNet ticari işletme ve tedarikçilere aylık abonelik (Pro/Premium) ve
> tekil ilan yayın ücreti (50 TL) sunar. Ödemeler yalnız App Store IAP /
> Google Play Billing üzerinden RevenueCat ile alınır; harici/web ödeme yoktur.
> 30 günlük ücretsiz deneme karta bağlı değildir.

## Güvenlik özeti

- Entitlement/listing YALNIZ service_role (webhook / doğrulanmış edge) tarafından
  uygulanır; client `user_entitlements`/`listing_payment_intents` yazamaz.
- Webhook: Authorization token + opsiyonel HMAC (timing-safe) + idempotent
  (`provider_event_id` UNIQUE).
- Listing fee: client transaction_id'ye güvenilmez → RevenueCat REST doğrulaması
  (confirm edge). Self-pay bypass kapalı (`mark_listing_fee_paid_from_store`
  service_role-only).
- Wrong account_type product → entitlement değişmez (`ignored_wrong_account_type`).
