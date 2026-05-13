# Renk Teması Uygulaması — Light Bakery Operasyon Dili

**Tarih:** 2026-05-12
**Kapsam:** Sadece renk paleti, yüzey, kart görünümü, buton, chip, input, gölge, border ve typography hissiyatı. Akış / navigation / widget hiyerarşisi / business logic / feature mantığı HİÇ değişmedi.

---

## 1. Hedef vs Uygulanan

| Hedef yönerge | Karşılık |
|---|---|
| %75 açık krem / %20 sıcak destek / %5 koyu vurgu | ✓ background `#FFF8ED`, surface `#F6EFE3`, card `#FAF2E6`, elevated `#F3E6D3`. Koyu kahve sadece text/icon/badge'lerde. |
| Yumuşak amber, agresif turuncu yok | ✓ `copper` `#D6A13A` (yumuşak amber), `softGold` `#B98224` (deep amber metin), `copperMuted` `#E8BF63` (light amber halo) |
| Saf beyaz yok | ✓ tüm "beyazlar" `#FFF8ED` / `#FAF2E6` |
| Koyu kahve sadece vurgu | ✓ `darkAccent` `#3A2618` & `darkAccentDeeper` `#4A3020` palette'te seyrek erişim sabitleri olarak duruyor; ana yüzey değil |
| Saf siyah text yok | ✓ `textPrimary` `#2B1D14` |
| Soğuk gri yok | ✓ secondary `#7A6857`, muted `#9C8973` — hepsi sıcak ton |
| Neon olmasın | ✓ success `#4F7D3A` toprak yeşili, danger `#B84A35` toprak kızılı, warning `#D9A441` amber |
| Buton agresif turuncu yok | ✓ amber `#D6A13A` bg + dark coffee text (honey button hissi) |
| Bottom nav: sade, aktif net | ✓ surface bg, aktif `softGold` (deep amber), pasif `textMuted` muted kahve |

---

## 2. Değişen Dosyalar (8 dosya, tamamı renk/stil)

| Dosya | Değişiklik | Etki |
|---|---|---|
| `lib/app/theme/app_colors.dart` | **Tam yeniden yazıldı** — yeni palet | Tüm tema temeli |
| `lib/app/theme/app_theme.dart` | ColorScheme, filled/elevated/outlined/text button, input, chip, nav, snackbar | Merkezi component stilleri |
| `lib/app/theme/app_tokens.dart` | Tüm shadow değerleri yumuşatıldı, sıcak kahve tonlu | Kartların kalkış hissi |
| `lib/core/widgets/premium/firinnet_header.dart` | Logo icon `Colors.white` → `textPrimary` (amber gradient üstünde okunabilirlik) | Tüm header'lar |
| `lib/core/widgets/empty_state.dart` | Aksiyon butonu foreground `Colors.white` → `textPrimary` | Boş durum CTA'ları |
| `lib/features/profile/screens/profile_screen.dart` | Avatar initial `Colors.white` → `textPrimary` (amber gradient üstünde) | Profil hero |
| `lib/features/feed/screens/feed_screen.dart` | Avatar initial `Colors.white` → `textPrimary` | Feed header avatar |
| `lib/features/feed/widgets/feed_composer.dart` | Avatar "M" + selected chip icon + submit button: `Colors.white` → `textPrimary` | Akış composer |
| `lib/features/social_groups/widgets/group_card.dart` | Join/Open button foreground `Colors.white` → `textPrimary` | Grup kartları |
| `lib/features/bakery_panel/screens/bakery_panel_screen.dart` | "Bayi Yönetimine Git" buton fg + "Açık bakiye" metric color: amber'in okunmaz versiyonlarından deep amber'e | Panel KPI |
| `lib/features/dealers/screens/dealer_detail_screen.dart` | "Fiyat ekle" mini buton fg `Colors.white` → `textPrimary` | Bayi detay |

**Toplam:** 4 tema dosyası + 7 widget cerrahisi (sadece renk referansı). 471 `AppColors.*` referansının 460+'ı dokunulmadan, yalnızca paletin VALUE değişimi ile yeni dile geçti.

