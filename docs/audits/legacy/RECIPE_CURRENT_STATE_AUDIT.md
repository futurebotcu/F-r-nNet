# RECIPE_CURRENT_STATE_AUDIT

**Tarih:** 2026-05-13
**Kapsam:** FırınNet Reçete modülü — mevcut durum, eksikler, yeniden kullanılabilirlik
**Hedef:** Yeni "Reçete Kütüphanesi" hedefine geçmeden önce zemini netleştirmek

> Bu rapor **sadece audit**'tir. Henüz kod değişikliği yapılmadı.

---

## 1. Mevcut reçete ekranları

| # | Ekran | Dosya | Route | İşlev |
|---|---|---|---|---|
| 1 | `RecipeCalculatorScreen` | `lib/features/bakery_panel/screens/recipe_calculator_screen.dart` | `/panel/recipe` | Tek ekran reçete hesaplayıcı. 6 input → 6 sonuç kartı. State `_result` ile sadece o oturumda tutulur. |
| 2 | `BakeryPanelScreen` (host) | `lib/features/bakery_panel/screens/bakery_panel_screen.dart` | `/panel/bakery` | "Reçete Hesapla" butonunun barındığı ticari panel ana ekranı. `_ProductionActions` (l.255-323) featured tile. |

Başka reçete ekranı **yok**. Liste/detay/oluşturma akışı **yok**.

---

## 2. RecipeCalculator (hesap motoru)

**Dosya:** `lib/features/bakery_panel/services/recipe_calculator.dart` (37 satır)

**Sınıf:** `RecipeCalculator` (const, bağımlılıksız)

**İmza:** `RecipeResult calculate(RecipeInput input)`

**Formüller (l.18-26)** — brief'le birebir eşleşiyor:

```
water_kg        = flour_kg * water_pct / 100
yeast_kg        = flour_kg * yeast_pct / 100
salt_kg         = flour_kg * salt_pct  / 100
total_dough_kg  = flour_kg + water_kg + yeast_kg + salt_kg
net_dough_kg    = total_dough_kg * (1 - waste_pct / 100)
estimated_count = floor(net_dough_kg * 1000 / unit_weight_gr)
```

**Clamping (güvenli aralıklar, l.9-15):**
- `flour_kg`: [0, ∞)
- `water_pct`: [0, 200]
- `yeast_pct`, `salt_pct`, `waste_pct`: [0, 100]
- `piece_weight_g`: [1, ∞)
- `estimated_pieces < 0 → 0`

**Brief'teki referans test (50/60/1/2/250/3) → 316 adet** — formül doğrular.

> Supabase trigger `calculate_recipe_calculation()` (migration l.162-181) **aynı formülü** uyguluyor. Local vs. server hesap sonuçları birebir eşleşiyor.

---

## 3. "Reçete Hesapla" butonu — açılış akışı

**Route:** `AppRoutes.recipe = '/panel/recipe'` (`app_router.dart` l.54)
**Builder:** `RecipeCalculatorScreen()` (`app_router.dart` l.141-143)

**Çağıran tek nokta:** `BakeryPanelScreen._ProductionActions` featured tile → `context.push('/panel/recipe')` (l.301)

**Erişim zinciri:**

```
RoleDashboardScreen   (rol = commercial)
       └── "Fırın Paneli" kartı (role_panel_cards.dart l.42-47)
              └── /panel/bakery   →  BakeryPanelScreen
                       └── featured "Reçete Hesapla" tile
                              └── /panel/recipe  →  RecipeCalculatorScreen
```

Bireysel kullanıcı role dashboard'ında reçeteye giden bir kart **yok**.

---

## 4. Supabase `recipe_calculations` INSERT durumu

**Şu an INSERT yapılmıyor.** Schema mevcut ama UI sonucu yalnızca local state'te kalıyor.

- `SupabaseBakeryRepository` → `production_entries`, `waste_entries`, `dealer_deliveries`'e yazıyor; `recipe_calculations` **yok**.
- `LocalBakeryRepository` → in-memory; recipe alanı **yok**.
- `bakery_providers.dart`'taki `recipeCalculatorProvider` sadece `const RecipeCalculator()` dönüyor (l.23-25), persistence yok.

**Supabase tablosu (migration `20260512075056_firinnet_v1_core_schema.sql` l.140-198):**

