# RECIPE_FEATURE_LIBRARY_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.1 — Reçete sadece hesap makinesi değil, **reçete kütüphanesi**
**Schema seçimi:** Onaylanan **B — tek `metadata jsonb` sütunu** (minimum migration)
**Test:** `flutter analyze` temiz, `flutter test` 63/63 yeşil (46 mevcut + 17 yeni)

---

## 1. Mevcut durum audit özeti

(Tam detay: [RECIPE_CURRENT_STATE_AUDIT.md](RECIPE_CURRENT_STATE_AUDIT.md))

- Tek ekran `RecipeCalculatorScreen` (`/panel/recipe`) ticari panelden push.
- `RecipeCalculator` formülü brief'le birebir (su/maya/tuz/toplam/net/adet).
- Supabase `recipe_calculations` tablosu mevcut + trigger + owner-only RLS, **ama Flutter tarafında INSERT yapan kod yok.**
- Reçete geçmişi UI, ürün seçimi, malzeme listesi, yapılış adımları, foto/video, paylaş butonu yok.
- `share_plus ^10.1.2` mevcut. `image_picker`/`file_picker`/Storage yok.
- Mevcut test sayısı: **46** (`flutter test` çıktısı; `test()` + `testWidgets()` toplamı).
- Sektörde tek erişim noktası: **ticari** rol.

---

## 2. Yeni reçete sistemi — özet

`recipe_calculations` tablosu V1'den korundu, üzerine **tek bir `metadata jsonb` sütunu** eklendi. Sütun jsonb içinde şu alanları tutuyor:

```json
{
  "title": "Trabzon Ekmeği",
  "description": "Çıtır kabuklu, içi yumuşak",
  "ingredients": [
    { "name": "Un",   "amount": 50,  "unit": "kg" },
    { "name": "Susam","amount": 1,   "unit": "kg", "note": "üzerine" }
  ],
  "steps": [
    { "order": 1, "text": "Hamuru yoğur" },
    { "order": 2, "text": "Dinlendir", "durationMin": 45 }
  ],
  "bake": { "tempC": 220, "durationMin": 18, "proofMin": 45 },
  "notes": "Soğuk fermantasyon önerilir",
  "mediaHints": [],
  "updatedAt": "2026-05-13T12:00:00.000Z"
}
```

