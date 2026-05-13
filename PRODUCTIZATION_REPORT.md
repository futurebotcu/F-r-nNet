# FırınNet — PASS 3 Productization & Real Experience Raporu

**Tarih:** 2026-05-09
**Aktif proje dizini:** `C:\dev\firinnet`
**Uygulama adı:** FırınNet
**Android paket:** `com.firinnet.firin_defter`
**Önceki pass’ler:** `UI_REDESIGN_REPORT.md` (PASS 1) · `UI_POLISH_REPORT.md` (PASS 2)

---

## 0. Kapsam ve Sınırlar

PASS 3 hedefi: “premium görünen demo” → **“gerçek yaşayan ürün”** hissi.

Dokunulmayanlar:
- Repository / provider / router / iş mantığı
- `RecipeCalculator`, `ReportBuilder`, model sınıfları
- Supabase / Firebase / herhangi bir backend (zaten yok; PASS 3’te de yok)

Dokunulanlar:
- Mock data (Feed / Market / Jobs) — gerçekçilik
- Brand strings (`AppStrings`) — kapsam genişlemesi
- Yeni interaction primitive’leri (`PressScale`, `AnimatedNumber`, `FadeSlideIn`)
- Card detayları (Market / Jobs / Feed) — yeni alanlar (seller, note, shift, badge)
- Panel ekranı — Topluluk ipuçları section’u (statik, içerikten bağımsız)
- Onboarding & splash copy
- Visual consistency QA taraması

---

## 1. Gerçekçilik İyileştirmeleri

### Feed (`feed_screen.dart`)
- **3 → 5 post.** Her biri konu, ton ve uzunluk farklı: simit fermantasyonu, un analiz raporu, börek sosu, taş fırın sıcaklık eğrisi, yaz mayası ipucu.
- Yazar etiketleri sektörel: **Usta Fırıncı · Konya**, **Uncu · Toptan tedarik**, **Pastacı · İstanbul Kadıköy**, **Fırın Sahibi · Gaziantep**, **Mayacı · İzmir**.
- Zaman damgaları doğal: `2 sa önce`, `5 sa önce`, `Dün, 18:42`, `1 gün önce`, `2 gün önce`.
- **Gönderi-bazlı badge** (FeedPostCard yeni `badgeLabel` parametresi): `Atölye / Tedarik / Tarif / Üretim / İpucu` — placeholder gradient üstündeki pill artık postun türünü söylüyor.
- Tag sistemi sektörel: `#ekşimaya #simit #usta`, `#un #tedarik #yenihasat`, `#taşfırın #geceüretimi #ekmek`, `#maya #yazreçetesi #fermantasyon`.
- Story strip 7 → **9 öğe** + sektörel isimler (`Taş Fırın`, `Ege Susam`).

### Market (`marketplace_screen.dart`)
- 5 → **6 ürün + 1 featured** (toplam 7 listing).
- Filter chip seti `Tümü, Ekipman, Hammadde, Fırınlar, İkinci El` → **`Tümü, Hammadde, Ekipman, Devren Fırın, İkinci El, Ambalaj`** (ürün-yelpazesini daha iyi yansıtıyor).
- Featured: “Faal mahalle fırını — devren satılık, **Ankara · Çankaya, ₺ 850.000**” + “38 yıllık müşteri sirkülasyonu” notu + satıcı adı.
- Yeni listingler:
  - Spiral mikser 80 L (₺ 54.000, İstanbul · Bayrampaşa, **Kara Endüstri** — 2022, az kullanılmış)
  - Tip 550 ekstra un · 25 kg paket (₺ 780, Konya, **Konya Değirmen** — yeni hasat, protein 13.2)
  - Döner katlı taş tabanlı pide fırını (₺ 180.000, Bursa · Osmangazi, **Mehmet Usta** — 5 katlı)
  - Hamur yoğurma robotu 25 L (₺ 32.500, İzmir · Karşıyaka, **Egem Ekipman** — bakımlı)
  - Kuru maya 500 gr vakumlu (₺ 195, İzmir, **Ege Mayacılık**)
  - Susam doğal 5 kg (₺ 1.450, Şanlıurfa, **Urfa Susam** — beyaz/yıkanmış)
- `MarketProductCard` API’si genişledi: yeni `seller`, `note` parametreleri. Kart artık başlık, fiyat, durum-notu, şehir + **satıcı adını** (softGold, w600) gösteriyor.
- “Öne çıkan” pill: ikon (premium rosette) + copper gölge → `featured` rim ile uyumlu premium hiss.
- V2 hint metni güncellendi: “mesajlaşma, doğrulanmış satıcı ve gelişmiş filtre”.