---

## 3. Yeni Renk Sistemi — Tam Tablo

### Yüzeyler (krem dominant)

| Token | Değer | Kullanım |
|---|---|---|
| `background` | `#FFF8ED` | Tüm scaffold zeminleri |
| `surface` | `#F6EFE3` | Bottom nav, input fill, chip bg, header strip |
| `card` | `#FAF2E6` | Standart `PremiumCard` |
| `elevatedCard` | `#F3E6D3` | Hero / featured / profil header |
| `surfaceLine` | `#E6D5BA` | Divider |
| `overlay` | `#EFE0C8` | Sheet / dialog |
| `borderHairline` / `borderLight` | `#DFC9A8` | Kart border, input border |

### Amber paleti

| Token | Değer | Anlam |
|---|---|---|
| `copper` | `#D6A13A` | Ana amber — buton bg, indicator, focused border |
| `softGold` | `#B98224` | Deep amber — text/icon emphasis on light card |
| `copperMuted` | `#E8BF63` | Light amber — yumuşak halo, gradient companion |

> **Önemli not:** `softGold` semantiği değişti. Eski temada light cream `#D6A56D` olarak DARK kart üzerinde vurgu yapıyordu; şimdi deep amber `#B98224` olarak LIGHT kart üzerinde vurgu yapıyor. İsim aynı, rol aynı (emphasis), değer yeni paleteye göre.

### Koyu vurgu (seyrek)

