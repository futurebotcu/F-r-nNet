# FırınNet — UI Redesign PASS 2 Raporu (Visual Polish & Hierarchy)

**Tarih:** 2026-05-09
**Aktif proje dizini:** `C:\dev\firinnet`
**Uygulama adı:** FırınNet
**Android paket adı:** `com.firinnet.firin_defter`
**Önceki pass:** `UI_REDESIGN_REPORT.md` (PASS 1, 2026-05-09 sabah)

---

## 0. Kapsam

PASS 2 yalnızca **sunum katmanını** rafine etti. Aşağıdakilere dokunulmadı:

- Repository / provider / router (`lib/features/**/repositories`, `providers`, `lib/app/router`)
- İş mantığı / servisler / modeller (`recipe_calculator.dart`, `report_builder.dart`, model sınıfları)
- Supabase, Firebase, MCP entegrasyonları (zaten yok)
- Test koşum davranışı (yalnızca yeni testler eklenmedi; mevcut 5 test geçiyor)

Hedef: visual hierarchy, spacing, typography, surface quality, card density, empty state quality ve premium bakery network hissi.

---

## 1. Tema & Token Katmanı

### `lib/app/theme/app_tokens.dart` — yeni gölge katmanları

| Token | Kullanım | Spec |
| --- | --- | --- |
| `AppShadow.card` *(yeni)* | Tüm `PremiumCard`, kart-türevi yüzeyler | `0x29000000`, blur 18, dy 8 |
| `AppShadow.floating` *(yeni)* | Üst katman (modal, floating panel) | `0x33000000`, blur 28, dy 14 |
| `AppShadow.heroGlow` *(yeni)* | Today / Profile hero kartları | iki katman: koyu derinlik + copper halo (`alpha 0.10`) |
| `AppShadow.soft / subtle / copper` | Korundu | — |

### `lib/app/theme/app_colors.dart` — semantik token + temizlik

- **Yeni:** `borderHairline` (`#26211D`) — koyu kartlarda hissedilir-hissedilmez kenar.
- **Yeni:** `heroFrom` / `heroTo` (`#2C1F18` → `#1A1612`) — hero kartlarda tek kaynaklı gradient.
- **Kaldırıldı (legacy alias):** `copperBright`, `copperDeep`, `ember`, `surfaceHigh`, `warning` — PASS 1’in sonunda “PASS 2’de temizlenebilir” notu vardı, temizlendi.

### `lib/app/theme/app_theme.dart`

- `appBarTheme`: `scrolledUnderElevation 0`, `titleSpacing 4`, `toolbarHeight 60`, başlık `w800` + `letter -0.3` — sub-screen başlıkları daha net.
- `inputDecorationTheme`: `enabledBorder` ve `border` artık `borderHairline` ince kenarla geliyor — input alanları kart sistemine entegre.
- `chipTheme`: `borderHairline` kenar — seçili-olmayan chip'lerde kart hissini güçlendiriyor.

---

## 2. Premium Component Sistemi

### `PremiumCard` — derinlik kazandı

| Özellik | Önce | Sonra |
| --- | --- | --- |
| Gölge | yok | `AppShadow.card` (default açık) |
| Kenar | yok | `borderHairline` 0.6 px (default açık) |
| API | `padding`, `onTap`, `warm`, `radius` | + `bordered`, `elevated` (her ikisi de default `true`) |

> Etki: tüm kart-türevi widget'lar (StatCard, FeedPostCard'taki dış kart, EmptyState ikon kutusu, vb.) tek seferde editorial kart hissi kazandı.

### `EmptyState` — yeniden yazıldı

- Eski: tek paragraf + sade ikon kutusu (legacy `surfaceHigh` / `copperBright`).
- Yeni:
  - Gradient ikon kutusu (`elevatedCard → card`) + `borderHairline` + `AppShadow.copper` halo
  - Başlık `titleLarge w800 letter-0.3`, alt metin `height 1.5`
  - **Opsiyonel CTA**: `actionLabel` + `onAction` → bakır renkli `FilledButton.icon`
  - `compact: true` — liste içinde gömülü kullanım için
- Legacy alias bağımlılığı tamamen kalktı.

### `PremiumBottomNav` — animated indicator

