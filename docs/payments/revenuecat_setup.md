# RevenueCat + Store Billing Kurulum Rehberi

FırınNet resmi ödeme modeli: iOS App Store IAP + Android Google Play Billing,
orkestrasyon RevenueCat, backend RevenueCat webhook + Supabase. Harici/web ödeme
yoktur.

## Product ID Listesi

Yeni satış modeli:

| Product ID | Paket | Fiyat |
|---|---|---|
| `firinnet_premium_monthly` | Premium aylık | 499 TL/ay |
| `firinnet_premium_yearly` | Premium yıllık | 4.990 TL/yıl |

Legacy transaction uyumluluğu için backend mapping bu eski ID'leri okumaya devam
eder, ancak yeni UI bunları satmaz:

| Legacy Product ID |
|---|
| `firinnet_bakery_pro_monthly` |
| `firinnet_bakery_premium_monthly` |
| `firinnet_supplier_pro_monthly` |
| `firinnet_supplier_premium_monthly` |

Korunan gelecek altyapısı:

| Product ID | Ürün | Durum |
|---|---|---|
| `firinnet_listing_fee_50` | 50 TL ilan yayın ücreti | Lansman döneminde kapalı, altyapı korunur |

## Google Play Console

1. `firinnet_premium_monthly` subscription ürününü oluştur.
2. Aylık base plan (id: `monthly`): 499 TL/ay.
3. `firinnet_premium_yearly` subscription ürününü oluştur.
4. Yıllık base plan (id: `annual`): 4.990 TL/yıl. NOT: eski `yearly` base
   planı yanlışlıkla aylık süreli açıldığı için devre dışı bırakıldı;
   RevenueCat ürünü `firinnet_premium_yearly:annual`.
5. `firinnet_listing_fee_50` one-time in-app product olarak kalabilir; lansman döneminde uygulama bunu başlatmaz.
6. License tester hesaplarını ekle.
7. Internal testing track ile test satın alması yap.

## RevenueCat

1. Android app package: `com.firinnet.firin_defter`.
2. iOS app bundle kullanılıyorsa ilgili bundle ID ile ayrı app oluştur.
3. Entitlement önerisi: `premium`.
4. `firinnet_premium_monthly:monthly` ve `firinnet_premium_yearly:annual` ürünlerini `premium` entitlement'a bağla (Google ürün kimliği `productId:basePlanId`).
5. Offering/package: monthly ve yearly package.
6. Public SDK keys:
   - Android: `REVENUECAT_ANDROID_API_KEY`
   - iOS: `REVENUECAT_IOS_API_KEY`
7. Webhook URL: `https://<PROJECT>.supabase.co/functions/v1/revenuecat-webhook`.
8. Webhook Authorization token Supabase secret `REVENUECAT_WEBHOOK_AUTH_TOKEN` ile aynı olmalı.
9. RevenueCat REST API key Supabase secret `REVENUECAT_REST_API_KEY` olarak set edilmeli.

## Supabase Edge Functions

- `revenuecat-sync-my-entitlements`: authenticated kullanıcı JWT'siyle çalışır.
- `revenuecat-confirm-listing-payment`: authenticated kullanıcı JWT'siyle çalışır.
- `revenuecat-webhook`: RevenueCat token/signature ile çağrılır; Supabase user JWT beklenmez.

Secret değerlerini source control'e koyma:

```bash
supabase secrets set REVENUECAT_WEBHOOK_AUTH_TOKEN=...
supabase secrets set REVENUECAT_WEBHOOK_SIGNING_SECRET=...
supabase secrets set REVENUECAT_REST_API_KEY=...
```

## Launch Promo

3 aylık ücretsiz Premium Google Play free trial değildir. Kullanıcı Premium bir
özelliğe ilk girdiğinde uygulama içi popup CTA'sı ile Supabase RPC
`activate_launch_premium_promo()` çağrılır. Kart, ödeme yöntemi ve otomatik
abonelik yoktur.

## Listing Launch Period

İlan ödemeleri runtime config ile kapalıdır:

- `listing_payments_enabled = false`
- `listing_free_until = <launch + 1 year>`

50 TL consumable altyapısı korunur. Ödeme yeniden açılmadan önce Play Console ve
RevenueCat'teki `firinnet_listing_fee_50` ürünü manuel kontrol edilmelidir.