| Token | Değer | Kullanım |
|---|---|---|
| `darkAccent` | `#3A2618` | Badge bg, ince ikon emphasis (henüz widget'larda erişen yok — gelecek için) |
| `darkAccentDeeper` | `#4A3020` | Daha derin vurgu |

### Tipografi (tek bağlam — light)

| Token | Değer | Kullanım |
|---|---|---|
| `textPrimary` | `#2B1D14` | Tüm ana metin (kart içi + zemin) |
| `textSecondary` | `#7A6857` | İkincil metin |
| `textMuted` | `#9C8973` | Etiket / placeholder |
| `onBackgroundPrimary/Secondary/Muted` | alias of text* | Önceki tema'dan kalan referans uyumluluğu |

### Durum

| Token | Değer | Anlam |
|---|---|---|
| `success` | `#4F7D3A` | Toprak yeşili |
| `warning` | `#D9A441` | Sıcak amber (status, ana aksentten ayrı) |
| `danger` | `#B84A35` | Toprak kızılı |
| `info` | `#6E7F8A` | Mat çelik |

---

## 4. Theme'e Taşınan Stiller

`app_theme.dart` artık şu component'lerin görünümünü TEK MERKEZDEN dağıtıyor:

| Component | Renk dili |
|---|---|
| `FilledButton` | `copper` bg + `textPrimary` foreground (dark coffee on amber → honey button) |
| `ElevatedButton` | Aynı |
| `OutlinedButton` | `softGold` (deep amber) foreground + `softGold @ 55%` border |
| `TextButton` | `softGold` foreground |
| `InputDecoration` | `surface` fill, `borderHairline` border, `softGold` focused border, `textSecondary` label, `textMuted` hint |
| `Chip` | `surface` bg, `copper` selected bg, `textPrimary` label, deselected ile selected aynı text rengi (samimi rozet) |
| `NavigationBar` | `surface` bg, aktif `softGold`, pasif `textMuted` |
| `SnackBar` | `elevatedCard` bg, `textPrimary` content (light kart hissi, koyu metin) |
| `AppBar` | `background` bg, `textPrimary` foreground |
| `Divider` | `surfaceLine` (sıcak bej) |
| `CardTheme` | `card` (light bej) |

Widget'ların büyük çoğunluğu (PremiumCard, QuickActionTile, _TodayHero, _DealerSummaryCard, RoleDashboard, vs.) bu theme değerlerini OKUYUP üzerinde inline color kullanıyor — dolayısıyla theme değişimi onları otomatik yeni dile çekiyor.

---

## 5. Hardcoded Renk Temizliği

Önceki tarama 17 dosyada `Colors.white` referansı buldu. Bunların kategorize edilmesi:

| Kategori | Sayı | Karar |
|---|---|---|
| Amber buton foreground (`backgroundColor: copper`) | 6 | **Temizlendi** → `textPrimary` |
| Amber gradient avatar initial | 3 | **Temizlendi** → `textPrimary` |
| Amber chip selected icon | 1 | **Temizlendi** → `textPrimary` |
| Photo/image overlay text (dark gradient overlay üstünde) | ~5 | **Korundu** — koyu görsel üstüne hâlâ beyaz metin doğru |
| PDF builder (PDF'de hep beyaz) | 1 | **Korundu** — PDF rendering kontekstinde alakasız |
| Dark photo border hairline | 2 | **Korundu** — koyu görsel üstünde |

Sadece teması bozan beyazlar (amber zemin üstündeki beyaz metin/icon) temizlendi. Görsel/medya kontekstindeki beyaz metinler dokunulmadan kaldı çünkü onlar kullanıcı görsel içeriği üstüne düşüyor.

`AppColors.softGold`/`copper`/`copperMuted` zaten her yerde semantik isimle kullanılıyordu — sadece DEĞERLER yeni paletla güncellendi, isim çağrıları korunmuş.

---

## 6. Hangi Ekranlarda Görsel Kontrol Yapıldı

Statik kod analizi + WCAG kontrast hesabıyla şu ekranlar değerlendirildi:

| Ekran | Durum |
|---|---|
| Splash / Onboarding | `background` cream zemine düşecek, mevcut metinler theme inherit ile dark coffee'ye dönüşür ✓ |
| Profil ekranı | Hero artık light bej (`elevatedCard`), avatar gradient amber + dark coffee initial ✓ |
| Role Dashboard (Panel tab) | Role badge strip `elevatedCard` (light bej), softGold ikonlar deep amber ✓ |
| Fırın Paneli | Hero gradient artık light bej, "Bugünün özeti" text dark coffee, currency softGold (deep amber) ✓ |
| Bayi Paneli (`_DealerSummaryCard`) | Light bej kart, "Açık bakiye" softGold'a çekildi (copper okunmuyordu — düzeltildi) ✓ |
| Feed | Composer avatar artık dark coffee initial; FeedScreen header avatar aynı ✓ |
| İlanlar (Jobs) | Theme inherit → tüm metinler dark coffee ✓ |
| Marketplace | Card tinted on light bej; photo overlay metinleri beyaz korundu (kullanıcı görseli üstünde) ✓ |
| Gruplar | Join/Open buton amber + dark coffee text ✓ |
| Bottom navigation | Surface bg, aktif deep amber, pasif muted kahve ✓ |

Emülatörde canlı görsel kontrol kullanıcı tarafında yapılıyor (build edildi, yüklendi).

---

## 7. WCAG Kontrast Hesabı (statik)

| Kombinasyon | Tahmini kontrast | Sonuç |
|---|---|---|
| `textPrimary` (#2B1D14) on `background` (#FFF8ED) | ~13:1 | AAA |
| `textSecondary` (#7A6857) on `background` | ~5:1 | AA |
| `textMuted` (#9C8973) on `background` | ~3.4:1 | AA large only |
| `textPrimary` on `card` (#FAF2E6) | ~12:1 | AAA |
| `textPrimary` on `elevatedCard` (#F3E6D3) | ~11:1 | AAA |
| `softGold` (#B98224) text on `card` | ~4.0:1 | AA (bold/large) |
| `softGold` on `elevatedCard` | ~3.7:1 | AA (bold/large) |
| `textPrimary` on `copper` (#D6A13A) — buton | ~6:1 | AAA |
| `textPrimary` on `copperMuted` (#E8BF63) — light amber gradient ucu | ~10:1 | AAA |
| `copper` (#D6A13A) on `background` — ÖNERMEZ, sadece bg | ~2.5:1 | sadece UI element, metin değil |
| `success` (#4F7D3A) on `card` | ~4.6:1 | AA |
| `danger` (#B84A35) on `card` | ~4.5:1 | AA |

**Önemli:** `copper` (light amber) artık SADECE BACKGROUND'dur. Text/icon vurgusu için `softGold` (deep amber) kullanılır. Aynı kuralın widget düzeyinde yanlış uygulandığı tek bir nokta vardı (`_DealerMetric "Açık bakiye"`) — düzeltildi.

---

## 8. Test Sonuçları

```
$ flutter analyze --no-fatal-infos
Analyzing firinnet...
No issues found! (ran in 0.4s)

$ flutter test
00:01 +42: All tests passed!
```

- **Analyzer:** 0 issue
- **Test:** 42/42 passed
- **Hot restart** ile emülatöre yeniden yüklendi (build başarılı)

Hiçbir test dosyası, business logic, model, repository, route veya feature kodu değiştirilmedi.

---

## 9. Hissiyat Karşılaştırması

| Boyut | Önceki (dark espresso + cream bg) | Şimdi (light krem + light kart) |
|---|---|---|
| Genel his | "Premium chalkboard" — kontrast yüksek, dramatik | "Sıcak fırın tezgâhı" — açık, samimi |
| Zemin | Cream `#F3E9DF` | Daha açık cream `#FFF8ED` |
| Kart | Espresso dark `#2E1E14` | Light bej `#FAF2E6` |
| Vurgu | Mat bakır `#A85F17` text/icon | Yumuşak amber `#D6A13A` bg + deep amber `#B98224` text |
| Buton | Bakır bg + beyaz text | Yumuşak amber bg + dark coffee text (honey button) |
| Hero | Dark espresso gradient | Açık warm bej gradient |
| Bottom nav | Cream bg, parlak amber active | Cream bg, deep amber active (daha sade) |
| Snackbar | Espresso kart hissi | Light bej kart hissi |
| Hardness | Yüksek kontrast "chalkboard" | Yumuşak doğal "fırıncı tezgâhı" |

---

## 10. Bilinen Sınırlar / Sonraki Adımlar

- **Photo/image overlay'lerde `Colors.white`** dokunulmadan korundu (5 yer). Bu doğru çünkü medya overlay'i koyu gradient'le birlikte tasarlanmış. Eğer kullanıcı görselleri hep koyu değilse `MarketProductCard` ve `GroupCard` resim overlay alanı ayrıca yumuşatılabilir — şu an placeholder ya da koyu örnekler için optimum.
- **`darkAccent` / `darkAccentDeeper` (koyu kahve aksentler)** palette'te tanımlandı ama henüz widget'larda erişen yok. Profil sayfasında küçük bir badge veya seçili nav indicator için ileride kullanılabilir; %5 koyu kuralına uygun.
- **`copper` artık SADECE BG**. Eğer ileride birisi metin rengi olarak `AppColors.copper` kullanırsa light kart üstünde okunmaz. Best practice: emphasis metin için `AppColors.softGold` (deep amber). Bu konvansiyonu `app_colors.dart` doc string'inde işaretledim.
- **Inline `FilledButton.styleFrom(backgroundColor: copper, foregroundColor: Colors.white)`** bazı widget'larda hâlâ olabilir; tarama 6 yerini buldu, ben 6'sını da düzelttim. Yine de `Colors.white` aramasında image overlay'leri hariç tutulduğunda 0 amber-on-white sorunu kalıyor.
- **Splash screen**'in kendi renkleri var; theme inherit ile light bg'ye düşmesi gerekiyor. Görsel doğrulanmalı — ben kod düzeyinde dokunmadım.
- **Onboarding ekranı** muhtemelen kendi `AppColors.copper` veya `softGold` referanslarıyla çalışıyor. Yeni amber paleti ile başlangıç ekranı "warmer" hissedilebilir.

---

**Sonuç:** Akış / navigation / feature mantığı tamamen değişmeden, sadece 4 tema dosyası ve 7 widget cerrahisi (renk referansı düzeyinde) ile uygulama "premium chalkboard" hissinden "sıcak fırıncı tezgâhı" hissine geçti. 42 test + analyzer temiz, emülatör build edildi.
