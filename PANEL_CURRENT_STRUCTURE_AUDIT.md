# PANEL_CURRENT_STRUCTURE_AUDIT

**Tarih:** 2026-05-13
**Tür:** Read-only audit (kod değişikliği yok, dosya yazımı yalnız bu rapor)
**Kapsam:** Ticari / Bireysel / Toptancı panelleri, alt akışlar (Fırın Paneli, Bayi Paneli, Reçete)
**Yöntem:** `app_router.dart`, `role_panel_cards.dart`, `app_shell.dart`, `role_dashboard_screen.dart`, `bakery_panel_screen.dart`, `dealer_*_screen.dart`, `dealer_providers.dart`, `marketplace_screen.dart`, `jobs_screen.dart`, ilgili repository dosyaları okundu

---

## 1. Genel Panel Yapısı

### Bottom nav (5 tab) — `app_shell.dart` l.17-58

| Sıra | Tab | Route | Ekran |
|---|---|---|---|
| 1 | Feed | `/feed` | `FeedScreen` |
| 2 | Gruplar | `/groups` | `GroupsListScreen` |
| 3 | Market | `/market` | `MarketplaceScreen` |
| 4 | İlanlar | `/jobs` | `JobsScreen` |
| 5 | Panel | `/panel` | **`RoleDashboardScreen`** |

> Profil sekmesi nav'dan çıkarılmış (kod yorumu: "Feed header avatar üzerinden erişilir"). `/profile` route'u korunuyor, push ile açılıyor.

### `/panel` neyi açıyor?

`/panel` → **`RoleDashboardScreen`** (`lib/features/dashboard/screens/role_dashboard_screen.dart`). Bu ekran rolü `profileControllerProvider`'dan okur, profil yoksa `AccountType.individual` varsayar, ve `RolePanelCards.forAccount(account)` çağrısıyla rol bazlı kart listesi gösterir.

`/panel` **doğrudan** Fırın Paneli'ne gitmiyor. Ticari kullanıcı `/panel` → kart listesi → "Fırın Paneli" kartına basınca `/panel/bakery` push edilir.

### Modüller arası ilişki

```
Bottom nav (sürekli görünür)
├── /feed              FeedScreen        (V1 local mock + composer)
├── /groups            GroupsListScreen  (V1 local mock)
├── /market            MarketplaceScreen (V1 statik mock kartlar)
├── /jobs              JobsScreen        (V1 statik mock kartlar)
└── /panel             RoleDashboardScreen — rol bazlı kart grid'i

Shell üstü (full-screen push'lar)
├── /profile           ProfileScreen
├── /profile/create    CreateProfileScreen
├── /panel/bakery      BakeryPanelScreen (Fırın Paneli — Ticari)
├── /panel/production  ProductionEntryScreen
├── /panel/waste       WasteEntryScreen
├── /panel/end-of-day  EndOfDayScreen
├── /panel/report      ReportScreen
├── /panel/recipe      → REDIRECT → /recipes   (legacy alias)
├── /panel/dealer      DealerDeliveryScreen   (legacy V1, kart grid'inde değil)
├── /recipes           RecipesListScreen
├── /recipes/new       RecipeEditorScreen
├── /recipes/:id       RecipeDetailScreen
├── /recipes/:id/edit  RecipeEditorScreen(recipeId)
├── /dealers           DealerListScreen
├── /dealers/new       AddDealerScreen
└── /dealers/:id{,...} DealerDetail + delivery/return/payment/adjustment/share
```

---

## 2. Ticari Panel

`/panel` ticari kullanıcıya **5 kart** gösteriyor (`role_panel_cards.dart` l.41-72):