- Üst hairline `surfaceLine` → `borderHairline` (-0.6 px), alt katmana `AppShadow.subtle` glow.
- Selected indicator: 28×2 düz line → **36×2.5 copper→softGold gradient** + softGold halo.
- İkon değişimi `AnimatedSwitcher` + `ScaleTransition`.
- Indicator `AnimatedOpacity` ile yumuşak geliş.
- Yükseklik 70 → 72 (1 satır alt-üst hava).

### `StatCard` — `hero` variant

- Yeni `hero: true` parametresi: `AppSpacing.xl` padding, **value 26 → 32 px**, label letter-spacing 0.8 → 1.0, helper bakır renk + `w600`.
- EndOfDay net özet artık hero modunda — ekranın görsel ağırlık merkezi oldu.

### `SectionLabel` — chevron + ayarlanabilir gap

- `trailingLabel` artık **chevron** ile birlikte (`InkWell`-tap, soft padding).
- `topGap` / `bottomGap` parametreleri default `xl / m` — section'lar arası ritim daha hava aldı.

### `FirinNetHeader`

- Logo: 36 → 38 px, copper-glow gölge eklendi (`alpha 0.25`).
- Başlık: `letter -0.4 height 1.1`.
- Alt-padding `s` → `m` (header → ilk içerik daha rahat).
- `HeaderActionButton`: `borderHairline` çevre + softGold splash.

### `QuickActionTile` + yeni `QuickActionMini`

- `QuickActionTile` artık ayrı `Container` ile gölge sarıyor (`featured` ise `AppShadow.copper`, değilse `AppShadow.card`); featured kenarlık `copper alpha 0.32`.
- İkon kutusu 40 → 42 px; chevron featured’da softGold.
- **Yeni `QuickActionMini`**: 2-col grid için kompakt — ikon top, label bottom, no subtitle, no chevron.

### `MetricPill`

- Arka plan `surface` → `overlay alpha 0.55` (daha “glass” his).
- `borderHairline`+ accent renk alpha 0.18 ince kenar; nokta indicator’a glow.
- Tipografi `bodyMedium` → fontSize 13 `w800` letter -0.1.

### Kart polish'leri

- `FeedPostCard`: hairline border + `AppShadow.card`. Etiketler düz `#tag` → bakır pill (`alpha 0.10`).
- `MarketProductCard`: `Material` artık `Container`'a sarılı — `featured` için `AppShadow.copper` + bakır kenar; standart için `AppShadow.card` + hairline.
- `JobOpportunityCard`: aynı sarmalama — featured copper rim, standart hairline.

---

## 3. Ekran-Bazlı Polish

### Feed (`feed_screen.dart`)
- Story strip yüksekliği 96 → 92, ayraç 12 → 14 px; avatar gradient `topLeft→bottomRight`; isim font 11.5 → 11 letter +0.1.
- “Sen” avatarı için `borderHairline` çevre.
- Section label artık chevron'lu trailing.

### Market (`marketplace_screen.dart`)
- Search bar prefixIcon `textMuted` → `softGold` (active feel); style 15px w500.
- Search üst-padding `s` → `xs` (header altına yapışık his azaldı).
- “V2 hint” düz metinden **bakır ikonlu hairline kart**’a dönüştü.

### Bakery Panel (`bakery_panel_screen.dart`) — en büyük değişim

**Today hero (TodayHero)**
- Inline `Color(0xFF...)` → `AppColors.heroFrom / heroTo` semantik referans.
- `AppShadow.heroGlow` (copper halo) + `copper alpha 0.18` çerçeve.
- Header satırına “**CANLI**” mikro-rozeti (uppercase, letter 1.2, softGold).
- Net özet 36 → 38 px, letter -1.0 → -1.2, height 1.05.
- Helper alt metni daha sakin (`textSecondary` 12.5).
- Alt padding `l` → `xl` (pill satırının nefesi arttı).

**Quick Actions**
- 6 öğeli düz dikey liste → **1 featured (Reçete) + 2-col grid (5 mini)**.
- Featured: `QuickActionTile` (subtitle dahil) — copper-glow rim.
- Mini'ler: `QuickActionMini` — `GridView.count` aspect 1.55, hairline kenar.
- Sonuç: dikey alan ~20% azaldı, “control center” okunabilirliği arttı.