### Jobs (`jobs_screen.dart`)
- **Hiring tab 3 → 4, Looking tab 2 → 3.**
- Roller daha sektörel:
  - Taş Fırın Ustası (₺ 38.000–45.000, **gece vardiyası**, 5+ yıl)
  - Pastacı Yardımcısı (₺ 24.000 + servis, Gündüz · 09–18)
  - Tezgâh & Sipariş Sorumlusu (₺ 22.000, **vardiyalı 07–15 / 15–23**)
  - Pide Ustası (₺ 30.000, Antep Pide Evi)
  - 12 yıllık ekşi maya ustası (Beklenti ₺ 40.000+, gece üretimi tercih)
  - Pastacı (atölye odaklı), Tezgâh & sipariş yardımcısı
- `JobOpportunityCard` API’si genişledi: yeni `shift` parametresi → ekstra etiket satırı (saat ikonuyla `Gece vardiyası`, `Gündüz · 09–18` vb.).
- Başvur butonu: `FilledButton` → `FilledButton.icon` (send_rounded), letter-spacing/weight artırıldı.
- “Apply” copy artık `AppStrings.jobsApply`.

---

## 2. Panel UX — “Premium Command Center” adımı

`bakery_panel_screen.dart` artık dört bölümlü:

1. **Today hero** — `FadeSlideIn` ile yumuşak giriş; net özet `AnimatedNumber` ile **0 → değer arası 720 ms ease-out** sayım animasyonu; CANLI rozeti artık nokta-puls + copper rim ile küçük bir badge.
2. **Hızlı işlemler** — PASS 2’deki featured + 5 mini grid korundu; tüm tile’lara `PressScale 0.97` eklendi (iOS-vari basma hissi).
3. **Son hareketler** — empty state aynen (CTA ile), data varsa eski liste.
4. **Bugün ağdan** *(yeni)* — `_CommunityTips` static section: 3 kart
   - **Bugünün ipucu** (softGold, ateş ikon) → “Yaz aylarında maya %0.2 düşür”
   - **Topluluktan** (success, trending_up) → “Bu hafta öne çıkan tedarikçi: Konya Değirmen…”
   - **Hatırlatma** (info, event_note) → “Gün sonu kapanışı yapmadın”

> Empty hissi azaltıldı: kullanıcının verisi olmasa bile Panel ekranı dolu, **statik ama sektörel** içerikle yaşıyor. Iş mantığına dokunulmadı, sadece UI section eklendi.

---

## 3. Yeni Interaction Primitive’leri — `lib/core/widgets/interactions.dart`

| Widget | Görev | Spec |
| --- | --- | --- |
| `PressScale` | Tap edildiğinde child’i hafifçe (default 0.97) küçülterek tactile basma hissi | `Listener` + `AnimatedScale`, 110 ms ease-out |
| `AnimatedNumber` | Sayısal değerleri 0 → V interpolasyonu | `TweenAnimationBuilder<double>`, `AppDuration.normal`, easeOutCubic |
| `FadeSlideIn` | Hero kartların ilk frame’de yumuşak girişi | `AnimatedSlide` + `AnimatedOpacity`, 320 ms easeOutCubic |

Uygulanan yerler:
- `QuickActionTile` & `QuickActionMini` → `PressScale`
- `_TodayHero` → net özet `AnimatedNumber`, dış kabuğu `FadeSlideIn`

Scroll polish:
- Feed, Market, Jobs, Panel ListView/CustomScrollView’larına **`BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`** — iOS-vari overscroll hissi (Android default ClampingScrollPhysics yerine).

Bottom nav (PASS 2’den): zaten `AnimatedSwitcher` + `AnimatedOpacity` vardı, korundu.

---

## 4. Brand Immersion (`AppStrings`)

PASS 3 öncesi: **38** sabit. Sonrası: **62** sabit. Eklenen alanlar:

- **Marka:** `appPitch` (“Fırıncının dijital ağı”), `appLongPitch` (“Atölyenden tedariğine, sektöründen müşterine — bir ağa bağlı.”), `launchHint` (“Tezgahın yanında her gün.”).
- **Onboarding:** `onboardingTitle`, `onboardingSubtitle` (iki satırlı pitch), `onboardingFooter` (“Profil olmadan da kullanabilir, dilediğin zaman kayıt olabilirsin.”).
- **Feed/Market/Jobs section başlıkları:** `feedSectionStories: 'Atölyeden anlık'`, `feedSectionPosts: 'Bugün ağda'`, `marketSubtitle: 'Fırıncının B2B pazarı'`, `marketHintV2`, `jobsListHiring`, `jobsListLooking`.
- **Panel:** `panelHeroLabel`, `panelHeroLive`, `panelHeroSub`, `panelSectionTips: 'Bugün ağdan'`, `panelEmptyTitle / Sub / Cta`.
- **Recipe:** `recipeHint` artık `AppStrings`’te.