| # | Kart adı | Alt metin | Route | Çalışıyor mu? | Coming soon? | Tanım |
|---|---|---|---|---|---|---|
| 1 | **Fırın Paneli** | Üretim, fire, gün sonu | `/panel/bakery` | ✅ | — | `role_panel_cards.dart` l.42-47 |
| 2 | **Bayi Paneli** | Teslimat, tahsilat, hesap | `/dealers` | ✅ | — | l.48-53 |
| 3 | **Reçetelerim** | Hamur hesabı, malzeme, yapılış | `/recipes` | ✅ | — | l.54-59 |
| 4 | İlanlarım | Yayında olan iş ilanların | `/jobs` | ⚠ (Jobs tab statik mock) | — | l.60-65 |
| 5 | Mesajlar | Sohbet & bildirimler | — | ❌ | ✅ | l.66-71 — `comingSoon: true`, snackbar |

**Doğrulamalar:**
- Fırın Paneli ana modül (üretim/fire/gün sonu/rapor + iç içe reçete erişimi).
- Bayi Paneli ana modül (`SupabaseDealerRepository` hibrit, gerçek tabloya yazıyor).
- Reçetelerim ana modül (`SupabaseRecipeRepository` tam Supabase + RLS owner-only).
- "İlanlarım" kartı `/jobs` tabına atıyor ama `JobsScreen` aslında **tüm ilanları gösteren liste** — "Benim ilanlarım" filtresi yok; başlık yanıltıcı (ileride filtre/own-listings için yer açılmış olabilir).
- Mesajlar yalnız placeholder snackbar (`AppStrings.comingSoon`).

**Üretim Gir / Fire Gir / Gün Sonu / Reçete ayrı ticari kart olarak yok** — bunlar ticari kart listesinin altında değil, Fırın Paneli içinde **alt** modüller olarak duruyor (madde 3).

---

## 3. Fırın Paneli İçeriği

`/panel/bakery` → `BakeryPanelScreen` (`lib/features/bakery_panel/screens/bakery_panel_screen.dart`).

### Üst hero
"Bugünün özeti" kartı — Üretim/Bayi/Fire metric pill'leri, animasyonlu net tutar (`todaySummaryProvider`).

### Üretim Yönetimi (`_ProductionActions` l.255-323)

| # | Aksiyon | Route | Çalışıyor mu? | Supabase? | Not |
|---|---|---|---|---|---|
| Featured | **Reçeteler** | `/recipes` | ✅ | ✅ | `_featured` l.258-263, icon `menu_book_outlined` |
| 1/4 | Üretim Gir | `/panel/production` | ✅ | ✅ | `production_entries` tablosuna yazıyor |
| 2/4 | Fire Gir | `/panel/waste` | ✅ | ✅ | `waste_entries` tablosuna yazıyor |
| 3/4 | Gün Sonu | `/panel/end-of-day` | ✅ | ✅ (özet) | `dailySummary` provider |
| 4/4 | Rapor Al | `/panel/report` | ✅ | ✅ (özet → metin) | `share_plus` üzerinden paylaşım |

### Bayi Yönetimi özet kartı (`_DealerSummaryCard` l.340-504)
- `dealersOverviewProvider` — toplam/aktif bayi, açık bakiye, bugün teslim/tahsilat.
- "Bayi Yönetimine Git" butonu → `/dealers`.
- ✅ Çalışıyor, Supabase + local hibrit.

### Son hareketler (`_RecentList` l.549-714)
- Bugünkü production + delivery + waste listeden top 2'şer kayıt.
- Boşken "İlk üretimi gir" CTA → `/panel/production`.

### Topluluk ipuçları (`_CommunityTips` l.717-761)
- 3 sabit statik kart (`_tips` array): "Bugünün ipucu", "Bu hafta öne çıkan tedarikçi", "Hatırlatma".
- **Statik mock veri** — hiç repository/provider yok. Görsel doldurma amaçlı.

### Eksikler

| Talep edilen | Durum |
|---|---|
| Reçete / Reçetelerim | ✅ Featured tile olarak burada (`/recipes`) |
| Hesaplama Makinesi (ayrı kart) | ❌ Yok — hesap yalnız Yeni Reçete sihirbazı içinde |
| Ürün ekleme / ürün listesi | ❌ Yok — `bakery_products` Supabase tablosu var ama UI yok (doğrulandı `lib/features/bakery_panel/` altında ekran yok) |