**Recent list empty**
- Tek paragraf → ikon + başlık + alt metin + **“İlk üretimi gir” CTA** (`/panel/production`'a push).

### Jobs (`jobs_screen.dart`)
- Segment container'a `borderHairline` ekstra çerçeve.
- Selected segment: `40 → 44` px, `AppShadow.subtle`, `copper alpha 0.22` kenar, label `w700 → w800` letter -0.1.
- Hover/press hissi netleşti.

### Profile (`profile_screen.dart`)
- Profile hero: `heroFrom/To` + `copper alpha 0.18` rim + `AppShadow.heroGlow`.
- Avatar 56 → 60 px + copper alpha 0.30 dış glow.
- Name letter -0.3 height 1.1; role label `w700` letter +0.2 fontSize 13.5.
- Empty state (profil yok): yeni `EmptyState` + “**Profil oluştur**” CTA → `/profile/create`.

### Recipe (`recipe_calculator_screen.dart`)
- Yalnızca sonuç bölümü için kullanılan `SectionLabel`, daha editorial bir caps-label'a (`SONUÇ`) dönüştü — `softGold w800 letter 1.4`. Unused `section_label` import temizlendi.

### End of Day (`end_of_day_screen.dart`)
- Empty: yeni `EmptyState` + nightlight ikon + **“Üretim Gir” CTA** → `/panel/production`.
- Tarih satırı küçük caps (uppercase 11.5 letter 1.2 textMuted).
- Net özet artık `hero: true` (büyük rakam, copper helper).

### Report (`report_screen.dart`)
- **Yeni:** `s.isEmpty` durumunda artık `EmptyState` (share ikon, “**Üretim Gir**” CTA) — boş günlerde rapor metni yerine yön gösteriyor.
- Rapor metni font 14 → 13.5, height 1.55 → 1.6 letter +0.1 — monospace okunabilirliği iyileşti.

### Onboarding (`onboarding_screen.dart`)
- Logo kutusu 72 → 76, borderRadius 20 → 22, copper alpha 0.32 dış glow.
- Başlık 34 → 36 px letter -1.0 height 1.05.
- Alt paragraf height 1.5 → 1.55.

---

## 4. Code Cleanup (kullanılmayan dosyalar silindi)

PASS 1 raporunda “PASS 2'de kaldırılabilir” notu vardı; aşağıdaki dosyalar hiçbir ekranda import edilmiyordu:

- `lib/core/widgets/summary_metric_card.dart` — silindi
- `lib/core/widgets/big_action_card.dart` — silindi
- `lib/core/widgets/section_header.dart` — silindi

Birlikte kalkan legacy color alias’ları:

- `AppColors.copperBright`, `copperDeep`, `ember`, `surfaceHigh`, `warning` — silindi.

`flutter analyze` ve `flutter test` kalkışın ardından temiz.

---

## 5. Korunan Mimari

- Riverpod state, GoRouter routing, `BakeryRepository` / `LocalBakeryRepository`, `RecipeCalculator`, `ReportBuilder`, model sınıfları — **değişmedi**.
- `BakeryPanelScreen`'in `_TodayHero / _QuickActions / _RecentList` private widget'ları sadece presentation refactor'u; provider tüketimi (`todaySummaryProvider`) aynı.

---

## 6. Analyze / Test Durumu

- `flutter analyze` → **No issues found! (0.6 s)**
- `flutter test` → **All tests passed!** (5 test, RecipeCalculator + placeholder) — PASS 1 ile aynı.

---

## 7. APK Install Durumu

- Build hedefi: `apk --debug` (cihaza redeploy)
- Cihaz: `emulator-5554` (Android, 1080×2400)
- Paket: `com.firinnet.firin_defter`

---

## 8. Screenshot Dosya Listesi (PASS 2)

Klasör: `C:\dev\firinnet\qa-screenshots\redesign-pass-2\`

> Ekran adları PASS 1 ile birebir aynı — `pass-1 vs pass-2` görsel diff alınabilir.

| Dosya               | PASS 2 (bayt) | PASS 1 (bayt) | Δ      | Tarih               |
| ------------------- | ------------: | ------------: | -----: | ------------------- |
| `01_onboarding.png` |       115 251 |       230 616 |  −115k | 2026-05-09 05:13    |
| `02_feed.png`       |       207 146 |       113 900 |   +93k | 2026-05-09 05:14    |
| `03_market.png`     |       188 110 |       166 651 |   +21k | 2026-05-09 05:14    |
| `04_panel.png`      |       197 380 |       177 399 |   +20k | 2026-05-09 05:14    |
| `05_jobs.png`       |       182 139 |       158 429 |   +24k | 2026-05-09 05:14    |
| `06_profile.png`    |       176 955 |       134 350 |   +43k | 2026-05-09 05:14    |
| `07_recipe.png`     |       102 081 |        98 496 |   +3k  | 2026-05-09 05:15    |
| `08_day_end.png`    |        84 414 |        65 442 |   +19k | 2026-05-09 05:15    |
| `09_report.png`     |        92 510 |        75 792 |   +17k | 2026-05-09 05:15    |

> Boyut farkı değişen pikselin yoğunluğunu yansıtır: gölge / hairline / pill detayları PASS 2'de PNG entropisini artırdı. `01_onboarding`'in küçülmesi PASS 1'in farklı emülatör durumunda (klavye / sistem barı) yakalanmış olmasından; PASS 2'de aynı tema-sahne küçük PNG verdi.
>
> Yardımcı dump dosyaları:
> - `_dump_current.xml` — onboarding dump'ı
> - `_dump_panel.xml` — Panel ekranı dump'ı (mini grid bounds için)

---

## 9. Screenshot Pipeline Notu

PASS 1 ile birebir aynı akış kullanıldı:

1. `adb devices` ile cihaz doğrula.
2. Hedef ekrana git: `adb shell input tap <x> <y>`.
3. **700–1000 ms** bekle.
4. Yakalama: `cmd /c "adb exec-out screencap -p > <hedef>.png"` — PowerShell'in `>` yönlendirmesi PNG'yi UTF-16 olarak bozar; `cmd /c` binary güvenli.
5. Doğrulama: yalnızca `(Get-Item ...).Length` ile dosya boyutu — **PNG içeriği parse edilmedi**.
6. Koordinat tespiti `adb shell uiautomator dump` + XML grep ile yapıldı; **blind tap yok**.
7. Panel alt ekranlarından dönüş `adb shell input keyevent 4`.

---

## 10. PASS 1 → PASS 2 Visual Diff Önerileri

PASS 2 değişimini bir bakışta görmek için önemli karşılaştırmalar:

- `01_onboarding`: logo glow + büyük başlık tipografisi
- `02_feed`: feed kartlarda hairline + tag pill, story strip kompaktlık
- `03_market`: search bar bakır prefix, V2 hint kartı
- `04_panel`: en büyük değişim — hero CANLI rozeti, 1+5 grid quick actions
- `05_jobs`: segment selected state belirginliği
- `06_profile`: hero glow + avatar büyüme
- `07_recipe`: SONUÇ caps label
- `08_day_end`: hero net özet (32 px) + empty state CTA
- `09_report`: empty state varsa CTA (boş veride)

---

## 11. PASS 3 İçin Önerilen Adımlar

PASS 2 sunum katmanını rafine etti; PASS 3 için doğal sonraki halkalar:

1. **Etkileşim & micro-animation:** Quick Actions tap-down scale, hero kartında sayı animasyonu, story strip inertia polish.
2. **Skeleton & loading states:** Repository yüklenirken her kartın iskelet hâli.
3. **Error states:** `AsyncValue.error` için EmptyState benzeri error component (ikon + başlık + retry).
4. **Light theme:** Şu an dark-only; `ThemeMode.system` ve light token eşlenikleri.
5. **Erişilebilirlik denetimi:** `textMuted #6E6864` ve `softGold #D6A56D` arası kontrast WCAG AA testi; semantic label'lar.
6. **PremiumCard varyantları:** `outlined` (no shadow, only hairline), `solid` (no border, with shadow) — şu an her ikisi default, bazı bağlamlarda fazla olabilir.
7. **Iconography:** Material `outlined` / `rounded` karışık kullanım var — tek aile (rounded) tercih edilebilir.
8. **Dependency upgrades:** PASS 1'den taşındı — `riverpod 3.x`, `go_router 17.x`, `share_plus 13.x` major'ları için risk/getiri çalışması.
9. **Text scaling testi:** Cihaz `textScaler` 1.3+ değerlerinde StatCard / hero / FilledButton clipping kontrolü.

---

**PASS 2 durumu:** ✅ Kapatıldı.
PASS 3 kod değişikliklerine henüz başlanmadı.
