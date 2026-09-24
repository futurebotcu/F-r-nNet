# Launch Premium / Listing Payment Davranış Testleri

`20260923120000_launch_premium_and_listing_v1.sql` migration'ının **gerçek
PostgreSQL üzerinde** davranış doğrulaması. `test/launch_premium_listing_migration_test.dart`
yalnız SQL metin kontratıdır; davranış kanıtı BU pakettir.

## Ne test edilir

- `claim_store_payment_event` / `complete_store_payment_event`:
  - apply hatası → aynı event id retry → tek başarılı uygulama
  - başarılı event tekrar teslimi → ikinci yan etki yok
  - `skipped_no_secret` final değil: secret yapılandırılınca retry işlenir
  - taze `processing` kilidi diğer teslimi reddeder; >5 dk bayat kilit devralınır
  - **eşzamanlı** aynı event teslimi (iki psql oturumu) → tek işleme
- `apply_store_subscription`:
  - refund sonrası gecikmiş eski active olayı erişim AÇMAZ; gerçek yeni satın
    alma (yeni tx + timestamp) açar
  - yenileme sonrası gecikmiş eski expiration yeni dönemi bozamaz
  - aylık↔yıllık: eski ürünün active olayı entitlement dönemini kısaltamaz;
    biri kapanırken diğer geçerli abonelik korunur (heal dahil)
  - tx id'siz/timestamp'siz REST snapshot (sync yolu) refund edilmiş dönemi
    yeniden açamaz; daha ileri expires'lı gerçek repurchase snapshot'ı açar
- Promo (`activate_launch_premium_promo`):
  - idempotent; **eşzamanlı** aktivasyon tek başlangıç/bitiş üretir
  - süresi dolan promo yeniden başlamaz
  - authenticated kullanıcı entitlement/promo alanlarını doğrudan yazamaz
  - RPC grant matrisi + SECURITY DEFINER + sabit `search_path`

## Nasıl çalışır

`run_tests.ps1`:

1. `C:\tmp\firinnet-pg-audit\cluster` altında **izole** bir PostgreSQL 18
   cluster'ı kurar (port 55432, yalnız 127.0.0.1). Production/paylaşılan
   DB'ye asla bağlanmaz.
2. `harness_schema.sql` ile Supabase mock'larını kurar: `auth.users`,
   `auth.uid()` (GUC `request.jwt.claim.sub` okur), `anon`/`authenticated`/
   `service_role` rolleri, önkoşul tablolar (`profiles`, `user_entitlements`
   DDL'i `20260711090000` ile birebir) ve kapsam dışı modül stub'ları.
3. GERÇEK migration dosyalarını uygular
   (`20260712120000_store_payments_foundation_v1.sql` →
   `20260923120000_launch_premium_and_listing_v1.sql`),
   `check_function_bodies=off` ile (gövdeler harness dışı modüllere değinir).
4. `sql/10..13` dosyalarını koşar (assert'ler `raise exception`).
5. Eşzamanlılık: `conc_*_a.sql` transaction'ı 3 sn açık tutarken `conc_*_b.sql`
   aynı event/promo'yu teslim eder; `14_concurrency_asserts.sql` "tam olarak
   biri işledi" garantisini doğrular.
6. Cluster'ı durdurup siler (`-KeepCluster` ile bırakabilirsiniz).

## Çalıştırma

```powershell
powershell -File supabase\tests\launch_payment_behavior\run_tests.ps1
# veya farklı kurulum:
powershell -File supabase\tests\launch_payment_behavior\run_tests.ps1 `
  -PgBin 'C:\Program Files\PostgreSQL\18\bin' -Port 55432
```

Başarı çıktısı: `ALL LAUNCH PAYMENT BEHAVIOR TESTS PASSED`.

## Bilinen sınırlar

- Tam migration zinciri koşulmaz: tarihî
  `20260518120000_groups_v1_leave_safely_and_remove_member.sql` dosyasındaki
  `comment on function ... '...' || '...'` sözdizimi lokal psql'de hata verir
  (canlıya farklı içerikle uygulanmış). Bu paket yalnız ödeme/promo bağımlılık
  zincirini gerçek dosyalardan uygular; öncülleri harness DDL mirror'lar.
- Edge function'lar (Deno) burada koşmaz; HTTP katmanı davranışı (503/401,
  HMAC) kod incelemesi + RevenueCat dokümanı ile doğrulanır.