---

## 4. Bayi Paneli İçeriği

`/dealers` → `DealerListScreen` (liste). Detaya basınca `/dealers/:id` → `DealerDetailScreen`.

### DealerListScreen aksiyonları

| Aksiyon | Route/işlem | Çalışıyor mu? | Supabase? | Local-only? |
|---|---|---|---|---|
| Bayi listele | `dealersListProvider.list()` | ✅ | ✅ | — |
| Arama (isim/bölge/contactName) | client-side filter | ✅ | — | — |
| Filtre (Tümü/Aktif/Pasif) | client-side filter | ✅ | — | — |
| Bayi ekle | `/dealers/new` (AppBar icon) | ✅ | ✅ (`dealers` tablosu) | — |
| Detaya gir | `/dealers/:id` | ✅ | ✅ | — |

### DealerDetailScreen aksiyonları (`_ActionsRow` l.498-540)

| Aksiyon | Route | Çalışıyor mu? | Supabase? | Local-only? |
|---|---|---|---|---|
| Ürün Ver (delivery) | `/dealers/:id/delivery` | ✅ | ✅ | `dealer_deliveries`+items'a yazıyor |
| İade Al (return) | `/dealers/:id/return` | ✅ | ⚠ | **Local-only** — Supabase transaction tablosu yok |
| Ödeme Al (payment) | `/dealers/:id/payment` | ✅ | ⚠ | **Local-only** |
| Düzeltme (adjustment) | `/dealers/:id/adjustment` | ✅ | ⚠ | **Local-only** |
| Hesap Paylaş | `/dealers/:id/share` | ✅ | — (text/pdf builder) | — |
| Fiyat ekle (price sheet) | bottom sheet | ✅ | ⚠ | **Local-only** — `dealer_prices` tablosu yok (V1.1 önerisi) |

### Diğer detay bölümleri

| Alan | Durum | Kaynak |
|---|---|---|
| Bakiye hero (cari/borç/alacak/kapalı) | ✅ | `balanceSummaryProvider` (txs toplamından) |
| 3 metric (Teslim/İade/Ödeme) | ✅ | summary aggregate |
| Bu hafta / Bu ay / Son ödeme chip | ✅ | summary aggregate |
| Fiyat listesi | ⚠ local-only | `pricesByDealerProvider` |
| İşlem geçmişi (filtreli) | ⚠ kısmen Supabase (yalnız delivery) | `transactionsByDealerProvider` |
| Notlar (çoklu) | ⚠ local-only | `notesByDealerProvider` |
| contactName / workingType (Peşin/Vadeli/Karma) | UI'da var, Supabase'de sütun yok | `local_dealer_repository`'de tutuluyor |

**Doğrulanan kısıt** (`supabase_dealer_repository.dart` l.18-26):
> *"local-only kayıtlar app restart'ında kaybolur. Üretim öncesi V1.1 schema genişletmesi şart."*

---

## 5. Bireysel Panel

`/panel` bireysel kullanıcıya **5 kart** gösteriyor (`role_panel_cards.dart` l.73-105):

| # | Kart adı | Alt metin | Route | Çalışıyor mu? | Coming soon? | Tanım |
|---|---|---|---|---|---|---|
| 1 | İş İlanları | Sektörde yayında olanlar | `/jobs` | ⚠ (Jobs statik mock) | — | l.74-79 |
| 2 | **Reçetelerim** | Hamur hesabı, malzeme, yapılış | `/recipes` | ✅ | — | l.80-85 |
| 3 | İş Arıyorum İlanı Ver | Kendini sektöre tanıt | — | ❌ | ✅ | l.86-91 |
| 4 | Mesajlar | Sohbet & bildirimler | — | ❌ | ✅ | l.92-97 |
| 5 | Profilim | Bilgi, rozet, şehir | `/profile` | ✅ | — | l.98-103 |