Hardcoded Türkçe metinler `AppStrings`’e taşındı. Tek istisna: mock data (`_Post.content` gibi) — mock olduğu için sabit kalmalı.

### Onboarding ekranı zenginleşti
- Logo + büyük başlık + alt metin (eski) + **3 highlight tile** *(yeni)*:
  - 🥖 Atölyenden anlık paylaş
  - 🏪 Tedarikçi ve ekipman ağı
  - 📋 Gün sonu cebinde, tek tap
- Buton sırası altında ek **footer mikro-metni**: profilsiz kullanım hatırlatması.

### Splash
- Tagline `AppStrings.appPitch` → `“Fırıncının dijital ağı”`.
- Yeni alt satır `AppStrings.launchHint` → `“Tezgahın yanında her gün.”`

---

## 5. Visual Consistency QA

Hardcoded `Color(0xFF…)` taraması:
- **Tema dosyaları (`app_colors.dart`)** — tüm semantik token’lar burada. ✓
- **Mock gradient’ler (Feed/Market post placeholder’ları)** — bilinçli olarak inline; bunlar “mock fotoğraf” yerini tutuyor, semantik renk değil. Fix kapsamı dışı.

Spacing / radius / shadow tutarlılığı:
- `AppSpacing.{xs|s|m|l|xl|xxl|pageH}` her yerde — magic number yok.
- `AppRadius.{s|m|l|xl|pill}` — `borderRadius: BorderRadius.circular(<sayı>)` doğrudan numara kullanılan tek yer onboarding logo (`22`) ve splash logo (`22`) — marka logosu için bilinçli özel ölçü, kabul edilebilir.
- `AppShadow.{card|copper|heroGlow|subtle}` — tüm kartlar tek katmandan çekiliyor.

Typography:
- AppBar başlıkları `w800`, body’ler `w500/600/700` — Roboto + letter-spacing token’lı.
- Section label’lar `titleMedium w800 letter -0.1`.
- Stat hero değerleri `w800 letter -0.8…-1.2` (PASS 2 token’ları).

Accent:
- `softGold` her zaman ikincil vurgu / bağlantı.
- `copper` birincil CTA / featured rim / hero glow.
- `success / danger / info` → metric pill, recent rows, tip card type.

---

## 6. Final QA — `flutter analyze` / `test` / build / smoke

| Kontrol | Sonuç |
| --- | --- |
| `flutter analyze` | **No issues found! (0.4 s)** |
| `flutter test` | **All tests passed! (5/5)** — RecipeCalculator + placeholder |
| `flutter build apk --debug` | **Built `build/app/outputs/flutter-apk/app-debug.apk`** |
| `adb install -r` | **Success** |
| Smoke test | Onboarding → Feed → Market → Panel → Jobs → Profile → Reçete → Gün Sonu → Rapor — overflow / clipping yok, tüm tab geçişleri sağlıklı |

Overflow / clipping notları:
- Tüm liste satırlarında `maxLines` + `overflow: TextOverflow.ellipsis`.
- Hero kartında 38 px değer + tek satır + ellipsis (paritesi).
- Quick actions mini grid `aspectRatio 1.55` — text 2 line max, ellipsis. Test edildi.
- Job tag bar 2x2 grid (4 tag) — `Flexible` + `ellipsis` her tag’de.

---

## 7. Screenshot Seti — `qa-screenshots/redesign-pass-3/`

| Dosya               | PASS 3 (bayt) | PASS 2 (bayt) | Δ      |
| ------------------- | ------------: | ------------: | -----: |
| `01_onboarding.png` |        39 586 |       115 251 |  −76k  |
| `02_feed.png`       |       225 141 |       207 146 |  +18k  |
| `03_market.png`     |       221 517 |       188 110 |  +33k  |
| `04_panel.png`      |       199 059 |       197 380 |   +2k  |
| `05_jobs.png`       |       207 308 |       182 139 |  +25k  |
| `06_profile.png`    |       177 609 |       176 955 |   +1k  |
| `07_recipe.png`     |       101 549 |       102 081 |   −1k  |
| `08_day_end.png`    |        83 940 |        84 414 |   ±0k  |
| `09_report.png`     |        92 097 |        92 510 |   ±0k  |