**Gizlilik:**
- Reçete varsayılan **private**. `recipe_calculations` tablosundaki RLS owner-only — kullanıcı paylaşana kadar başka kimse okuyamaz.
- "Paylaş" butonu reçetenin DB durumunu değiştirmez; sadece paylaşılabilir içerik üretir (Feed'e post, sistem paylaşımı, vb.).

**Erişim:**
- **Ticari:** Role dashboard → "Reçetelerim" kartı (yeni) + Fırın Paneli featured tile ("Reçeteler", `/recipes`).
- **Bireysel:** Role dashboard → "Reçetelerim" kartı (yeni). Eskiden erişim yoktu.
- **Toptancı:** Şu an erişim eklenmedi (V1 zorunlu kapsam dışında).

---

## 3. Ürün listesi ve yeni ürün mantığı

`lib/features/bakery_panel/data/recipe_products.dart`:

```dart
const List<String> standardRecipeProducts = <String>[
  'Ekmek', 'Simit', 'Poğaça', 'Açma',
  'Pide', 'Lavaş', 'Börek', 'Kurabiye',
];
```

Editor'da `ChoiceChip` ızgarası standart ürünleri sunar. Hemen altında "Veya yeni ürün adı yaz" alanı serbest text giriş — kullanıcı "Trabzon Ekmeği", "Ramazan Pidesi" gibi özel ad da girebilir. İkisinden hangisi doluysa o kaydedilir; ikisi de boşsa "Genel reçete" düşer.

---

## 4. Malzeme & adım yapısı

### Malzeme
Editor'da "+ Malzeme ekle" butonu dinamik liste oluşturur.

Her satır: `name`, `amount`, `unit`, `note` (opsiyonel).

Kaydedilirken boş `name`'li satırlar **filtrelenir**. Birim boşsa default "kg" düşer.

Detay ekranında ayrılmış kart ile sıralı listede gösterilir.

### Yapılış adımları
"+ Adım ekle" butonu dinamik liste. Her satır: `text`, `duration` (dakika, opsiyonel).

Boş `text`'li satırlar atılır. `order` kaydet anında 1'den başlayarak otomatik atanır — kullanıcının taşıma karmaşası yok.

WhatsApp metninde de `order` sırasına göre yazılır.

---

## 5. Supabase `recipe_calculations` kayıt akışı

### Migration
**Dosya:** `supabase/migrations/20260513090000_firinnet_recipe_metadata_jsonb.sql`
**Uygulandı:** `mcp__supabase__apply_migration` üzerinden remote'a uygulandı.

```sql
alter table public.recipe_calculations
  add column if not exists metadata jsonb not null default '{}'::jsonb;
```

**RLS değişmedi**, **trigger değişmedi**, mevcut sütunlar bozulmadı. Geri dönüş: `alter table ... drop column metadata;`

### INSERT akışı (`SupabaseRecipeRepository`)
1. `_requireUserId()` → `auth.uid()` zorunlu (RLS koşulu).
2. INSERT payload:
   - `owner_id`, `product_name`
   - `flour_kg`, `water_percent`, `yeast_percent`, `salt_percent`, `unit_weight_gr`, `waste_percent`
   - `metadata` (jsonb, `RecipeMetadata.toJson()` çıktısı)
3. Hesaplanan sütunlar (`water_kg`, `yeast_kg`, `salt_kg`, `total_dough_kg`, `net_dough_kg`, `estimated_count`) **gönderilmez**; mevcut BEFORE trigger doldurur.
4. `.select(...).single()` ile dolu satır geri çekilir, UI sonucu trigger çıktısını gösterir.

### Listeleme & detay
- `list()` → `select(_columns).eq(owner_id).order(created_at desc)`. RLS owner-only.
- `getById(id)` → owner_id + id koşullarıyla `maybeSingle()`.
- `delete(id)` → owner_id + id ile.

### Local fallback (`LocalRecipeRepository`)
- `AppConfig.supabaseEnabled == false` veya kullanıcı oturumsuzken `recipeRepositoryProvider` bunu döner.
- In-memory liste. Hesap çıktısını client-side `RecipeCalculator` ile üretir → Supabase trigger ile **birebir aynı** sonuç (formül paritesi audit ile doğrulandı, brief 316 testi yeşil).
- `r_<timestamp>` formatlı geçici id; save'de Supabase'e geçiş yapılırsa `INSERT` path'i bu prefix'i de "yeni satır" sayar.

---

## 6. Paylaşım mantığı

`lib/features/bakery_panel/services/recipe_share_text_builder.dart` — saf fonksiyon, `share_plus`'tan ve UI'dan bağımsız, test edilebilir.

### Çıktı şablonu (briefle uyumlu)
```
Trabzon Ekmeği Reçetesi
Un: 50 kg
Su: 30 kg
Maya: 0.5 kg
Tuz: 1 kg
Gramaj: 250 gr
Tahmini: 316 adet

Malzemeler:
- Un: 50 kg
- Susam: 1 kg (üzerine)

Yapılışı:
1. Hamuru yoğur
2. Dinlendir (45 dk)

Pişirme: 220°C • 18 dk pişirme • 45 dk mayalanma

Not: Soğuk fermantasyon önerilir

FırınNet
```

### Paylaş bottom sheet (`RecipeDetailScreen`)
- **Feed'de paylaş** → `FeedRepository.addPost(type: production, text: shareText, tags: [reçete])`. Mevcut local feed mock'una yazar; backend hazırlandığında otomatik geçecek.
- **Grupta paylaş** → "YAKINDA" rozetiyle disable değil, basıldığında snackbar "Grupta paylaşım sonraki fazda aktif olacak." Grup seçimi ekstra UI gerektirir.
- **WhatsApp / Sistem paylaşımı** → `Share.share(text, subject: 'FırınNet — Reçete')`. Android sistem chooser'ı açar.
- Liste kartında doğrudan "Paylaş" butonu da sistem chooser'a kısa yol verir (en sık aksiyon).

---

## 7. Gizlilik düzeltmesi — reçete private default, paylaşım sadece aksiyon

Brief önemli bir noktayı vurguladı:
> *"Reçeteler varsayılan olarak sadece kullanıcıya özel olacak. Reçete herkese açık olmayacak. Kullanıcı sadece Paylaş butonuna basarsa reçete feed/grup/WhatsApp gibi yerlere paylaşılacak. Paylaşmak reçetenin kendi kaydını public yapmaz; sadece paylaşım içeriği oluşturur."*

Bu mantık şöyle uygulandı:
- `recipe_calculations` üzerindeki RLS policy'leri V1'den beri **owner-only**. Yeni `metadata` sütunu da bu policy'lerin altında. Başka bir kullanıcı bu satırı `select` edemez.
- Paylaş butonu **DB'ye dokunmaz**; sadece `RecipeShareTextBuilder` ile metin üretir + bunu Feed'in `addPost` çağrısına veya `share_plus`'a yollar.
- Feed'e atılan kopya bağımsız bir `FeedPost`'tur; orijinal reçete kaydı private kalır.
- Schema'ya `is_private` bayrağı **eklenmedi** — gereksiz çünkü RLS zaten kapsıyor.
- Detay ekranında bottom sheet açılışında küçük açıklama: *"Reçete sadece sende kayıtlı. Paylaşmak gizliliğini değiştirmez; sadece bu içeriği oluşturur."*

---

## 8. Değişen dosyalar

### Yeni eklenenler
- `supabase/migrations/20260513090000_firinnet_recipe_metadata_jsonb.sql` — metadata jsonb migration
- `lib/features/bakery_panel/data/recipe_products.dart` — standart ürün listesi
- `lib/features/bakery_panel/models/recipe_metadata.dart` — RecipeIngredient/RecipeStep/RecipeBakeInfo/RecipeMetadata
- `lib/features/bakery_panel/models/recipe_record.dart` — Recipe domain modeli
- `lib/features/bakery_panel/repositories/recipe_repository.dart` — abstract
- `lib/features/bakery_panel/repositories/local_recipe_repository.dart` — in-memory
- `lib/features/bakery_panel/repositories/supabase_recipe_repository.dart` — RLS owner-only INSERT/UPDATE/DELETE/SELECT
- `lib/features/bakery_panel/services/recipe_share_text_builder.dart` — WhatsApp/sistem paylaşım metin builder
- `lib/features/bakery_panel/screens/recipes_list_screen.dart` — Reçetelerim
- `lib/features/bakery_panel/screens/recipe_editor_screen.dart` — yeni/düzenleme sihirbazı
- `lib/features/bakery_panel/screens/recipe_detail_screen.dart` — detay + paylaş bottom sheet
- `test/recipe_share_text_builder_test.dart` — 6 test
- `test/local_recipe_repository_test.dart` — 11 test (repo + JSON round-trip)

### Düzenlenenler
- `lib/app/router/app_router.dart` — `/recipes`, `/recipes/new`, `/recipes/:id`, `/recipes/:id/edit` route'ları; `/panel/recipe` redirect alias
- `lib/features/bakery_panel/providers/bakery_providers.dart` — `recipeRepositoryProvider`, `recipeChangesProvider`, `recipesListProvider`, `recipeShareTextBuilderProvider`
- `lib/features/bakery_panel/screens/bakery_panel_screen.dart` — featured tile "Reçete Hesapla" → "Reçeteler" ve route `/recipes`
- `lib/features/dashboard/services/role_panel_cards.dart` — ticari + bireysel role'lerine "Reçetelerim" kartı
- `lib/core/constants/app_strings.dart` — `cardMyRecipes`, `cardMyRecipesSub`

### Silinenler
- `lib/features/bakery_panel/screens/recipe_calculator_screen.dart` — ölü kod (mantığı editor'a evrildi, route alias artık /recipes'a yönlendiriyor)

---

## 9. `flutter analyze` sonucu

```
Analyzing firinnet...
No issues found! (ran in 0.6s)
```

---

## 10. `flutter test` sonucu

```
00:03 +63: All tests passed!
```

**Detay (63 test, 12 dosya):**

| Dosya | Test sayısı | Durum |
|---|---|---|
| `recipe_calculator_test.dart` | 4 | ✅ (V1) |
| `recipe_share_text_builder_test.dart` | 6 | ✅ (yeni) |
| `local_recipe_repository_test.dart` | 11 | ✅ (yeni: 8 repo + 3 round-trip) |
| `feed_repository_test.dart` | 11 | ✅ |
| `social_group_repository_test.dart` | 11 | ✅ |
| `dealer_balance_test.dart` | 7 | ✅ |
| `dealer_repository_test.dart` | 4 | ✅ |
| `dealer_share_builder_test.dart` | 2 | ✅ |
| `dealer_pdf_builder_test.dart` | 2 | ✅ |
| `repository_provider_selection_test.dart` | 2 | ✅ |
| `feed_composer_layout_test.dart` | 2 | ✅ |
| `widget_test.dart` | 1 | ✅ |

**Kontrol noktaları:**
- `RecipeCalculator` brief örneği `50/60/1/2/250/3` → `316` adet → ✅
- `RecipeShareTextBuilder` WhatsApp formatı → 6 senaryo (briefin örneği + title override + boş productName + malzeme/adım/pişirme/not + sıralama) ✅
- `LocalRecipeRepository` CRUD + watch stream + sıralama ✅
- `RecipeMetadata.toJson/fromJson` tam round-trip + boş + forward-compat (bilinmeyen anahtar yutulur) ✅
- Mevcut 46 testin tamamı bozulmadan geçti ✅

---

## 11. Kalan eksikler / sonraki faz

### Foto / video upload (V1.2+)
- `recipe_calculations.metadata.mediaHints[]` schema'da yer açık ama UI placeholder.
- Yapılacaklar:
  - `image_picker` paketi pubspec'e
  - Supabase Storage bucket: `recipe-media` (RLS owner-only)
  - Editor'da "+Foto ekle" butonu → upload → URL'i `mediaHints[]`'e yaz
  - Detay ekranında thumb grid + lightbox
- Mevcut placeholder mesaj net: *"Foto ve video yükleme sonraki fazda aktif olacak. Bu reçete metin tabanlı paylaşılabilir."*

### Reçete için zenginleştirilmiş schema (opsiyonel)
Eğer "Trabzon Ekmeği gibi serbest başlığa göre arama" veya "tariflerden filtreleme" V1.2'de gelirse:
- `metadata` jsonb içindeki `title`, `ingredients[].name` üzerine **GIN index** açılabilir.
- Tam metin arama için `tsvector` generated column eklenebilir.
- Migration tek `alter table`'lık, RLS değişmez. Bu fazda gerek yoktu.

### Feed / grup gerçek backend entegrasyonu (V2)
- Mevcut `FeedRepository` ve `SocialGroupRepository` local in-memory.
- "Feed'de paylaş" yine çalışır (local feed'e yazıyor) ama Supabase backend gelirse otomatik geçer.
- "Grupta paylaş" — şu an snackbar "yakında". Grup seçimi için modal sheet ekleyip `socialGroupRepository.postMessage(...)` çağırılabilir.

### Reçete kopyalama / klonlama
- Detay ekranında "Yeni bir reçeteye kopyala" butonu. Editör'ü `recipeId == null` modunda açıp ön doldurma yapar.

### Pişirme zamanlayıcısı (idea)
- Detay ekranında "Adımı başlat" butonu adım `durationMin` ile zamanlayıcı çalıştırır.

### Bakım: ürün katalog entegrasyonu
- Şu an reçete `product_name` ile serbest metin tutuyor. İleride `bakery_products` katalogundan seçim eklenebilir, ama brief bunu istemedi.

---

## Kırmızı çizgilerin kontrolü

| Kural | Durum |
|---|---|
| RLS gevşetme yok | ✅ Trigger ve policy'lere dokunulmadı |
| service_role / PAT / DB password Flutter'a girmedi | ✅ |
| Tasarım renklerine dokunulmadı | ✅ AppColors/AppShadow değişmedi |
| Profil ekranına dokunulmadı | ✅ |
| Sosyal akışın ana mimarisi bozulmadı | ✅ FeedRepository.addPost imzası mevcut, ek değişiklik yok |
| Mevcut 46 test bozulmadı | ✅ 46/46 geçti, üstüne 17 yeni eklendi → 63/63 |
| Reçete varsayılan private | ✅ RLS owner-only (zaten vardı) |
| Paylaşım reçeteyi public yapmaz | ✅ Sadece Feed'e ayrı kopya / system share metni üretir |

---

## Test örneği — brief uyumu

| Girdi | Beklenen | Local (RecipeCalculator) | Supabase trigger |
|---|---|---|---|
| `flour_kg=50, water=60%, yeast=1%, salt=2%, unit=250g, waste=3%` | `water=30 kg, yeast=0.5 kg, salt=1 kg, total=81.5 kg, net=79.055 kg, count=316` | ✅ | ✅ (formül kodu birebir aynı) |

İki kanal eş çıktı veriyor — `flutter test` ve migration `calculate_recipe_calculation()` aynı algoritmayı çalıştırıyor.

---

**Hedef gerçekleşti:** Reçete modülü artık sadece hesap makinesi değil; kullanıcının ürün bazlı reçetelerini kaydettiği, malzemelerini ve yapılışını yazdığı, gerektiğinde paylaşabildiği bir **FırınNet Reçete Kütüphanesi**.