**Doğrulamalar:**
- Reçetelerim ✅ — ticari ile aynı `/recipes` sistemi.
- Hesaplama Makinesi **ayrı kart olarak yok** (V1.1 mantığında reçete kayıtsız da Yeni Reçete üzerinden hesap yapılabiliyor).
- Feed/Grup/Market bağlantısı **panel kartlarında yok** — bottom nav üzerinden zaten herkese açık.
- İş İlanları kartı çalışıyor route bazında ama JobsScreen statik mock (madde 2'deki aynı uyarı).

---

## 6. Toptancı Panel

`/panel` toptancı kullanıcıya **4 kart** gösteriyor (`role_panel_cards.dart` l.106-133):

| # | Kart adı | Alt metin | Route | Çalışıyor mu? | Coming soon? | Tanım |
|---|---|---|---|---|---|---|
| 1 | Ürün/Hizmet İlanı Ver | Market'te yayına al | `/market` | ⚠ (Market statik mock) | — | l.107-113 |
| 2 | Gelen Mesajlar | Müşteri talepleri | — | ❌ | ✅ | l.114-119 |
| 3 | Firma Profilim | Kart, iletişim, bölge | `/profile` | ✅ (genel profil) | — | l.120-125 |
| 4 | Duyuru / Fiyat Listesi | Toptan fiyat bildir | — | ❌ | ✅ | l.126-131 |

**Doğrulamalar:**
- "Ürün/Hizmet İlanı Ver" kartı `/market` tabına atıyor ama `MarketplaceScreen` **statik in-file mock kartlar** (`_Product` const array). Yayına alma akışı **yok** — sadece mevcut mock listeyi gösteriyor. Yanıltıcı.
- "Firma Profilim" kartı genel `ProfileScreen`'e atıyor; toptancı için ayrı firma profili UI'sı yok (genel profil ekranı kullanılıyor).
- Reçete / hesaplama toptancıda **yok** — `RolePanelCards.forAccount(wholesaler)` listesinde "Reçetelerim" eklenmemiş.

---

## 7. Reçete ve Hesaplama Durumu

| Soru | Cevap |
|---|---|
| Reçetelerim hangi rollerde var? | **Ticari + Bireysel.** Toptancıda yok. |
| Hesaplama Makinesi ayrı modül? | ❌ **Yok.** V1.1 hotfix'inde standalone `RecipeCalculatorScreen` silindi (eski `/panel/recipe` route'una redirect bırakıldı). |
| Hesap yalnız Yeni Reçete içinde mi? | ✅ Evet — `RecipeEditorScreen` form içinde "Hesabı yenile" butonu + 6 stat kartı. |
| `/panel/recipe` neye gidiyor? | **Redirect** → `/recipes` (app_router l.166-169). Legacy alias. |
| `/recipes` | `RecipesListScreen` — owner'ın tüm reçeteleri (gizli + açık). |
| `/recipes/new` | `RecipeEditorScreen()` — yeni reçete sihirbazı (ürün seç + gerçek miktar + malzemeler + adımlar + görünürlük + kaydet). |
| `/recipes/:id` | `RecipeDetailScreen(recipeId)` — okuma + paylaş. |
| `/recipes/:id/edit` | `RecipeEditorScreen(recipeId)` — düzenleme. |
| Ticari vs bireysel erişim farkı? | ❌ **Yok** — tek `/recipes` sistemi. Ticari Fırın Paneli featured tile'dan da girer, bireysel panel kartından girer. Hesaplama mantığı bir. |

---

## 8. Çalışan / Yarım / Placeholder Listesi

### Gerçek çalışanlar (Supabase veya local persist)