| Sütun | Tip | Not |
|---|---|---|
| `id` | uuid PK | — |
| `owner_id` | uuid FK profiles | RLS anahtarı |
| `product_name` | text | nullable |
| `flour_kg` | numeric(12,3) | > 0 |
| `water_percent` | numeric(8,3) | >= 0 |
| `yeast_percent` | numeric(8,3) | >= 0 |
| `salt_percent` | numeric(8,3) | >= 0 |
| `unit_weight_gr` | numeric(12,2) | > 0 |
| `waste_percent` | numeric(8,3) | [0,100], default 0 |
| `water_kg`, `yeast_kg`, `salt_kg`, `total_dough_kg`, `net_dough_kg`, `estimated_count` | numeric/integer | **trigger doldurur** (l.169-178) |
| `created_at` | timestamptz | default now() |

**RLS:** Owner-only (select/insert/update/delete `owner_id = auth.uid()`). Anonim erişim yok.
**Trigger:** `trg_recipe_calculations_calculate` BEFORE INSERT/UPDATE — Flutter formülüyle birebir.

**Tabloda OLMAYAN alanlar (yeni hedef için kritik):**
- başlık / reçete adı (sadece `product_name` var, "Trabzon Ekmeği" gibi free-text için kullanılabilir)
- açıklama / notlar
- pişirme süresi / pişirme derecesi / mayalanma süresi
- malzemeler listesi (un dışında un+su+maya+tuz+susam+yağ vb. dinamik)
- yapılış adımları
- fotoğraf/video
- `updated_at`
- `is_private` / visibility (zaten RLS owner-only — gizlilik bayrağına gerek yok)

---

## 5. Reçete geçmişi UI

**Yok.** Listeleme, detay, kart UI hiçbiri yazılmamış. `RecipeListScreen`, `RecipeDetailScreen` adı altında bir dosya bulunmuyor.

---

## 6. Ürün listesi / ürün seçimi

**Yok.** RecipeCalculatorScreen'de ürün adı alanı **bile yok**. Brief'in talep ettiği önset (Ekmek/Simit/Poğaça/Açma/Pide/Lavaş/Börek/Kurabiye) ekran üzerinde sunulmuyor; sadece sayısal 6 alan var.

Not: `bakery_products` tablosu Supabase'de mevcut (kullanıcının kendi ürün katalogu). Üretim ekranlarında ürün adı `production_entries.product_name` ile tutuluyor ama reçete tarafıyla bağlı değil.

---

## 7. Malzeme listesi UI/model

**Yok.** `RecipeInput` 6 sabit alandan ibaret (un+su%+maya%+tuz%+gramaj+fire). Dinamik "malzeme adı + miktar + birim" listesi modeli yok, UI yok, repository yok.

---

## 8. Yapılış adımları

**Yok.** Adım listesi modeli, UI, tablosu yok.

---

## 9. Fotoğraf / video alanı

**Yok.**
- `pubspec.yaml`'da `image_picker`, `file_picker`, `video_player` **yok**
- Supabase Storage entegrasyonu **yok**
- FeedPost/GroupMessage modellerinde dahi medya alanı yok (mevcut sosyal akış sadece metin)
- Sadece `pdf: ^3.11.1` var (bayi PDF üretimi için)

---

## 10. Reçete paylaşımı

**Reçete için yok**, ama altyapı kısmen mevcut.

`share_plus: ^10.1.2` paketi `pubspec.yaml`'da. Kullanımı:
- `ReportScreen` (l.83-86): "Raporunu Paylaş" — `Share.share(text)`
- `DealerShareScreen` (l.121-130): bayi özeti metin paylaşımı

Reçete ekranında "Paylaş" butonu yok.

---

## 11. Feed / grup / WhatsApp paylaşım altyapısı

**Var ama metin-bazlı (medya yok).**

| Modül | Repository | Local mock | Supabase impl |
|---|---|---|---|
| Feed | `FeedRepository` (`addPost`, `toggleLike`, `toggleSave`, `listInsights`) | `LocalFeedRepository` (in-memory) | **yok** (V2 olarak işaretli) |
| Grup | `SocialGroupRepository` (`postMessage`, `listMessages`, join/leave) | `LocalSocialGroupRepository` (in-memory) | **yok** |
| WhatsApp / dış | `share_plus` (`Share.share(text)`) | uyarlanabilir | — |

