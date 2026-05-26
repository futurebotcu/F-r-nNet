# Görsel Tema QA — Light Bakery Operasyon Dili

**Tarih:** 2026-05-12
**Yöntem:** ADB üzerinden gerçek emülatör (Pixel 7 1080x2400) screenshot'ları + ekran ekran görsel kontrast incelemesi + nokta atış renk/kontrast düzeltmesi. Layout, content, route, business logic değişmedi.

---

## 1. Screenshot Klasörü

`screenshots/theme_check/`

### "Before" — düzeltmelerden önce
| Dosya | Ekran |
|---|---|
| `00_current.png` | İlk açılıştaki Feed (scroll'da fotoğraf placeholder bloğu) |
| `01_feed.png` | Feed üst — "Atölyeden anlık" + "Sektör Grupları" carousel (cover'larda koyu blok) |
| `02_gruplar.png` | Gruplar tab — tüm grup kartları koyu kahve cover banner ile |
| `03_market.png` | Market — "Öne çıkan" + "Yeni ilanlar" koyu fotoğraf placeholder'ları |
| `04_ilanlar.png` | İlanlar — temiz, sadece "Jobs" başlığı İngilizce |
| `05_panel.png` | Panel — "Merhaba, Misafir" + sektör ağı kartları |
| `06_profile.png` | Profil — hero light bej, avatar amber gradient + dark coffee initial |
| `07_mesajlar.png` | Mesajlar — snackbar "Yakında aktif olacak" |
| `09_group_detail.png` | Grup detayı — mesaj baloncukları, send button |

### "After" — düzeltmelerden sonra
| Dosya | Ekran |
|---|---|
| `after_01_feed.png` | Feed — group carousel cover artık warm bej |
| `after_02_gruplar.png` | Gruplar — kart cover'ları warm bej, kategori text dark coffee |
| `after_03_market.png` | Market — product photo placeholder warm bej, badge'ler okunabilir |
| `after_04_ilanlar.png` | İlanlar — değişiklik yok, zaten temizdi |
| `after_05_panel.png` | Panel — değişiklik yok, zaten temizdi |

---

## 2. Ekran Ekran Değerlendirme (Before → After)

### Onboarding (`after_test.png` ilk açılışta yakalandı)
- ✓ Hero amber gradient banner, fire icon
- ✓ "Hoş geldin FırınNet'e" — large dark coffee text
- ✓ 3 feature row: amber square icons + dark coffee labels
- ✓ "Profil Oluştur" — amber bg + dark coffee text + dark coffee icon (honey button)
- ✓ "Kayıtsız Devam Et" — text button, dark coffee
- ✓ Status bar dark icons (önceki light status bar fix uygulandı)
- **Sorun yok**

### Feed / Akış
- **Before:** Sektör Grupları carousel'ında kart üst yarısı tamamen dark coffee espresso bloğu — light theme'de visual "boşluk" gibiydi
- **After:** Cover banner warm bej (`#F3E6D3 → #E5D2B0`), kategori text dark coffee, kategori icon amber. Kart bir bütün olarak akıyor
- "Atölyeden anlık" stripe — circular avatars amber border + dark coffee initial ✓
- "Aç" buton amber + dark coffee ✓
- Composer avatar "M" amber gradient + dark coffee initial ✓
- "Bugün ağda" section başlığı ✓
- "ÜRETİM" amber rozet ✓
- Bottom nav: surface bg, aktif Feed deep amber, pasif muted ✓

### Gruplar
- **Before:** Tüm grup kartlarının üstünde geniş koyu kahve cover banner — light theme üstünde ağır blok hissi
- **After:** Cover banner warm bej, "Reçete & Üretim" / "Un & Hammadde" dark coffee, kategori icon amber, "ÜYE" pill outline okunabilir
- "Aç" buton amber + dark coffee ✓
- "Grup Oluştur" FAB amber + dark coffee ✓
- Search bar, filter chip'ler temiz ✓
- Member progress bar amber, fluid ✓

### Market
- **Before:** "Öne çıkan" hero + grid product card'larında photo placeholder dark coffee bloklarla — gerçek görsel yokken çok ağır
- **After:** Photo placeholder warm bej (7 farklı subtle ton, visualSeed'e göre). "Devren" badge: light bg pill + dark coffee text (önceki: dark overlay + white text). "Öne çıkan" pill: amber bg + dark coffee text + dark coffee premium icon (önceki: amber + white)
- Card title, price (deep amber), city, seller — hepsi temiz okunabilir ✓
- Filter chip'ler temiz ✓

### İlanlar / Jobs
- ✓ Toggle (Usta Arıyor / İş Arıyor) temiz
- ✓ Job kartlar light bej, deep amber başlık, "Tam zaman" outline chip
- ✓ Icon chip rows (location, salary, experience, shift) okunabilir
- ✓ "Başvur" buton amber + dark coffee (honey button) — en güçlü CTA hissi
- ⚠ Header text "Jobs" hâlâ İngilizce — TEMA DIŞI lokalizasyon sorunu, raporda not edildi
- **Tema açısından sorun yok**

### Panel
- ✓ "Merhaba, Misafir" + "İş ağına bağlan" hero — light bej
- ✓ Logo fire icon amber gradient + dark coffee
- ✓ BIREYSEL / Diğer role badge — light bej card
- ✓ 4 aksiyon kartı (İş İlanları, İş Arıyorum İlanı Ver, Mesajlar, Profilim) — light bej, amber icon square, dark coffee başlık, muted brown subtitle. İş İlanları kartı diğerlerinden subtle daha vurgulu (active emphasis)
- ✓ Bottom nav Panel aktif deep amber underline

### Profil
- ✓ Hero light bej (elevatedCard), avatar amber gradient + dark coffee "M" initial (önceki Colors.white → textPrimary fix uygulandı)
- ✓ "Misafir / Diğer" name + role, "Hesap Bireysel" inline tag
- ✓ İstatistikler row — 12 / 186 / 4 — büyük dark coffee sayılar, muted brown labels
- ✓ Hesap menu list — 5 row light bej hairline border
- ✓ "Profilden Çık" text button bottom

### Mesajlar
- ✓ Henüz açılmamış feature — snackbar "Yakında aktif olacak"
- ✓ Snackbar elevated card bej bg + dark coffee text (theme'in snackBarTheme'inden gelen tutarlı görünüm)

### Grup Detayı
- ✓ Hero card light bej, "Reçete & Üretim" badge, group title
- ✓ ÜYE / LIMIT progress bar amber
- ✓ "Ayrıl" outlined button — soft deep amber border
- ✓ Mesaj baloncukları: H, S avatar amber gradient + dark coffee initial
- ✓ "SABİTLENDİ" pin badge deep amber uppercase
- ✓ Reaction count ❤️
- ✓ Message input + send button amber circular + dark coffee paper-plane icon

---

## 3. Yapılan Düzeltmeler (4 dosya)

### A. Group card cover gradient (light bakery)
**Dosya:** `lib/features/social_groups/widgets/group_card.dart`

| Değişim | Önceki | Şimdi |
|---|---|---|
| `_seedGradients` (8 adet) | Dark espresso: `#3A2418 → #1F140C` vb. | Warm bej: `#F3E6D3 → #E5D2B0` vb. (7 subtle warm ton) |
| Icon container bg | `overlay.withValues(alpha: 0.45)` | `background.withValues(alpha: 0.7)` |
| Icon container border | `Colors.white @ 0.06` | `softGold @ 0.25` |
| Category label text | `Colors.white` w700 | `textPrimary` w800 |

**Neden:** Light theme üstünde dark coffee cover bloğu visual "hole" gibi duruyordu. Warm bej gradient'lere geçince kart bir bütün olarak akıyor.

### B. Marketplace photo placeholder + badge
**Dosyalar:**
- `lib/features/marketplace/screens/marketplace_screen.dart` (7 product `gradient`)
- `lib/core/widgets/premium/market_product_card.dart` (badge + "Öne çıkan" pill)

| Değişim | Önceki | Şimdi |
|---|---|---|
| 7 product `gradient` | Dark espresso | Warm bej (her ürün için subtle ton) |
| Badge bg (Devren/Ekipman/Hammadde) | `overlay @ 0.55` | `background @ 0.85` |
| Badge border | `Colors.white @ 0.06` | `softGold @ 0.3` |
| Badge text | `Colors.white` w700 | `textPrimary` w800 |
| "Öne çıkan" pill icon | `Colors.white` | `textPrimary` |
| "Öne çıkan" pill text | `Colors.white` w800 | `textPrimary` w800 |

**Neden:** Gerçek görsel yokken photo placeholder dark espresso ile geliyordu. Light theme'de empty state çok ağırdı. White-on-dark overlay'lerde light bej'e geçince beyaz text → dark coffee text.

### C. Feed post photo placeholder
**Dosya:** `lib/features/feed/repositories/local_feed_repository.dart`

| Değişim | Önceki | Şimdi |
|---|---|---|
| `_gradients` (8 adet) | Dark espresso | Warm bej |

**Neden:** Feed post'larda `gradient` field var, ürün ve grup kartlarındakiyle aynı sorun.

### D. Status bar overlay style (light status bar)
**Dosyalar:** `lib/main.dart`, `lib/app/theme/app_theme.dart`

| Değişim | Önceki | Şimdi |
|---|---|---|
| `main()` system overlay | Yok — default (dark icons in dark mode) | `SystemChrome.setSystemUIOverlayStyle` with `statusBarIconBrightness: Brightness.dark`, `statusBarBrightness: Brightness.light`, `systemNavigationBarColor: #FFF8ED` |
| `AppBarTheme.systemOverlayStyle` | Yok | `SystemUiOverlayStyle(statusBarColor: transparent, statusBarIconBrightness: dark, statusBarBrightness: light)` |

**Neden:** Light theme üzerinde status bar ikonları beyaz görünüyordu (dark mode varsayımı). Light theme + cream background için dark icons gerekiyor.

---

## 4. Kalan Görsel Riskler

| Risk | Neden | Önerilen aksiyon |
|---|---|---|
| **"Jobs" header İngilizce** | Lokalizasyon eksiği (tema dışı) | `AppStrings.jobsTitle` Türkçe'ye çevrilmeli — "İş İlanları" veya "İlanlar". `lib/core/constants/app_strings.dart` |
| **Soft keyboard sırasında profil oluşturma flow** | ADB tap "Profil Oluştur" sonrası klavye açıldı — UX intent doğru ama bu sayfa screenshot olarak alınamadı | Manuel test |
| **Gerçek görsel yüklendiğinde markette badge görünürlüğü** | Şu an placeholder warm bej üzerinde dark badge text okunuyor. Gerçek fotoğraf koyu/parlak karışıksa badge kontrastı değişebilir | İlerde gerçek görsel pipeline'ı eklenince badge'e text shadow veya gradient overlay düşünülebilir |
| **`darkAccent` / `darkAccentDeeper` token'ları unused** | Palette'te tanımlı ama widget'larda erişen yok | Önceki rapor (`COLOR_THEME_APPLICATION_REPORT.md`) zaten not etti — gelecekte spot dark accent için kullanılabilir |
| **Compose / Detail screen'lerin tam testi** | Bu QA Feed/Gruplar/Market/İlanlar/Panel/Profil/Mesajlar/Group detail'e baktı. Job detail, Composer keyboard expanded, Bayi panel deep tarafları kullanıcı navigation'ı gerektiriyor | Kullanıcı manuel testi |

---

## 5. Test Sonuçları

```
$ flutter analyze --no-fatal-infos
Analyzing firinnet...
No issues found! (ran in 0.5s)

$ flutter test
... 42 tests
00:01 +42: All tests passed!
```

- **Analyzer:** 0 issue
- **Tests:** 42/42 passed
- **Build:** `flutter build apk --debug` → `app-debug.apk` 24.9s
- **Install:** `adb install -r` → Success
- **Launch:** `monkey -p com.firinnet.firin_defter` → app açıldı, status bar dark icons doğrulandı

---

## 6. Önceden Sonraya Karşılaştırma — Kritik Noktalar

| Boyut | Before | After |
|---|---|---|
| Feed group carousel cover | Dark espresso `#3A2418` blok | Warm bej `#F3E6D3` |
| Group list card cover banner | Dark espresso blok | Warm bej gradient |
| Group card category text | Beyaz (Colors.white) | Dark coffee (textPrimary) |
| Group card icon container | Dark overlay + white border | Light cream + amber border |
| Market product photo placeholder | Dark espresso | Warm bej |
| Market "Devren/Ekipman" badge | Dark overlay + white text | Light bg + dark coffee text |
| Market "Öne çıkan" pill | Amber + white text | Amber + dark coffee text |
| Feed post photo placeholder gradient | Dark espresso | Warm bej |
| Status bar (Android system bar) | Light icons (assumed dark theme) | Dark icons (correct for light theme) |
| Navigation bar (alt sistem bar) | Default (likely dark) | Cream (#FFF8ED) + dark icons |

---

## 7. Toplam Etki

**Dosya değişikliği:** 5 dosya — hepsi sadece renk/yüzey/text-color cerrahisi:
1. `lib/features/social_groups/widgets/group_card.dart` (gradient + icon + label)
2. `lib/features/marketplace/screens/marketplace_screen.dart` (7 product gradient)
3. `lib/core/widgets/premium/market_product_card.dart` (badge + featured pill)
4. `lib/features/feed/repositories/local_feed_repository.dart` (8 gradient)
5. `lib/main.dart` + `lib/app/theme/app_theme.dart` (status bar overlay)

**Hiç dokunulmadı:**
- Hiçbir feature mantığı / route / navigation / state management / data layer
- Hiçbir test dosyası
- Hiçbir layout / widget hiyerarşisi
- Hiçbir spacing / padding (cerrahi: sadece renk)

**Sonuç:** Light bakery dili artık ekran ekran tutarlı. "Premium chalkboard" izleri (dark espresso cover'lar, white text overlay'leri, dark status bar) tamamen kaldırıldı. Hem `flutter analyze` hem `flutter test` temiz.