| Modül | Durum |
|---|---|
| **Auth** (login/signup/signOut) | Supabase Auth + handle_new_user trigger |
| **Profil oluşturma + okuma** | `profiles` tablosu + auth trigger |
| **Fırın Paneli — Üretim Gir** | `production_entries` tablosu |
| **Fırın Paneli — Fire Gir** | `waste_entries` tablosu |
| **Fırın Paneli — Gün Sonu özet** | `dailySummary` aggregator |
| **Fırın Paneli — Rapor Al** | text builder + `share_plus` |
| **Bayi Yönetimi — Liste + Ekle** | `dealers` tablosu |
| **Bayi Detay — Ürün Ver (delivery)** | `dealer_deliveries`+items |
| **Bayi Detay — Bakiye hero + metrikler** | tx aggregator |
| **Bayi Detay — Hesap Paylaş (text + PDF)** | builder + share_plus + pdf paketi |
| **Reçete Kütüphanesi** | `recipe_calculations` + jsonb metadata + visibility (V1.1) |
| **Reçete Editör Hesap Önizleme** | `RecipeCalculator.calculateFromQuantities` |
| **Profil "Açık Reçeteler"** | `publicRecipesByOwnerProvider` (RLS public select) |
| **Feed (post + like + save + comment placeholder)** | LocalFeedRepository in-memory (V2 Supabase) |
| **Sosyal Gruplar (V1)** | LocalSocialGroupRepository in-memory |

### Yarım çalışanlar (UI tam ama persist yetersiz)

| Modül | Eksik kısım |
|---|---|
| **Bayi Detay — İade Al** | UI tam; **Supabase'de transaction tablosu yok**, LocalDealerRepository'e yazılıyor — uygulama yeniden başlayınca kaybolur |
| **Bayi Detay — Ödeme Al** | Aynı — local-only |
| **Bayi Detay — Düzeltme (adjustment)** | Aynı — local-only |
| **Bayi Detay — Fiyat ekle** | `dealer_prices` tablosu yok; local-only |
| **Bayi Detay — Notlar (multi-note)** | Supabase yalnız tek `dealers.note` text alanı tutuyor; multi-note local-only |
| **Dealer modeli — contactName / workingType / area** | Supabase'de sütun yok; `area` → `district` map ediliyor, contactName ve workingType **kaydedilmiyor** |
| **Feed** | Local mock seed; Supabase impl V2 olarak işaretli |
| **Sosyal Gruplar** | Local mock; Supabase impl yok |
| **Reçete paylaşımı — Grupta paylaş** | Bottom sheet'te "YAKINDA" rozeti + snackbar |
| **Reçete medya (foto/video)** | Placeholder kart — Supabase Storage entegrasyonu yok |

### Placeholder / yakında (comingSoon snackbar)

`RolePanelCards`'ta `comingSoon: true`:
- **Ticari:** Mesajlar
- **Bireysel:** İş Arıyorum İlanı Ver, Mesajlar
- **Toptancı:** Gelen Mesajlar, Duyuru / Fiyat Listesi

Statik/mock olarak doldurulmuş ama gerçek persist olmayan ekranlar:
- **Marketplace tab** (`/market`) — in-file `_Product` const array
- **Jobs tab** (`/jobs`) — in-file `_Job` const array (`_bakeriesHiring`, `_workersLooking`)
- **Topluluk ipuçları** Fırın Paneli sonunda — 3 sabit `_TipCard`

---

## 9. Panel Hiyerarşi Yorumu

> Sadece gözlem; **kod değişikliği önerisi değil.**

**Ticari panelde ana işler net mi?**
Genel olarak evet, ana 3 modül (Fırın Paneli, Bayi Paneli, Reçetelerim) ilk 3 sırada featured. Ama "İlanlarım" kartı yanıltıcı — açıldığında genel ilanlar tabına gidiyor, "ilanlarım" filtresi yok. Mesajlar comingSoon olarak 5. sırada yer kaplıyor.

