# RECIPE_QUANTITY_AND_VISIBILITY_FIX_REPORT

**Tarih:** 2026-05-13 (V1.1 hotfix)
**Konu:** Reçete sistemi yüzde formundan **gerçek miktar formuna** geçti; reçeteye **gizli / profilde açık** görünürlük bayrağı eklendi.
**Test:** `flutter analyze` temiz, `flutter test` 77/77 yeşil (63 mevcut + 14 yeni)

---

## 1. Neden yüzde formu kaldırıldı

Önceki implementasyonda kullanıcı şu alanları yüzdelik giriyordu: su %, maya %, tuz %, fire %. Bu fırıncının gerçek kullanım modeline ters. Fırıncı tezgâhta yüzde değil **gerçek ölçü** ile düşünür:

> *"Un 50 kg, su 30 L, maya 500 gr, tuz 1 kg, gramaj 250 gr, fire 2.445 kg."*

Eski form bunu gizliyordu — kullanıcının kafasında %60 değil "30 L" var. Bu farkı UI'da kapatmak yerine modeli düzelttik.

---

## 2. Yeni gerçek miktar formu

Editor (`recipe_editor_screen.dart`) artık şu alanları gösteriyor:

| Alan | Birim seçenekleri | Default |
|---|---|---|
| Un | kg | 50 |
| Su | **L / kg** toggle | 30 L |
| Maya | **gr / kg** toggle | 500 gr |
| Tuz | **kg / gr** toggle | 1 kg |
| Birim gramaj | gr | 250 |
| Fire / kayıp | **kg / gr** toggle, opsiyonel | boş |
| Pişirme derecesi | °C | boş |
| Pişirme süresi | dk | boş |
| Mayalanma / dinlendirme | dk | boş |

Yüzde alanları (Su %, Maya %, Tuz %, Fire %) **tamamen kaldırıldı.** İçeride birim seçimi `kg`/`gr`/`L` arasında geçiş yapan kompakt pill grubu (`_UnitChips`).

### Yeni hesap formülü (`RecipeCalculator.calculateFromQuantities`)

```dart
total = flour + water + yeast + salt + extras_kg
net   = total - waste     (clamped >= 0)
count = floor(net * 1000 / piece_weight_gr)
```

- `extras_kg`: malzeme listesindeki **kg'a çevrilebilen** ek malzemelerin toplamı. `unitToKg(amount, unit)` yardımcısı; `kg`/`g`/`gr`/`gram`/`l`/`lt`/`litre`/`ml` desteklenir, "adet"/"yumurta" gibi anlamsız birimler atlanır.
- `1 L su ≈ 1 kg` kabulü.
- Maya/tuz/fire için kullanıcı `gr` seçmişse UI değeri 1000'e bölerek kg'a normalize eder.

### Brief örneği — testle doğrulandı

```
Un: 50 kg / Su: 30 L / Maya: 500 gr / Tuz: 1 kg / Gramaj: 250 gr / Fire: 2.445 kg
→ total = 81.5 kg / net = 79.055 kg / count = 316 adet
```

Test: `test/recipe_quantity_visibility_test.dart` → "briefteki örnek: 50/30L/500gr/1kg/250gr/2.445kg → 316 adet" ✅

---

## 3. Eski yüzde kolonlarıyla Supabase mapping nasıl çözüldü

Mevcut `recipe_calculations` tablosunda yüzde kolonları (`water_percent`, `yeast_percent`, `salt_percent`, `waste_percent`) + `flour_kg` + `unit_weight_gr` + check constraint'ler var. Ayrıca BEFORE INSERT/UPDATE trigger yüzde→kg dönüşümünü yapıp `water_kg`/`yeast_kg`/`salt_kg`/`total_dough_kg`/`net_dough_kg`/`estimated_count` sütunlarını dolduruyor.

**Trigger'a dokunulmadı** (büyük schema kırılımı yok). Yerine `SupabaseRecipeRepository._toRow`'da kullanıcı miktarlarından yüzde türetiliyor:

```dart
water_percent = water_kg / flour_kg * 100        // 30/50*100 = 60 ✓
yeast_percent = yeast_kg / flour_kg * 100        // 0.5/50*100 = 1
salt_percent  = salt_kg  / flour_kg * 100        // 1/50*100 = 2
waste_percent = waste_kg / (flour+water+yeast+salt) * 100   // 2.445/81.5*100 = 3
                                                  // (clamp [0,100])
```

Bu sayede trigger'ın doldurduğu kg sütunları gerçek miktarlarla bire bir eşleşir. Brief örneği için trigger çıktısı: `water_kg=30, yeast_kg=0.5, salt_kg=1, total=81.5, net=79.055, count=316` — UI'daki client-side hesapla aynı.

### Çelişki / sınırlama