`FeedPost` ve `GroupMessage` modellerinde **medya alanı yok** — sadece `text`, `tags`, `gradient`, `like/comment/save` sayaçları.

Yani reçete paylaşımı için:
- WhatsApp/dış → `share_plus` ile **doğrudan kullanılabilir** (metin builder yazmamız yeterli)
- Feed/grup → mevcut `addPost` / `postMessage` metin alanına çok satırlı reçete metni gönderilebilir, ama production-hazır Supabase backend yok (in-memory mock)

---

## 12. Local / mock fallback

**Pattern:** `AppConfig.supabaseEnabled` getter (`app_config.dart` l.15-16) dart-define ile gelen URL+key boş değilse `true`. Tüm provider'lar bu pattern üzerinden ayrılıyor:

```dart
if (AppConfig.supabaseEnabled && user != null) return SupabaseXRepository(...);
return LocalXRepository();
```

Örnekler: `bakeryRepositoryProvider`, `dealerRepositoryProvider`, `profileRepositoryProvider`, `authRepositoryProvider`.

**Persistent local storage yok.** Tüm "Local" repolar in-memory (Hive/sqflite/sharedprefs hiçbiri pubspec'te yok). Uygulama yeniden başlayınca local veri kaybolur — bu mevcut tasarım kararı.

Reçete tarafı için şu an local fallback **hiç yok** — çünkü Supabase tarafında da kayıt yok; sadece anlık hesap var.

---

## 13. Ticari vs bireysel erişim

| Rol | Reçeteye giriş |
|---|---|
| `commercial` (ticari) | RoleDashboard → "Fırın Paneli" → BakeryPanelScreen → "Reçete Hesapla" → `/panel/recipe` |
| `individual` (bireysel) | **Erişim yok.** RolePanelCards bireysel için: İlanlar, İş İlanı Yayınla, Mesajlar, Profilim |
| `wholesaler` (toptancı) | **Erişim yok.** Ürün Yayınla, Mesajlar, Şirket Profili, Fiyat Duyuruları |

Brief: "Ticari ve bireysel için ayrı reçete mantığı kurma. Tek reçete sistemi olacak." → Yeni hedefte **bireysel rolüne de** reçete giriş kartı eklemek gerekecek.

---

## EK 1 — `RecipeInput` ve `RecipeResult` modeli alanları

**`RecipeInput` (`recipe.dart` l.2-46):**
- `flourKg` (double), `waterPct`, `yeastPct`, `saltPct`, `pieceWeightG`, `wastePct` (hepsi double)
- `RecipeInput.defaults` = 50/60/1/2/250/3
- `copyWith(...)`

**`RecipeResult` (`recipe.dart` l.49-65):**
- `waterLiters`, `yeastKg`, `saltKg`, `totalDoughKg`, `doughAfterWasteKg` (double)
- `estimatedPieces` (int)

> Bu modelde yeni hedef için eksik olan her şey EK 2'deki schema eksik listesiyle birebir örtüşüyor.

---

## EK 2 — pubspec medya/paylaşım durumu

| Paket | Var/Yok | Not |
|---|---|---|
| `share_plus: ^10.1.2` | ✅ | WhatsApp/sistem paylaşımı için hazır |
| `pdf: ^3.11.1` | ✅ | Bayi PDF — reçete için gerekli değil |
| `image_picker` | ❌ | Foto seçimi için eklenmeli (V2'ye bırakılabilir) |
| `file_picker` | ❌ | — |
| `video_player` | ❌ | — |
| `url_launcher` | ❌ | WhatsApp deep-link için isteğe bağlı (`share_plus` zaten yeterli) |
| Supabase Storage | ❌ | Şu an hiçbir bucket konfigürasyonu yok |

---

## EK 3 — Mevcut testler

`test/` altında **9 dosya, toplam 44 `test(...)` çağrısı**:

| Dosya | Test sayısı |
|---|---|
| `recipe_calculator_test.dart` | 4 |
| `feed_repository_test.dart` | 11 |
| `social_group_repository_test.dart` | 11 |
| `dealer_balance_test.dart` | 7 |
| `dealer_repository_test.dart` | 4 |
| `dealer_share_builder_test.dart` | 2 |
| `dealer_pdf_builder_test.dart` | 2 |
| `repository_provider_selection_test.dart` | 2 |
| `widget_test.dart` | 1 |

> **NOT:** Brief'te "mevcut 46 test bozulmasın" denildi. Gerçek sayı 44. Sayı muhtemelen son raporlardan birinde yaklaşık alınmış. Hedef: **44 mevcut test yeşil kalsın**, üzerine reçete kayıt/builder testleri eklenecek.

---

## EK 4 — Yeni hedefte yeniden kullanılabilir yapılar

| Mevcut yapı | Yeni hedefte kullanım |
|---|---|
| `RecipeCalculator` service | ✅ Aynen kalır — hesap motoru tek formül, brief ile birebir |
| `RecipeInput` / `RecipeResult` | ✅ Korunur — `RecipeDraft` gibi bir üst kapsayıcıya alan olarak girer |
| `RecipeCalculatorScreen` | ⚠ "Yeni Reçete" form sihirbazına dönüşür (hesap kısmı sub-section) |
| Supabase `recipe_calculations` tablosu + trigger | ✅ Aynen kullanılır — yeni alan eklenecekse migration konuşulacak (aşağı) |
| `AppConfig.supabaseEnabled` pattern | ✅ Aynı pattern recipe repository'ye uygulanır |
| `share_plus` | ✅ Reçete WhatsApp/sistem paylaşımı |
| `FeedRepository.addPost` / `SocialGroupRepository.postMessage` (local mock) | ⚠ Sadece metin paylaşımı yapılabilir; foto/medya eklenirse mock yeterli olmaz |
| `bakery_products` (Supabase) | ⚠ Standart ürün önsetleri için referans, ama brief'te ürün önset listesi sabit string verilmiş — basit `const` enum/listesi yeterli |

---

## EK 5 — Yeni hedef için eksik olan parçalar

### Mutlaka eklenecek
- **Reçete listesi ekranı** (`RecipesScreen` / `MyRecipesScreen`) — owner_id filtresiyle Supabase'den oku, local fallback ile in-memory
- **Reçete oluşturma sihirbazı** (mevcut hesaplayıcının üst kapsayıcısı) — ürün seçimi → temel bilgiler + hesap → malzemeler → adımlar → notlar → kaydet
- **Reçete detay ekranı** — okuma + "Paylaş" butonu
- **Repository:** `RecipeRepository` abstract + `SupabaseRecipeRepository` + `LocalRecipeRepository`
- **Standart ürün listesi:** brief'teki 8 ürün için const liste + "Yeni ürün adı yaz" alanı
- **Paylaşım metin builder:** brief'teki WhatsApp formatına uygun multi-line string üreten saf fonksiyon
- **Bireysel role dashboard erişimi:** "Reçeteler" kartı eklemek

### Şarta bağlı / kararlaştırılacak (aşağıya bak)
- **Malzeme listesi**, **yapılış adımları**, **pişirme süresi/derecesi**, **mayalanma süresi**, **kısa açıklama**, **notlar**, **fotoğraf/video** — schema'da alan yok

---

## EK 6 — Schema kararı (KULLANICI ONAYI BEKLENİYOR)

Brief diyor ki:
> *"Backend schema/RLS değiştirme gerekiyorsa önce raporla; mümkünse mevcut schema ile ilerle. Büyük migration gerekiyorsa hemen yapma; önce öner."*

Mevcut `recipe_calculations` **sadece** un/su%/maya%/tuz%/gramaj/fire% + hesap çıktıları + product_name'i tutuyor. Brief'in istediği zengin alanları (malzemeler, adımlar, notlar, pişirme süresi, açıklama, foto) tutmuyor.

### Seçenek A — Mevcut schema ile ilerle (sıfır migration)
- Reçete kaydı yalnızca DB'de hesap özeti olarak tutulur.
- Malzemeler/adımlar/notlar/pişirme süresi **sadece UI state'te** kalır; persist edilmez.
- Detay ekranını yeniden açtığında bu alanlar boş döner.
- Kayıttan SONRA tekrar düzenlemek için DB'ye gitmek yetmez.
- **Sonuç:** Kaydet/listele çalışır ama "reçete kütüphanesi" hissi vermez. WhatsApp paylaşımı için tek oturumda yine çalışır.

### Seçenek B — Tek `metadata jsonb` sütunu (minimal migration) ✅ ÖNERİLEN
- `recipe_calculations` tablosuna **tek yeni sütun** ekle: `metadata jsonb not null default '{}'::jsonb`
- Malzemeler `metadata.ingredients[]`, adımlar `metadata.steps[]`, notlar `metadata.notes`, pişirme bilgileri `metadata.bake.*` olarak JSON içinde tutulur
- RLS değişmez (zaten owner-only). Trigger değişmez. Mevcut sütunlar bozulmaz.
- Foto/video URL'leri ileride `metadata.media[]` olarak eklenebilir (gerçek storage ayrı faz).
- Migration: tek `alter table ... add column metadata jsonb not null default '{}'::jsonb;` — çok düşük risk.

### Seçenek C — Ayrı zengin `recipes` tablosu + alt tablolar (büyük migration)
- Yeni `recipes`, `recipe_ingredients`, `recipe_steps` tabloları + RLS + foreign key zinciri
- `recipe_calculations` salt-hesap olarak kalır (legacy uyum)
- Yüksek karmaşıklık, ileride storage/medya tablosu eklenince temizdir
- **Brief "büyük migration gerekiyorsa hemen yapma" diyor — bu yola girilirse onay şart.**

### Seçenek D — Hibrit: Şu an A, sonraki fazda B veya C
- V1 bu fazda: kaydet hesap özeti + listele + WhatsApp paylaşımı çalışır
- V1.1 fazında schema kararı verilir
- Avantaj: Hızlı, sıfır migration; dezavantaj: detay ekranında malzemeler/adımlar persist olmaz

> **Tavsiye edilen: Seçenek B (metadata jsonb).** Tek sütun, geri dönüşü kolay, brief'in istediği tüm alanları kapsar.

---

## EK 7 — Akış planı (kullanıcı onayından sonra)

Schema kararı netleşince izlenecek sıra (önerilen B varsayımıyla):

1. Migration: `metadata jsonb` sütunu ekle (`alter table public.recipe_calculations add column metadata jsonb not null default '{}'::jsonb`)
2. `Recipe` ve `RecipeIngredient` / `RecipeStep` modelleri (`lib/features/bakery_panel/models/`)
3. `RecipeRepository` abstract + `SupabaseRecipeRepository` + `LocalRecipeRepository`
4. `recipeRepositoryProvider` (AppConfig.supabaseEnabled pattern)
5. UI:
   - `RecipesListScreen` (Reçetelerim)
   - `RecipeEditorScreen` (yeni/düzenleme — mevcut RecipeCalculatorScreen'in evrimi)
   - `RecipeDetailScreen`
6. `RecipeShareTextBuilder` (saf fonksiyon, test edilebilir)
7. Router: `/recipes`, `/recipes/new`, `/recipes/:id`
8. Bireysel role dashboard'una "Reçeteler" kartı
9. BakeryPanelScreen featured tile'ı `/recipes` veya `/recipes/new`'ye yönlendir
10. Testler:
    - Mevcut 44 testin tamamı geçmeye devam
    - `RecipeCalculator` 316 testi (zaten var, beklenen değerleri brief ile birebir kontrol)
    - `RecipeShareTextBuilder` testi (WhatsApp metin formatı)
    - `RecipeRepository` mapping testi (local + Supabase JSON round-trip)
11. `flutter analyze` + `flutter test` yeşil
12. `RECIPE_FEATURE_LIBRARY_REPORT.md`

---

## Kırmızı çizgiler (brief'ten)

- ❌ RLS gevşetme yok — owner-only kalacak
- ❌ service_role / PAT / DB password Flutter'a girmez
- ❌ Tasarım renklerine dokunma
- ❌ Profil ekranına dokunma
- ❌ Sosyal akışın ana mimarisini bozma
- ❌ Mevcut 44 test bozulmayacak
- ✅ Reçete varsayılan **private** (RLS owner-only zaten bunu sağlar — ek `is_private` bayrağına gerek yok)
- ✅ Paylaşım reçeteyi public yapmaz, sadece içerik üretir (feed/grup metin paylaşımı veya `share_plus`)

---

## Karar bekleyen tek soru

**Schema seçeneği A / B / C / D'den hangisi?** (EK 6)

Bu seçim netleşmeden uygulamaya başlamayacağım.
