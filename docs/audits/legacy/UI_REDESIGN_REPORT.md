# FırınNet — UI Redesign PASS 1 Raporu

**Tarih:** 2026-05-09
**Aktif proje dizini:** `C:\dev\firinnet`
**Uygulama adı:** FırınNet
**Android paket adı:** `com.firinnet.firin_defter`

---

## 0. Dizin / Klasör Notları

- Aktif proje dizini: `C:\dev\firinnet` — tüm geliştirme ve QA buradan yapılır.
- Eski/duplicate klasör: `C:\dev\FırınNet` — boşaltıldı (2026-05-08), kullanılmayacak.
- QA çıktıları: `C:\dev\firinnet\qa-screenshots\redesign-pass-1\`
- Geçmişte bash escape hatası nedeniyle proje kökünde `Cdevfirinnetqa-screenshotsredesign-pass-1` adlı bozuk bir klasör adı raporlanmıştı; bu kontrol turunda artık yok.

---

## 1. PASS 1 Özet

PASS 1, eski Material vurgusunu “premium dark bakery” editorial diline taşıdı:

- 5 sekmeli alt navigasyon (Feed / Market / Panel / Jobs / Profil) tek bir `PremiumBottomNav` ile birleştirildi.
- Tüm ana ekranlar `PremiumScaffold` + bakır vurgulu kart sistemi üzerine alındı.
- Panel ekranı için “Hızlı işlemler” ızgarası (`QuickActionTile`) ve günlük özet (`StatCard`) eklendi.
- Renk / token sistemi `AppColors`, `AppSpacing`, `AppRadius`, `AppShadow`, `AppDuration` altında merkezileşti.
- Mevcut repo / provider / router katmanları korundu — sadece sunum katmanı değişti.

---

## 2. Değişen / Eklenen Ana Dosyalar

### Yeni premium component sistemi (`lib/core/widgets/premium/`)

- `premium_scaffold.dart` — koyu zemin + safe-area ritmi
- `premium_card.dart` — yumuşak gölgeli ana kart
- `firinnet_header.dart` — ekran üst başlığı + alt metin
- `metric_pill.dart` — küçük metrik etiketi
- `stat_card.dart` — büyük sayı + alt etiketli özet kartı
- `quick_action_tile.dart` — Panel ızgarası için aksiyon kartı
- `feed_post_card.dart` — Feed gönderi kartı
- `market_product_card.dart` — Market ürün kartı
- `job_opportunity_card.dart` — Jobs ilan kartı
- `section_label.dart` — bölüm başlığı
- `premium_bottom_nav.dart` — özelleştirilmiş alt sekme çubuğu

### Tema & token

- `lib/app/theme/app_colors.dart` — `background / surface / card / elevatedCard`, `copper / softGold / copperMuted` paleti
- `lib/app/theme/app_tokens.dart` — `AppSpacing` (4 px tabanlı), `AppRadius`, `AppShadow.soft|subtle|copper`, `AppDuration`
- `lib/app/theme/app_theme.dart` — dark-only Material 3 tema, copper birincil

### Shell & router

- `lib/features/dashboard/screens/app_shell.dart` — 5 sekmeli `ShellRoute` + `PremiumBottomNav`
- `lib/app/router/app_router.dart` — splash / onboarding / createProfile + 5 ana tab + 6 Panel alt ekranı

### Yeni & redesign edilen feature ekranları

- `feed/screens/feed_screen.dart`
- `marketplace/screens/marketplace_screen.dart`
- `bakery_panel/screens/bakery_panel_screen.dart`
- `bakery_panel/screens/recipe_calculator_screen.dart`
- `bakery_panel/screens/production_entry_screen.dart`
- `bakery_panel/screens/dealer_delivery_screen.dart`
- `bakery_panel/screens/waste_entry_screen.dart`
- `bakery_panel/screens/end_of_day_screen.dart`
- `bakery_panel/screens/report_screen.dart`
- `jobs/screens/jobs_screen.dart`
- `profile/screens/profile_screen.dart`
- `profile/screens/create_profile_screen.dart`
- `onboarding/screens/onboarding_screen.dart` (premium giriş + “Profil Oluştur / Kayıtsız Devam Et”)
- `onboarding/screens/splash_screen.dart`

---

## 3. Yeni Tab Yapısı

| Index | Route          | Etiket  | Ekran                  |
| :---: | -------------- | ------- | ---------------------- |
|  0    | `/feed`        | Feed    | `FeedScreen`           |
|  1    | `/market`      | Market  | `MarketplaceScreen`    |
|  2    | `/panel`       | Panel   | `BakeryPanelScreen`    |
|  3    | `/jobs`        | Jobs    | `JobsScreen`           |
|  4    | `/profile`     | Profil  | `ProfileScreen`        |

Panel alt ekranları (shell dışında, tam ekran):

- `/panel/recipe` → Reçete Hesapla
- `/panel/production` → Üretim Gir
- `/panel/dealer` → Bayiye Ver
- `/panel/waste` → Fire Gir
- `/panel/end-of-day` → Gün Sonu
- `/panel/report` → Rapor Al

`PremiumBottomNav` koordinatları (1080×2400 emülatör):

| Tab    | x   | y    |
| ------ | --: | ---: |
| Feed   | 108 | 2246 |
| Market | 324 | 2246 |
| Panel  | 540 | 2246 |
| Jobs   | 756 | 2246 |
| Profil | 972 | 2246 |

---

## 4. Premium Component Sistemi

- **Renk dili:** koyu yüzey katmanları (`#0F0F10` → `#171717` → `#1B1B1C` → `#211B16`) üzerine bakır vurgu (`#C26A2D` / `#D6A56D`).
- **Tipografi:** `textPrimary #F5F1EB`, `textSecondary #A8A29E`, `textMuted #6E6864` — düşük doygunluk, yüksek okunabilirlik.
- **Boşluk ritmi:** `AppSpacing` 4 px tabanlı (xs 4, s 8, m 12, l 16, xl 24, xxl 32, xxxl 48); sayfa kenar boşluğu `pageH 20 / pageV 16`.
- **Köşe yarıçapı:** `AppRadius.xs 8 → xl 28`, pill 999.
- **Gölge katmanları:** `AppShadow.soft / subtle / copper` (bakır vurgulu kartlar için).
- **Hareket:** `AppDuration.fast 180 ms`, `normal 280 ms` — sakin geçişler.
- **Lokalizasyon:** `tr_TR` öntanımlı, `en_US` desteklenir.
- **Tema:** `ThemeMode.dark` — light tema yok (PASS 1 kapsamı dışında).