> Boyut artışı (Feed/Market/Jobs): yeni kart elemanları (seller adı, note, shift) + tag pill yoğunluğu.
> `01_onboarding` küçüldü: PASS 2’de geri-ile kapatılmamış klavye/sistem barı kalmıştı; PASS 3’te temiz onboarding state yakalandı.
> Rapor / Gün Sonu / Recipe — empty state ve sade form ekranları olduğu için aynı boyut civarında.

---

## 8. Marka Dili Kararları

- **Konuşma tonu:** Sade, doğrudan, ustaca. “Atölyenden anlık”, “Bugün ağda”, “Net özet — bayi tutarı eksi fire zararı.”
- **Çağrı dili:** Komut değil, davet. `"İlk üretimi gir"`, `"Üretim Gir"`, `"Profil oluştur"`.
- **Uppercase mikro-rozetler:** `CANLI`, `SONUÇ`, `BUGÜNÜN İPUCU`, `TOPLULUKTAN`, `HATIRLATMA` — `letter-spacing 1.0–1.4`, `w800`, semantic accent.
- **Sektör jargonu:** `ekşi maya, fermantasyon, taş fırın, gece vardiyası, tezgâh, devren, hamur yoğurma robotu, kuru maya, susam` — okuyan ustanın “bu adam fırından anlıyor” hissi vermesi için bilinçle seçildi.
- **Lokalizasyon kararı:** Sayı formatlama `tr_TR`, fiyatlar `₺ X.XXX` (boşlukla), tarih `9 Mayıs, Cumartesi`, saat `Dün, 18:42`.

---

## 9. Hâlâ Demo Hissi Veren Alanlar (kasıtlı)

Bunlar PASS 3 kapsamı dışında bırakıldı (backend/iş mantığı gerekirdi):

1. **Profile stats** — `12 paylaşım / 186 bağlantı / 4 yıl` hâlâ statik mock.
2. **Feed etkileşim sayıları** — like/comment hardcoded; tap reaksiyonu yok.
3. **Market “Başvur / İletişime Geç”** — tap callback `_noop`.
4. **Jobs “Başvur”** — onApply default callback yok.
5. **Search bar** — TextField var ama filtreleme yok.
6. **ChoiceChip filter** — index değişiyor ama listing filtrelenmiyor.
7. **Feed image** — gerçek fotoğraf yerine gradient placeholder; CDN entegrasyonu olunca açılır.
8. **Bildirimler** — header’daki bell ikon `_noop`.
9. **Gün Sonu/Rapor empty state** — gerçek günlük veri olmadığında doğru, ama aktif veri akışı için bir “demo seed” (Repository’ye dokunmadan) yok.

---

## 10. PASS 4 İçin Önerilen Adımlar

PASS 3 sunum + içerik gerçekliğini eline alıp “yaşayan ürün” hissi getirdi. PASS 4 doğal sonraki halka:

1. **Mock data ↔ Repository köprüsü:** Profil “Misafir” modunda geldiğinde `LocalBakeryRepository`’e demo seed (3 üretim, 2 bayi teslim, 1 fire) eklenebilir → Panel & Day End ilk açılışta dolu görünür. **Iş mantığı dokunmaz**, sadece bir “seed” constructor flag’i.
2. **Etkileşim devamı:** Like / save / comment butonlarına optimistic UI (`AnimatedSwitcher` ile sayı geçişi, kalp doluyor animasyonu).
3. **Market filter & search:** ChoiceChip ve TextField’ın bağlanması (yine local; `_items.where(...)`).
4. **Detay sheet’leri:** Market product tap → bottom sheet (görseller, satıcı kartı, “İletişime Geç” CTA). Jobs Apply → bottom sheet.
5. **Notifikasyon merkezi:** Header bell tap → minimal “Sektör güncellemeleri” liste.
6. **Skeleton & loading:** `AsyncValue.loading` için her ekrana kart-iskeleti.
7. **Hero parallax:** Today hero ScrollController’la küçük parallax yumuşaması.
8. **Push state simülasyonu:** Demo amaçlı bir “Bugün 3 yeni ilan eklendi” banner (tek tap kapanır).
9. **Ses & haptic:** `HapticFeedback.lightImpact()` PressScale’e eklenebilir.
10. **Light theme:** PASS 3 boyunca dark-only kaldı; PASS 4’te `ThemeMode.system` desteklenebilir.
11. **i18n hazırlığı:** `AppStrings` zaten merkezi; `flutter_localizations` ile EN tablosu için temel hazır.
12. **Erişilebilirlik:** `Semantics` etiketleri, `MergeSemantics`’le card içi grupların temizlenmesi (özellikle `_QuickActionMini` için).

---

**PASS 3 durumu:** ✅ Kapatıldı.
PASS 4 kod değişikliklerine henüz başlanmadı.