Trigger **extras** (yağ/susam/şeker vs.) hakkında bilgi sahibi değil — sadece base 4 malzemeden hesap yapar. Brief'in istediği `extra_ingredients_kg` toplamı tabloya yansımıyor. Bu kısmı çözmek için:

- **Otorite kaynak metadata.** `metadata.quantities` JSON sütununda gerçek miktarlar saklanıyor.
- **Repository read-side:** `_fromRow` her okumada `RecipeCalculator.calculateFromQuantities` ile sonucu yeniden hesaplıyor (extras dahil). Tablodaki kg/sayı sütunlarına güvenmiyoruz.
- **DB sütunları yarı-uyumluluk** rolünde: SQL sorgulayıcılar için bir "no-extras snapshot". Brief'in istediği UI sonucu için extras dahil edilen client-side hesap kullanılıyor.

Schema/trigger değişikliği gerekmedi. Geleceğe taşınabilirlik için: extras dahil hesabı SQL'e taşımak gerekirse trigger güncellenir, RLS değişmez.

---

## 4. Gizli / herkese açık flag sistemi

### Migration: `20260513170000_firinnet_recipe_visibility.sql`

```sql
alter table public.recipe_calculations
  add column if not exists is_public boolean not null default false,
  add column if not exists published_at timestamptz;

create index if not exists idx_recipe_calculations_public_created
  on public.recipe_calculations (created_at desc)
  where is_public = true;

create policy recipe_calculations_select_public on public.recipe_calculations
  for select to authenticated
  using (is_public = true);
```