**Fırın Paneli ve Bayi Paneli yeterince öne çıkıyor mu?**
Evet, ilk iki kart. Featured durumu yok (hepsi eşit görsel ağırlıkta `QuickActionTile` ile sunuluyor, ilk kart `featured: true` ile vurgulu — bu da Fırın Paneli'ne denk geliyor).

**Reçete / Hesaplama ana panelde anlaşılır mı?**
- Ticari için **iki giriş noktası var**: (1) `/panel`'deki "Reçetelerim" kartı (2) Fırın Paneli içindeki featured "Reçeteler" tile'ı. İkisi de `/recipes`'a gider — duplikasyon ama erişim kolaylaştırıyor.
- Standalone "Hesaplama Makinesi" yok. Sadece hesap istemek için kullanıcı "Yeni Reçete" sihirbazına girmek zorunda — kayıt yapmasa bile bir oturum açma deneyimi. Bu özellikle kullanıcının hızlı hesap yapmak istediği durumda uzun yol olabilir, **ama veri kaydı/listeleme/paylaşım fanteziyle birleştirildiği için product tercihi makul.**

**Bireysel panel boş/eksik mi?**
- 5 karttan 2'si `comingSoon`, 1'i (`İş İlanları` kartı) statik mock'a gidiyor, 1'i Reçetelerim (gerçek çalışıyor), 1'i Profil (gerçek çalışıyor).
- Sektör katılımcısı için bireysel rolde "ne işe yarar" sorusunun cevabı şu an dar: reçete + profil. İş ilanları geldiğinde tablo doldurur.

**Toptancı panel gerçek ürün mantığına hazır mı?**
- ❌ Değil. "Ürün/Hizmet İlanı Ver" kartı statik mock marketplace'e gidiyor — yayına alma akışı yok. Bayi mantığına benzer bir "toptan satıcı katalog" sistemi yok. Toptancı rolü şu an placeholder kabuk seviyesinde.

**İlk panel mantığına göre kaybolmuş veya yanlış yerde duran bir şey var mı?**

| Gözlem | Doğrulama |
|---|---|
| `/panel/dealer` route'u hâlâ tanımlı (`DealerDeliveryScreen`) ama hiçbir UI buna push etmiyor | `app_router.dart` l.62 + l.174-179; legacy V1 |
| Eski `/panel/recipe` route'u redirect olarak duruyor | app_router l.166-169 — derinlinkleri kıramamak için doğru karar |
| Topluluk ipuçları kartları Fırın Paneli'nin altında ama Feed kontekstinde olmalı | gözlem, statik mock |
| "İlanlarım" kartı `/jobs` tabına atıyor ama JobsScreen "tüm ilanlar" listesi | rol-tabanlı filtreleme JobsScreen'de yok |
| Toptancı paneli reçete yok ama Feed/Grup tab'larında reçete paylaşımı **görebilir** (paylaşılan reçeteler oraya akıyor) — bu tutarlı | gözlem |
| Profil ekranı sahibinin "Açık Reçeteler"ini gösteriyor ama başkasının profilini gezme akışı yok | RLS hazır, UI yok (V1.1 raporda not edildi) |

---

## Özet

### 1. Ticari panelde şu an görünenler
**Fırın Paneli, Bayi Paneli, Reçetelerim, İlanlarım, Mesajlar (yakında).**
3 ana modül + 1 yanıltıcı kısayol + 1 placeholder.

### 2. Bireysel panelde şu an görünenler
**İş İlanları, Reçetelerim, İş Arıyorum İlanı Ver (yakında), Mesajlar (yakında), Profilim.**
2 gerçek (Reçetelerim, Profilim) + 1 mock (İş İlanları) + 2 placeholder.

### 3. Toptancı panelde şu an görünenler
**Ürün/Hizmet İlanı Ver, Gelen Mesajlar (yakında), Firma Profilim, Duyuru/Fiyat Listesi (yakında).**
1 mock + 1 generic profil + 2 placeholder. Reçete yok.

### 4. Fırın Paneli içinde görünenler
- Bugünün özeti hero
- Featured **Reçeteler** → `/recipes`
- 4 mini: **Üretim Gir, Fire Gir, Gün Sonu, Rapor Al**
- Bayi Yönetimi özet kartı + CTA → `/dealers`
- Son hareketler liste
- Topluluk ipuçları (3 statik kart)

### 5. Bayi Paneli (Dealer) içinde görünenler
- Liste: arama + Tümü/Aktif/Pasif filtresi + Bayi Ekle (AppBar)
- Detay: bakiye hero, 5 aksiyon chip (**Ürün Ver, İade Al, Ödeme Al, Düzeltme, Hesap Paylaş**), fiyat listesi, işlem geçmişi (filtreli), notlar

### 6. Eksik olan kritik şeyler
- **Toptancı için gerçek ürün/ilan yayınlama akışı** (sadece statik mock market)
- **Marketplace + Jobs gerçek backend** (in-file const array)
- **Hesaplama Makinesi standalone modu** — hızlı hesap için ayrı kart yok (tercih meselesi; mevcut tasarım kayıtlı reçeteyi öne çıkarıyor)
- **Bireysel için reçete dışı içerikli iş** — şu an reçete + profil dışı bireysel'e değer yok
- **Bayi tarafında payment/return/adjustment/price/note için Supabase persist** — UI tam, ama veriler restart'ta kaybolur (kritik üretim öncesi engeli)
- **Reçete medya (foto/video)** — Supabase Storage entegrasyonu yok
- **Mesajlaşma altyapısı** — 3 rolde de comingSoon
- **Başkasının profilini görüntüleme** — RLS hazır ama route/UI yok

### 7. Sadece görünürlük/hiyerarşi problemi olanlar
- **"İlanlarım" kartı (Ticari):** route doğru (`/jobs`) ama JobsScreen rol bazlı filtre uygulamıyor; ad yanıltıcı.
- **Ticari panelinde Reçete için iki giriş noktası** (`/panel` kartı + Fırın Paneli featured tile) — duplikasyon; product tercihi.
- **Mesajlar (3 rol)** kart yer kaplıyor ama backend yok — kart hâlâ yer kaplıyor (kart sayısı dengelemek için kullanılmış izlenimi).
- **"Firma Profilim" toptancı için ayrı UI yok** — generic ProfileScreen'e gidiyor.
- **Fırın Paneli'ndeki topluluk ipuçları** Fırın Paneli'ne özgü değil; Feed bağlamına daha uygun.

### 8. Kod değiştirmeden sonraki önerilen düzeltme sırası

> Yine sadece öneri sırası; bu raporda kod değişmedi.

1. **Bayi V1.1 schema genişletme** (en kritik blocker): `dealer_transactions` (payment/return/adjustment), `dealer_prices`, `dealer_notes` çoklu, `dealers.contact_name + working_type` sütunları. Mevcut local hibrit veri kaybediyor.
2. **JobsScreen + MarketplaceScreen gerçek backend** (Supabase tabloları + repository/provider). Bunlardan en az `jobs` tablosu ticari ve bireysel için kritik.
3. **Toptancı "Ürün/Hizmet İlanı Ver" akışı** — wholesaler için ilan yayınlayıp marketplace'te gözüken gerçek bir akış. Toptancı rolünün varlık nedeni bu.
4. **"İlanlarım" kartını ya filtreli `/jobs?owner=me` haline getir ya da kaldır.** Ad yanıltıcı.
5. **Hesaplama Makinesi shortcut** — Fırın Paneli'ne 5. mini kart "Hesap" → `RecipeEditorScreen(quickMode: true)` (kaydetmeden kapatılabilir).
6. **Mesajlaşma altyapısı** (3 rolde de comingSoon). Real-time messaging — V2 scope.
7. **Reçete medya** — Supabase Storage `recipe-media` bucket + image_picker.
8. **Başkasının profilini görüntüleme** route'u + UI (RLS zaten hazır).
9. **Topluluk ipuçları kartlarının yeri** — Feed'de "Sektör Pulse" bölümüne taşıma değerlendirilebilir.

---

**Not:** Bu rapor yalnız doğrulanan satır/dosya/route'ları içerir. Tüm tablolardaki "doğrulandı" işaretleri görülen koda dayalı; emin olamadığım yer kalmadı. Eğer kalan bir kör nokta görürsen söyle, ek tarama yaparım.