---

## 5. Korunan Mimari

- **State management:** `flutter_riverpod ^2.5.1`
- **Routing:** `go_router ^14.6.2` (`ShellRoute` + 5 tab + Panel sub-route)
- **Repository pattern:** `BakeryRepository` arayüzü, `LocalBakeryRepository` uygulaması (local-first; pubspec açıklamasında belirtilen `“Fırıncılar için local-first defter uygulaması”` mottosuyla uyumlu)
- **Domain modelleri:** `Recipe`, `ProductionEntry`, `DealerDeliveryEntry`, `WasteEntry`, `DailySummary`, `BakeryProfile`
- **Servisler:** `RecipeCalculator`, `ReportBuilder`
- **Paylaşım:** `share_plus ^10.1.2`
- **Formatlama:** `intl ^0.20.2`
- **Provider'lar:** `bakery_providers.dart`, `profile_provider.dart`

PASS 1 yalnızca sunum katmanını yeniledi; iş mantığı, model katmanı ve repository sözleşmesi değişmedi.

---

## 6. Analyze / Test Durumu

- `flutter analyze` → **No issues found! (0.6 s)**
- `flutter test` → **All tests passed!** (5 test)
  - `RecipeCalculator default brief example: 50 kg / 60 / 1 / 2 / 250 / 3` ✓
  - `RecipeCalculator zero flour produces zero output` ✓
  - `RecipeCalculator 100% waste leaves no dough and 0 pieces` ✓
  - `RecipeCalculator larger piece weight reduces estimated pieces` ✓
  - `widget_test.dart: placeholder` ✓

Not: `flutter pub get` 17 paketin yeni sürümü olduğunu raporladı (constraint nedeniyle yükseltilmedi). PASS 2 öncesi tartışılabilir — şimdilik aksiyon yok.

---

## 7. APK / Install Durumu