**RLS davranışı:**
- Owner mevcut `recipe_calculations_select_own` ile **tüm** kendi reçetelerini (gizli + açık) görür.
- Diğer authenticated kullanıcılar yeni `recipe_calculations_select_public` ile yalnız `is_public = true` reçeteleri görür (iki permissive policy OR'lanır).
- Insert/update/delete eskisi gibi **yalnız owner**. Public flag birinin reçetesini düzenleme/silme hakkı **vermez** — sadece okuma izni verir.
- **anon role'e select açılmadı.** Uygulamada kayıtsız kullanıcı profil gezme akışı yok; gerekirse ileride permissive `to anon` policy bir migration ile eklenir.

### Domain modeli

`Recipe.visibility: RecipeVisibility { private | public }` + `publishedAt: DateTime?` alanları eklendi. Varsayılan `private`. Test `Recipe visibility default Recipe.visibility = private` ile bağladık.

### Editor UI

`_VisibilityToggle` widget'ı reçete editöründe yeni "GÖRÜNÜRLÜK" bölümünde. `Switch.adaptive`:
- **Gizli**: "Sadece sen görürsün."
- **Profilimde görünsün**: "Profiline girenler bu reçeteyi görebilir."

### Liste / detay rozetleri

`VisibilityBadge` widget'ı (`recipe_visibility_badge.dart`) — liste kartının sağ üst köşesinde tarih altında ve detay header'ında. İki durum:
- 🔒 **GİZLİ** (muted)
- 🌍 **PROFİLDE AÇIK** (success/yeşil)

### `publishedAt` yönetimi

LocalRecipeRepository ve SupabaseRecipeRepository:
- Private → public geçişinde `publishedAt = now()`.
- Public → public geçişinde önceki damga korunur.
- Public → private geçişinde `publishedAt = null`.

(`copyWith(publishedAt: null)` `null`'ı "değişiklik yok" sayar — bu yüzden direkt constructor ile temizliyoruz.)

### Paylaş butonu

`RecipeShareTextBuilder` ve detay ekranındaki "Paylaş" sheet **tamamen ayrı**. Paylaş aksiyonu:
- `is_public` flag'ini değiştirmez.
- Sadece metin üretir + Feed/WhatsApp'a yollar.

Test: `share text builder is_public durumunu değiştirmez` ✅

---

## 5. Profile görünürlüğü

`ProfileScreen` (`lib/features/profile/screens/profile_screen.dart`) — minimum invaziv değişiklik:
- İstatistikler ile Hesap bölümleri arasına **"Açık Reçeteler"** section'ı eklendi.
- `SectionLabel.trailingLabel = 'Tüm reçetelerim'` linki `/recipes`'a push yapar.
- `_PublicRecipesSection` widget'ı `publicRecipesByOwnerProvider(currentUser.id ?? 'local')` izler.
- Boş durumda kart "henüz açık reçeten yok — bir reçeteyi düzenleyip 'Profilimde görünsün' seç" mesajı.
- Dolu durumda her açık reçete tek satırlık tile (başlık + miktar/adet + visibility badge), tıklanınca detay.

Profil hero, stats, account list, logout button yapısı **dokunulmadı**. Renkler değiştirilmedi.

`SupabaseRecipeRepository.listPublicByOwner` `is_public = true` filtresiyle RLS'in yeni permissive policy'sini kullanır — başkasının profilini gezme akışı geldiğinde bu metod aynen çalışacak. Şu an UI sadece kendi profilini gösterdiği için sahip kendi açık reçetelerini görür.

---

## 6. Ticari ve bireysel erişim kontrolü

Önceki fazda eklenen "Reçetelerim" kartları **kontrol edildi ve teste bağlandı**:

| Rol | Reçetelerim kartı | Test |
|---|---|---|
| `commercial` (ticari) | ✅ Var, route `/recipes` | `RolePanelCards forAccount(commercial)` — bulundu |
| `individual` (bireysel) | ✅ Var, route `/recipes` | `RolePanelCards forAccount(individual)` — bulundu |
| `wholesaler` (toptancı) | ❌ Yok (brief gereği değil) | — |

Ayrıca:
- Ticari Fırın Paneli'nde featured tile zaten "Reçeteler" → `/recipes`.
- Legacy `/panel/recipe` `/recipes`'a redirect.

Test: `recipe_quantity_visibility_test.dart` → "ticari rolde Reçetelerim kartı /recipes'a yönlendirir" + "bireysel rolde Reçetelerim kartı /recipes'a yönlendirir" ✅

**Ticari ve bireysel için tek ortak `/recipes` sistemi. Ayrı hesap mantığı yok.**

---

## 7. Değişen dosyalar

### Yeni
- `supabase/migrations/20260513170000_firinnet_recipe_visibility.sql` — visibility migration
- `lib/features/bakery_panel/models/recipe_quantities.dart` — gerçek miktar modeli + `unitToKg`
- `lib/features/bakery_panel/screens/recipe_visibility_badge.dart` — gizli/açık rozeti
- `test/recipe_quantity_visibility_test.dart` — 14 yeni test

### Düzenlendi
- `lib/features/bakery_panel/services/recipe_calculator.dart` — yeni `calculateFromQuantities`; eski `calculate(RecipeInput)` legacy test yüzeyi için korunuyor
- `lib/features/bakery_panel/models/recipe_record.dart` — `quantities` primary, `visibility`/`publishedAt`/`isPublic` alanları, `RecipeVisibility` enum
- `lib/features/bakery_panel/services/recipe_share_text_builder.dart` — `recipe.input.*` → `recipe.quantities.*`
- `lib/features/bakery_panel/repositories/recipe_repository.dart` — `listPublicByOwner(ownerId)` eklendi
- `lib/features/bakery_panel/repositories/local_recipe_repository.dart` — quantities, visibility, publishedAt geçişleri; `listPublicByOwner`
- `lib/features/bakery_panel/repositories/supabase_recipe_repository.dart` — gerçek miktar → yüzde mapping; `is_public`/`published_at` kolonları; `listPublicByOwner`; `_fromRow` quantities'ı metadata'dan okuyup result'ı client-side hesaplar
- `lib/features/bakery_panel/providers/bakery_providers.dart` — `publicRecipesByOwnerProvider(ownerId)`
- `lib/features/bakery_panel/screens/recipe_editor_screen.dart` — yüzde formu kaldırıldı, gerçek miktar + birim toggle'ları + görünürlük switch + ownerId set
- `lib/features/bakery_panel/screens/recipes_list_screen.dart` — `recipe.quantities.*` + visibility badge
- `lib/features/bakery_panel/screens/recipe_detail_screen.dart` — header'da visibility badge
- `lib/features/profile/screens/profile_screen.dart` — "Açık Reçeteler" section + `_PublicRecipesSection`
- `test/recipe_share_text_builder_test.dart` — quantities sample fixture'a güncellendi
- `test/local_recipe_repository_test.dart` — quantities sample fixture'a güncellendi

---

## 8. Migration dosyası

`supabase/migrations/20260513170000_firinnet_recipe_visibility.sql` — yukarıda (madde 4) tam içerik. `mcp__supabase__apply_migration` ile remote'a uygulandı, başarılı.

**Geri dönüş:**
```sql
drop policy recipe_calculations_select_public on public.recipe_calculations;
drop index idx_recipe_calculations_public_created;
alter table public.recipe_calculations drop column published_at, drop column is_public;
```

---

## 9. `flutter analyze` sonucu

```
Analyzing firinnet...
No issues found! (ran in 0.6s)
```

---

## 10. `flutter test` sonucu

```
00:02 +77: All tests passed!
```

**14 yeni test:**

| Test | İçerik |
|---|---|
| briefteki örnek: 50/30L/500gr/1kg/250gr/2.445kg → 316 adet | Quantities formülü ✅ |
| fire boş bırakılırsa toplam hamur olduğu gibi alınır | wasteKg=0 ✅ |
| extras kg dahil toplam hamuru artırır | Yağ + susam toplamı total'a eklenir ✅ |
| extras "adet" gibi anlamsız birimlerini görmezden gelir | Yumurta 3 adet → extras=0 ✅ |
| gr birimi 1000'e bölünür (L = kg kabulü) | unitToKg map ✅ |
| waste > total ise net 0'a clamp olur | Edge case ✅ |
| RecipeQuantities defaults round-trip | JSON ✅ |
| null json → defaults | JSON edge ✅ |
| default Recipe.visibility = private | Brief gereği ✅ |
| private → public geçişi LocalRepo'da publishedAt set eder | Toggle + retract ✅ |
| listPublicByOwner sadece is_public=true sahip kayıtları döner | Filtreleme ✅ |
| share text builder is_public durumunu değiştirmez | Paylaş ayrı ✅ |
| ticari rolde Reçetelerim kartı /recipes'a yönlendirir | Erişim kontrolü ✅ |
| bireysel rolde Reçetelerim kartı /recipes'a yönlendirir | Erişim kontrolü ✅ |

**63 mevcut test bozulmadan geçti** (44 base + 11 dealer/feed/group/widget + 2 testWidgets + 6 share builder eski + ... toplam 63). Önceki Recipe API'sini kullanan tester fixture'lar quantities'a göçürüldü, semantikleri aynı.

---

## 11. Kalan eksikler / sonraki faz

### Başka kullanıcının profilini görüntüleme
Şu an `/profile` ekranı yalnız kendi profilini gösteriyor. `/users/:id` veya `/profile/:id` route'u eklendiğinde:
- `_PublicRecipesSection`'a `ownerId` parametresi geç.
- `publicRecipesByOwnerProvider(ownerId)` çağrısı RLS sayesinde başkasının açık reçetelerini döner.
- Listelenecek mantık zaten hazır.

### Anon (kayıtsız) için public select
Uygulamada anon kullanıcı profil gezmiyorsa gerek yok. Açılırsa:
```sql
create policy recipe_calculations_select_public_anon on public.recipe_calculations
  for select to anon
  using (is_public = true);
```

### Trigger'a extras farkındalığı
Şu an `total_dough_kg`/`estimated_count` tablodaki sütunlar **extras hariç**. SQL analitik / başka istemci kullanıyorsa bu eksik. Çözüm: trigger'ı `metadata.ingredients` üzerinden okumaya bağlamak veya yeni `total_dough_kg_with_extras` generated column eklemek — bu fazda yapılmadı (büyük migration, brief yasakladı).

### Foto / video upload
Önceki faz raporundaki kalan iş — V1.1'de yine placeholder. Editor ve detayda mesaj net: "Görsel ekleme sonraki fazda aktif olacak."

### Grup paylaşımı
Detay ekranındaki share sheet'te "Grupta paylaş" hâlâ "YAKINDA" rozeti. Backend altyapısı geldiğinde modal sheet'ten grup seç + `SocialGroupRepository.postMessage` çağırılacak.

### `metadata.quantities` migrasyonu eski kayıtlar için
Eski (V1.1-öncesi) reçete kayıtları `metadata.quantities` içermiyor olabilir. `SupabaseRecipeRepository._fromRow` bu durumda DB'deki yüzde-türetilmiş kg sütunlarından quantities kuruyor — backward compat sağlanmış durumda. Tek-seferlik migration script ihtiyacı yok.

---

## Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Profil tasarımına dokunma | ✅ Sadece yeni section eklendi; hero/stats/account list/logout aynen |
| Sosyal akış ana mimarisini bozma | ✅ FeedRepository/SocialGroupRepository imzaları değişmedi |
| İlanlar/mesajlar/ticari panel genel yapısına dokunma | ✅ Sadece bakery panel featured tile route'u (önceki fazda) |
| Tasarım renklerini değiştirme | ✅ AppColors/AppShadow değişmedi |
| service_role / PAT / DB password kullanma | ✅ Yalnız MCP üzerinden migration |
| Flutter client içine secret koyma | ✅ |
| Mevcut 63 test bozulmasın | ✅ 63 + 14 = 77/77 |
| Hem ticari hem bireysel erişim | ✅ Her iki rolde "Reçetelerim" kartı testle bağlı |
| Ticari ve bireysel için ayrı hesap mantığı kurma | ✅ Tek `RecipeCalculator`, tek `/recipes` ekranları |
| RLS gevşetme | ✅ Mevcut owner-only policy'ler aynen; eklenen public-read **sadece select**, üzerine de filtreli (`is_public = true`) |

---

**Hedef gerçekleşti:** Reçete sistemi fırıncının gerçek kullanım modeline geçti — **yüzde değil gerçek miktar**, varsayılan **gizli**, isteğe bağlı **profilde açık**, hem ticari hem bireysel için **ortak ve zorunlu erişilebilir** tek sistem.
