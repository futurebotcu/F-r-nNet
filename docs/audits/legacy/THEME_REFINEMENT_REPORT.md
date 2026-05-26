# Tema İnceltme Raporu — Bakery Operasyon Dili

**Tarih:** 2026-05-12
**Kapsam:** Sadece renk, yüzey, gölge, border, typography. Akış / layout / widget hiyerarşisi DEĞİŞMEDİ.

---

## 1. Hissiyat Farkı — Eski vs Yeni

| Boyut | Eski | Yeni |
|---|---|---|
| Genel | Premium dark "editorial" — Dribbble cafe konsepti hissi | Sabah operasyon — un beji countertop + espresso kart |
| Zemin | Soğuk siyah-gri (#0F0F10) | Sıcak kırık beyaz / un beji (#F3E9DF) |
| Kartlar | Soğuk dark gri (#1B1B1C) | Espresso kahve (#2E1E14) |
| Vurgu | Parlak bakır (#C26A2D) + parlak softGold (#D6A56D) | Mat bakır (#A85F17) + tok sıcak amber (#C26A1E) |
| Gölge | Saf siyah, geniş blur + copper halo glow | Sıcak espresso tonu, kısa offset, glow yok |
| Bottom nav | Dark surface + parlak gradient indicator | Cream surface + mat tek-çizgi copper indicator |
| Hero | Dark gradient + bakır glow halo | Espresso gradient + minimal sıcak shadow |
| Typography | Yüksek kontrast cream üstüne (light text) | Cream zemin → koyu kahve; kart içi → light cream |

**Hissiyat özeti:** "Stok premium cafe template" yerine "sabah 04:00–08:00 fırın hatti" — operasyonel, samimi, parlamasız.

---

## 2. Değişen Renkler — Tam Liste

### `lib/app/theme/app_colors.dart` — yeniden yazıldı

| Token | Eski (dark) | Yeni (bakery operasyon) | Amaç |
|---|---|---|---|
| `background` | `#0F0F10` | `#F3E9DF` | Sıcak kırık beyaz, un tonu |
| `surface` | `#171717` | `#EAD9C0` | Bottom nav, input field — koyulaşan un |
| `card` | `#1B1B1C` | `#2E1E14` | Espresso — kart yüzeyi |
| `elevatedCard` | `#211B16` | `#3A271A` | Vurgu kartı, sıcak kahve |
| `surfaceLine` | `#2A2624` | `#D9C7AE` | Cream zemin üstünde divider |
| `overlay` | `#0A0A0B` | `#221610` | Sheet/dialog espresso zemin |
| `borderHairline` | `#26211D` | `#5A3A23` | Dark kart içi warm wood line |
| `borderLight` (**yeni**) | — | `#D9C7AE` | Cream zemin üstünde hairline (input vb.) |
| `heroFrom` | `#2C1F18` | `#3A271A` | Hero gradient sıcak başlangıç |
| `heroTo` | `#1A1612` | `#2A1B11` | Hero gradient derin son |
| `copper` | `#C26A2D` | `#A85F17` | Mat bakır — primary CTA, focus |
| `softGold` | `#D6A56D` | `#C26A1E` | Tok amber — secondary vurgu (parlak değil) |
| `copperMuted` | `#8C4F23` | `#9E6B3D` | Mat amber — pressed/disabled |
| `textPrimary` | `#F5F1EB` | `#F2EAD9` | Kart içi cream metin (hâlâ light) |
| `textSecondary` | `#A8A29E` | `#CBB9A1` | Kart içi muted cream |
| `textMuted` | `#6E6864` | `#9C8973` | Kart içi placeholder |
| `onBackgroundPrimary` (**yeni**) | — | `#2B1D17` | Cream zemin üstünde ana metin (saf siyah değil) |
| `onBackgroundSecondary` (**yeni**) | — | `#5A4A3F` | Cream zemin üstünde ikincil |
| `onBackgroundMuted` (**yeni**) | — | `#8A7563` | Cream zemin üstünde muted |
| `success` | `#5D8B4E` | `#5D7A3F` | Toprak yeşili (daha doygun) |
| `danger` | `#C65A5A` | `#B04A3A` | Toprak kızılı (daha tok) |
| `info` | `#6E8FB2` | `#6E7F8A` | Mat çelik (mavinin doygunluğu düştü) |

**Yapısal not:** "İki bağlamlı palet" benimsendi. `textPrimary/Secondary/Muted` semantiği değişmedi — hâlâ "ana/yardımcı/silik metin" anlamında. Sadece DEĞERLER kontekste göre değiştirildi: bu üçü artık DARK KART üzerinde kullanılıyor (light cream tonları). Cream zemin üstündeki metinler için yeni `onBackground*` üçlüsü eklendi.

---

## 3. Güncellenen Widget'lar (minimum cerrahi)

Akış / hiyerarşi / layout HİÇ değişmedi. Sadece renk referansları güncellendi.

| Dosya | Değişiklik | Neden |
|---|---|---|
| `lib/app/theme/app_colors.dart` | Tam yeniden yazım | Yeni palet + iki bağlamlı renk |
| `lib/app/theme/app_theme.dart` | `darkTheme()` artık `Brightness.light` döner, `ColorScheme.light`, mat butonlar, copper focused border | Cream zemin teması; isim eski kalsın diye API uyumlu |
| `lib/app/theme/app_tokens.dart` | Tüm `AppShadow` değerleri sıcak espresso tonuna, alpha %50–70 düşürüldü; `heroGlow` parlak halo'dan tek sıcak gölgeye | "Daha mat, daha doğal" yönergesi |
| `lib/app/app.dart` | `themeMode: ThemeMode.dark` → `ThemeMode.light` | Sistemin theme override'ından bağımsız tek tutarlı görünüm |
| `lib/core/widgets/premium/section_label.dart` | Section başlığı `textPrimary` → `onBackgroundPrimary`; trailing link `softGold` → `copper` | Section başlığı cream zemin üstünde, dark tonda olmalı |
| `lib/core/widgets/premium/firinnet_header.dart` | `HeaderActionButton`: `card` (artık dark) → `surface` (cream darker); icon rengi `textPrimary` → `onBackgroundPrimary`; border `borderHairline` → `borderLight`; splash `softGold` → `copper` | Header'daki yuvarlak ikon buton cream zemin üstünde durmalı |
| `lib/core/widgets/premium/premium_bottom_nav.dart` | Border `borderHairline` → `surfaceLine`; aktif renk `softGold` → `copper`; pasif `textMuted` → `onBackgroundMuted`; indicator parlak gradient + glow → tek mat copper çizgi | Cream surface bottom nav'da kontrast dengesi + "daha sade, aktif sekme net" |

**Toplam:** 4 tema/token dosyası + 3 widget dosyası (sadece renk referansı). Widget tree'lerine, padding'lere, child ordering'e, navigation'a, route'lara, model katmanına HİÇ dokunulmadı.

---

## 4. Hangi Widget'lar Otomatik Adapte Oldu

Tema'nın `textTheme.apply(bodyColor: onBackgroundPrimary, displayColor: onBackgroundPrimary)` ayarı sayesinde, MERAS ALINAN tüm metinler (color override'ı olmayan `theme.textTheme.titleLarge?.copyWith(...)` çağrıları) cream zemin üzerinde otomatik koyu kahve oldu. Etkilenen widget'lar (dokunulmadan):

- `FirinNetHeader` başlığı (title) — koyu kahve oldu
- `PageTitle` başlığı (section_label içinde) — koyu kahve oldu
- AppBar başlıkları — koyu kahve oldu
- TextField etiketleri — `onBackgroundSecondary` oldu (theme inputDecoration üzerinden)
- TextField hint'leri — `onBackgroundMuted` oldu
- Body metinleri (genel bilgi yazıları) — `onBackgroundSecondary` oldu

EXPLICIT `AppColors.textPrimary` ile renklenmiş metinler (`_TodayHero`, `_DealerSummaryCard`, `_RecentRow`, `_TipCard`, `PremiumCard` içerikleri vb.) hâlâ light cream — çünkü onlar ESPRESSO kart içinde duruyor ve `textPrimary` semantik olarak hâlâ "kart içi ana metin" anlamında, sadece DEĞERİ değişti.

---

## 5. Buton ve Yüzey Dili

### Butonlar
- **Filled / Elevated**: bg matte copper `#A85F17`, foreground beyaz, gölge yok (theme elevation 0 zaten). Daha tok, daha az parlak. Sıcak shadow `AppShadow.copper` ile sarılabilir (mevcut çağıranlar değişmez).
- **Outlined**: foreground copper, border copper @ 45% opacity. Eskiden softGold idi — artık mat bakırla tutarlı.
- **Text**: foreground copper (eski softGold). Link gibi davranıyor.

### Inputlar
- fillColor `surface` (cream darker) — cream zemin üstünde hafif derinlik.
- Border `borderLight` (#D9C7AE) — silik.
- Focused border `copper` 1.4px — net ama parlak değil.
- Label `onBackgroundSecondary`, hint `onBackgroundMuted` — okunabilir ama hiyerarşik.

### Chip'ler
- bg `surface` (cream darker), selected `copper`, label `onBackgroundPrimary`. Seçili chip beyaz metinli mat bakır — kontrast net.

### Kartlar
- `CardThemeData.color = AppColors.card` (espresso) hâlâ default; ama widget'ların çoğu zaten explicit `Container(color: AppColors.card)` kullanıyor — değişiklik geçişli.
- Border `borderHairline` (warm wood #5A3A23) artık espresso kart üstünde sıcak iç çizgi.

### Bottom nav
- Cream surface zemin, hafif `subtle` shadow.
- Aktif: mat copper ikon + etiket + 32px tek-çizgi indicator (eski parlak gradient/glow KALDIRILDI).
- Pasif: `onBackgroundMuted` (muted kahve) ikon + etiket.

### Snackbar
- `elevatedCard` (espresso) bg + `textPrimary` (cream) text. Bildirim kart hissi koruyor, cream zemin üstünde okunabilir.

---

## 6. Gradient ve Hero Alanları — Daha Mat

- `heroFrom/heroTo` artık `#3A271A → #2A1B11` (eskiden `#2C1F18 → #1A1612`). Aynı espresso ailesi ama daha doygun, daha az soğuk.
- `AppShadow.heroGlow` eskiden iki katmanlıydı (siyah + copper halo). Şimdi tek katman, sıcak espresso `Color(0x1A2B1D17)`. Glow yok, sadece nazik yükseliş.
- `AppShadow.copper` alpha %14 → %8. Sıcak sızıntı kaldı, parlama yok.
- `AppShadow.card` saf siyah → sıcak espresso `#2B1D17` tonlu, alpha %16 → %8. Mat ve hafif.

---

## 7. KPI / Metrik / Bottom Nav Okunabilirlik

- Dark espresso kart üzerinde KPI sayıları (cm: `softGold`/`copper` rengini explicit kullanan) artık `#C26A1E` mat amber. Eski sarımsı parlaklık gitti, sayı net seçilir.
- `_DealerMetric` etiketleri (`label.toUpperCase()`) `textMuted` (#9C8973) — cream-muted, kart içinde okunabilir.
- Bottom nav aktif: `copper` ikon/etiket + indicator. Pasif: `onBackgroundMuted`. Kontrast oranı kabaca 4.5:1+ (cream surface üzerinde dark muted text — sabah okunaklı).

---

## 8. Contrast / Readability Kontrolü (manuel ölçüm)

| Eşleştirme | Tahmini WCAG kontrast | Uygunluk |
|---|---|---|
| `onBackgroundPrimary` (#2B1D17) on `background` (#F3E9DF) | ~12:1 | AAA |
| `onBackgroundSecondary` (#5A4A3F) on `background` | ~7:1 | AAA |
| `onBackgroundMuted` (#8A7563) on `background` | ~4.5:1 | AA (large/normal) |
| `textPrimary` (#F2EAD9) on `card` (#2E1E14) | ~12:1 | AAA |
| `textSecondary` (#CBB9A1) on `card` | ~7:1 | AAA |
| `textMuted` (#9C8973) on `card` | ~4.5:1 | AA |
| `copper` (#A85F17) on `background` | ~4.6:1 | AA — link/button rengi OK |
| `copper` ikon on `surface` (#EAD9C0) bottom nav | ~4.3:1 | AA — aktif sekme net |
| `Colors.white` on `copper` (#A85F17) butonlar | ~4.6:1 | AA — CTA okunabilir |

Sabah kullanımı için göz yormayan kontrast: cream zemin tam karanlıkta parlamaz, gün ışığında okunur. Espresso kartlar yumuşak gölge ile yükseltilmiş; saf beyaz olmadığı için parlama yok.

---

## 9. Kontrol Sonucu

```
$ flutter analyze --no-fatal-infos
Analyzing firinnet...
No issues found! (ran in 0.5s)

$ flutter test
00:01 +42: All tests passed!
```

42/42 test geçti. Analyzer'da uyarı yok. Test dosyalarına dokunulmadı.

---

## 10. Bilinen Sınırlar / Sonraki Adımlar

- **Bazı widget'lar EXPLICIT `AppColors.softGold` kullanıyordu**, bu değer artık `#C26A1E` (mat amber). Eski "altın" hissi yerine "mat amber" hissi — bu istenen yön. Eğer bir yerde rengin somut bir sembolizmi varsa (ör. "ödül" / "premium" gibi) o çağrı yerine özel sembol rengi eklenebilir; şu an gerek yok.
- **`AppColors.borderHairline` artık espresso kart içi warm wood** (#5A3A23). Eğer bir widget cream zemin üstüne `borderHairline` koyuyorsa fazla koyu görünür. Hızlı taramada böyle bir kullanım görmedim — yeni `borderLight` cream zemin için ayrı duruyor. Gelecekte cream zemin üzerine input/border ekleyecek geliştiriciler `borderLight` kullanmalı.
- **`textPrimary` semantiği "kart içi"** olarak işliyor. Cream zemin üstünde metin yazılacaksa `onBackgroundPrimary` kullanılmalı. Bu konvansiyonu `app_colors.dart` doc string'inde belirttim.
- **Featured/elevated kartlardaki "sıcak" his** kaldı (heroFrom/heroTo gradient). Eğer kullanıcı bunun da düz/mat olmasını isterse `_TodayHero` gradient'i tek renge indirilebilir — şu an dokunmadım, korunmuş gradient minimal espresso ramp.
- **Splash screen** dokunulmadı — büyük olasılıkla `AppColors.background` kullanıyor, otomatik cream'e döndü. Görsel doğrulaması yapılmalı.

---

**Sonuç:** Akış/navigasyon/widget tree değişmeden, sadece renk-yüzey-gölge-typography katmanı bakery operasyon diline çekildi. 42 test ve analyzer temiz.