- Cihaz: `emulator-5554` (Android, 1080×2400)
- Kurulu paket: `com.firinnet.firin_defter` ✓
- Aktivite: `com.firinnet.firin_defter/.MainActivity`
- PASS 1 sırasında uygulama açıldı, onboarding geçildi, tüm tab’lar ve Panel alt ekranları başarıyla render edildi.

---

## 8. Screenshot Dosya Listesi

Klasör: `C:\dev\firinnet\qa-screenshots\redesign-pass-1\`

| Dosya               | Boyut (bayt) | Tarih               |
| ------------------- | -----------: | ------------------- |
| `01_onboarding.png` |      230 616 | 2026-05-08 17:40    |
| `02_feed.png`       |      113 900 | 2026-05-08 18:29    |
| `03_market.png`     |      166 651 | 2026-05-09 04:50    |
| `04_panel.png`      |      177 399 | 2026-05-09 04:50    |
| `05_jobs.png`       |      158 429 | 2026-05-09 04:50    |
| `06_profile.png`    |      134 350 | 2026-05-09 04:50    |
| `07_recipe.png`     |       98 496 | 2026-05-09 04:51    |
| `08_day_end.png`    |       65 442 | 2026-05-09 04:51    |
| `09_report.png`     |       75 792 | 2026-05-09 04:51    |

Yardımcı dump dosyaları:
- `_dump_current.xml` — onboarding/feed dump’ı (uiautomator)
- `_dump_panel.xml` — Panel ekranı dump’ı (Reçete / Gün Sonu / Rapor bounds için)

---

## 9. Screenshot Pipeline Notu

Çalışan akış:

1. `adb devices` ile cihaz doğrula.
2. Hedef ekrana git: `adb shell input tap <x> <y>`.
3. **700–1000 ms** bekle (ekran yerleşmesi için).
4. Yakalama: `cmd /c "adb exec-out screencap -p > <hedef>.png"` — PowerShell’de doğrudan `>` yönlendirmesi PNG’yi UTF-16 olarak bozar; `cmd /c` binary güvenli.
5. Doğrulama: yalnızca `(Get-Item ...).Length` ile dosya boyutu kontrol edilir; **PNG içeriği parse edilmez** (önceki başarısız “PNG’yi okumaya çalış” yaklaşımı kaldırıldı).
6. Koordinat tespiti `adb shell uiautomator dump /sdcard/window_dump.xml` + `adb pull` + XML grep ile yapılır; **blind tap yok**.
7. Panel alt ekranlarından dönmek için `adb shell input keyevent 4`.

---

## 10. PASS 2 İçin Önerilen Adımlar

Kod tarafına henüz dokunmadan, PASS 2 öncesi tartışılması gereken adımlar:

1. **Empty state’ler:** Üretim Gir / Bayiye Ver / Fire Gir / Gün Sonu / Rapor ekranlarında veri yokken görsel ritim. (`08_day_end.png` ve `09_report.png` dosya boyutlarının küçüklüğü buradaki sadeliğin işareti olabilir — görsel inceleme sonrası karar verilmeli.)
2. **Geri tuşu ergonomisi:** Panel alt ekranlarında özel bir “geri” butonu / breadcrumb gerekip gerekmediği.
3. **Skeleton / loading:** Repository yüklenirken placeholder’lar.
4. **Light tema:** Şu an dark-only; talep varsa `ThemeMode.system` desteği için renk eşlenikleri.
5. **Erişilebilirlik:** `content-desc` etiketleri zaten dolu — kontrast oranları (özellikle `textMuted #6E6864`) WCAG AA’ya karşı denetlenmeli.
6. **`AppColors` legacy alias’ları:** `copperBright / copperDeep / ember / surfaceHigh / warning` — yorum satırı “eski ekranlar redesign edilince kaldırılacak” diyor; PASS 2’de kaldırılabilir.
7. **Bağımlılık güncellemeleri:** 17 paketin yeni majör sürümleri var (riverpod 3.x, go_router 17.x, share_plus 13.x). Risk/getiri tartışılmalı.
8. **PASS 1 → PASS 2 görsel diff:** PASS 2 başlamadan önce `redesign-pass-1` setinin tamamı manuel onaylanmalı, ardından `redesign-pass-2` klasörü açılıp aynı 9 ekran için karşılaştırma alınmalı.

---

**PASS 1 durumu:** ✅ Kapatıldı.
PASS 2 kod değişikliklerine henüz başlanmadı — talimat gereği bekliyor.
