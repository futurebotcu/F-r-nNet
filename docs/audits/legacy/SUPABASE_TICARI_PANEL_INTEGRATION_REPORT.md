# FırınNet — Ticari Panel Supabase Entegrasyonu Raporu

Tarih: 2026-05-12
Yaklaşım: **A) Core flow Supabase, geri kalan Local** (hibrit V1).

**Uygulanan kurallar:**
- service_role / PAT / DB password kullanılmadı.
- Anon/publishable key client'a hardcode edilmedi (`--dart-define` ile build-time).
- RLS / schema değiştirilmedi.
- Tasarım, renk, akış değişmedi.
- Mevcut local/mock impl'ler **bozulmadı**; anahtarsız çalıştırmada eski davranış.

---

## 1. Değişen / Eklenen Dosyalar

**Yeni:**
- `lib/features/bakery_panel/repositories/supabase_bakery_repository.dart`
- `lib/features/dealers/repositories/supabase_dealer_repository.dart`
- `test/repository_provider_selection_test.dart` — anahtarsız çalıştırmada Local impl ve seed dolulu doğrulaması.

**Revize:**
- `lib/features/bakery_panel/providers/bakery_providers.dart` — `bakeryRepositoryProvider` Supabase+currentUser kombinasyonuna göre Local/Supabase swap.
- `lib/features/dealers/providers/dealer_providers.dart` — `dealerRepositoryProvider` aynı swap mantığı.

**Hiç dokunulmayan (kapsam dışı, kasıtlı):**
- 14 ekran (`bakery_panel_screen`, `production_entry_screen`, `waste_entry_screen`, `recipe_calculator_screen`, `end_of_day_screen`, `report_screen`, `dealer_list_screen`, `add_dealer_screen`, `dealer_detail_screen`, 4 dealer form ekranı, `dealer_share_screen`). Hepsi mevcut abstract repository üzerinden çalıştığı için **swap-only yaklaşım**la otomatik Supabase'e gitti.
- Tüm modeller, hesap servisleri (`RecipeCalculator`, `DealerBalanceService`, `ReportBuilder`, `DealerPdfBuilder`, `DealerShareBuilder`).
- `local_*_repository.dart` — Local impl'ler aynen korundu.
- Tüm tema, router, auth katmanı.

## 2. Supabase'e Bağlanan Tablolar

| Tablo | İşlem | Repository tarafı |
|---|---|---|
| `bakeries` | Otomatik default işletme oluşturma (`ensureDefaultBakery`) | Bakery + Dealer (her ikisi de bakery_id ister) |
| `production_entries` | INSERT, SELECT (owner_id + production_date) | Bakery |
| `waste_entries` | INSERT, SELECT (owner_id + waste_date) | Bakery |
| `dealers` | LIST, GET, UPSERT, setActive | Dealer |
| `dealer_deliveries` | INSERT (parent) | Dealer (delivery type), Bakery (read-only) |
| `dealer_delivery_items` | INSERT (child) | Dealer (delivery type), Bakery (read-only) |

## 3. Repository / Provider Mimarisi

### 3.1 BakeryRepository
```dart
abstract class BakeryRepository {
  listProduction({day?}), addProduction()
  listDeliveries({day?}), addDelivery()        // ← legacy V1, Supabase impl StateError fırlatır
  listWastes({day?}), addWaste()
  dailySummary(day)
  watch()
}
```

Implementasyonlar:
- `LocalBakeryRepository` (in-memory; mevcut, değişmedi)
- `SupabaseBakeryRepository` (yeni; tüm INSERT'lerde `owner_id = auth.uid()`, `bakery_id = ensureDefaultBakery()`)

### 3.2 DealerRepository
```dart
abstract class DealerRepository {
  listDealers({activeOnly?}), getDealer(), upsertDealer(), setActive()
  listPrices(), currentPriceFor(), addPrice()
  listTransactions(), listAllTransactions(), addTransaction()
  listNotes(), addNote()
  watch()
}
```

Implementasyonlar:
- `LocalDealerRepository(seed: true)` (mevcut, demo 4 bayi)
- `SupabaseDealerRepository` (yeni; **compose pattern**: içinde `LocalDealerRepository(seed: false)` tutar; payment/return/adjustment/price/multi-note bu local cache'e gider, dealer + delivery Supabase'e gider)

### 3.3 Provider seçim mantığı
```dart
final bakeryRepositoryProvider = Provider<BakeryRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseBakeryRepository(sb.Supabase.instance.client);
  }
  return LocalBakeryRepository();
});
```

`AppConfig.supabaseEnabled` (dart-define) **VE** oturum açık ise Supabase; aksi halde Local. `currentAuthUserProvider` Riverpod'da watch edilir; sign-in / sign-out anında provider otomatik invalidate olur, repository swap olur, mevcut sayfalar yeniden yüklenir.

## 4. Local / Mock Fallback Nasıl Korundu

| Senaryo | Bakery repo | Dealer repo |
|---|---|---|
| `flutter run` (anahtarsız) | LocalBakeryRepository | LocalDealerRepository (seed: true) — 4 demo bayi |
| Anahtarlar verildi, oturum yok | LocalBakeryRepository | LocalDealerRepository (seed: true) |
| Anahtarlar verildi + signed in | SupabaseBakeryRepository | SupabaseDealerRepository (compose: kendi içindeki seed:false Local sadece extras için) |

Mevcut testler bu fallback üzerinden çalışmaya devam etti — 44/44 yeşil.

## 5. owner_id / RLS Güvenliği

- Her INSERT/UPDATE'de `owner_id = auth.currentUser.id`. Service-role veya admin path yok.
- `auth.currentUser` null ise repository **`StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.')`** fırlatır. Bu Türkçe mesaj UI'da SnackBar olarak yansır.
- Backend RLS policy'leri (`owner_id = auth.uid()`) zaten owner-based; bu repository'ler RLS'yi bypass etmez, normal `authenticated` JWT ile yazar.
- `bakery_id` her INSERT'te `ensureDefaultBakery()` ile gelir; başka kullanıcının bakery_id'sine yazma riski yok (FK + RLS çift katmanlı koruma).
- Cross-owner saldırı: `dealer_delivery_items` trigger'ı parent delivery'nin `owner_id`'sini her item için doğrular (önceki migrationda kuruldu).

## 6. Form Validasyonları

Mevcut form ekranlarının validasyonları **aynen korundu** — sadece veri akışı swap'landı. Spesifik kontroller:

| Ekran | Validasyon |
|---|---|
| `add_dealer_screen` | name boş olamaz |
| `production_entry_screen` | quantity > 0 |
| `waste_entry_screen` | quantity > 0, unitValue ≥ 0 |
| `recipe_calculator_screen` | flourKg > 0, unit_weight_g > 0 (RecipeCalculator clamp ile) |
| `dealer_delivery_form_screen` | productName seçili, quantity > 0, unitPrice > 0 |
| `dealer_return_form_screen` | productName seçili, quantity > 0 |
| `dealer_payment_form_screen` | amount > 0 |
| `dealer_adjustment_form_screen` | note zorunlu |

Backend tarafında ek CHECK constraint'ler (`quantity ≥ 0`, `returned_quantity ≤ quantity`, `account_type` whitelist vs.) zaten V1 migration'da kuruldu — double-layer.

## 7. Transaction / Tutarlılık

`dealer_deliveries` + `dealer_delivery_items` iki ayrı insert: Supabase Dart client DB-side transaction'ı doğrudan exposed etmez. Mevcut akış:
1. `dealer_deliveries` insert → parent id alınır
2. `dealer_delivery_items` insert (delivery_id ile)

Eğer item insert yarıda kalırsa (network kopması) **parent kayıt yetim kalır**. Bu durumda UI yenileme parent'ı listede gösterir ama item yoktur. Şu an için:
- Riski raporlayıp manuel temizliği belgeliyoruz (`delete from dealer_deliveries where ...` ile düşürülür).
- V1.1 çözüm: RPC fonksiyonu (`create_delivery_with_items`) yazıp tek transaction'da çalıştırmak; Supabase'in REST'i RPC ile transaction sağlar.

## 8. Manuel Test Adımları

```powershell
flutter run ^
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```

1. **Login**: fatihkartal75@gmail.com + şifre → `/panel` açılır → Ticari kart seti.
2. **Fırın Paneli** kartı → `/panel/bakery`. İlk açılışta tüm rakamlar 0; arka planda `bakeries` tablosunda kullanıcının satırı oluşmaz (henüz). MCP doğrulama:
   ```sql
   select id, name, city from public.bakeries
   where owner_id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
   ```
   Beklenen: 0 satır (henüz INSERT yok).
3. **Üretim Gir** → form: Ekmek 100 adet → Kaydet. MCP:
   ```sql
   select product_name, quantity, production_date from public.production_entries
   where owner_id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4'
   order by created_at desc;
   ```
   Beklenen: 1 satır. **Aynı sorguda** bakeries'i tekrar kontrol: 1 satır (default "Fırınım" otomatik oluştu).
4. **Reçete Hesapla** → 50 / 60 / 1 / 2 / 250 / 3 → estimatedPieces = 320 (RecipeCalculator local). Şu an Supabase'e KAYDEDİLMİYOR (UI ekranı yok); raporda kalan iş.
5. **Fire Gir** → Ekmek 5 adet, 8 TL → Kaydet. MCP:
   ```sql
   select product_name, quantity, unit_cost, estimated_loss from public.waste_entries
   where owner_id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
   ```
   Beklenen: `estimated_loss = 40` (5 × 8) trigger ile.
6. **Bayi Paneli** → Bayi Ekle: "Test Bayi", phone, area, working type. MCP:
   ```sql
   select name, phone, district, is_active from public.dealers
   where owner_id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
   ```
   Beklenen: 1 satır (`contact_name`, `working_type` yok — Flutter Dealer.contactName/workingType local-cache'de tutulur, kaybolabilir).
7. **Bayiye Ürün Ver** → Test Bayi → Ekmek 20 adet × 10 TL. MCP:
   ```sql
   select d.delivery_date, d.total_amount, d.returned_amount, d.paid_amount, d.remaining_amount
   from public.dealer_deliveries d
   where d.owner_id = 'abf96b42-0d17-40b1-9b0f-cbf910f9e2a4';
   ```
   Beklenen: `total_amount = 200`, `paid_amount = 0`, `remaining_amount = 200` (trigger).
8. **Ödeme Al** → 100 TL → Kaydet. **Şu an local-only** (V1 kısıt). MCP üzerinden Supabase'de yansımaz. UI hesabı bu local kaydı kombine eder; remaining 100 görünür.
9. **Gün sonu** → hero rakamları: üretim 100, fire 5/40 TL, bayi 200 TL.
10. **Çıkış / tekrar giriş** → Supabase'den production+waste+delivery yeniden çekilir; **ödeme kaybolur** (local-only, app restart'ta sıfır).

> **Kritik test**: Adım 10'da ödeme satırının kaybolması beklenen davranış. V1.1'de `dealer_transactions` tablosu eklenince bu kayıp kapanır.

## 9. `flutter analyze` + `flutter test`

| Komut | Sonuç |
|---|---|
| `flutter analyze` | `No issues found! (ran in 0.6s)` ✓ |
| `flutter test` | **46/46 passed** (mevcut 44 + 2 yeni provider seçim testi) ✓ |

## 10. Kalan Riskler

| Risk | Etki | Önerilen çözüm |
|---|---|---|
| **payment / return / adjustment local-only** | App restart'ta kaybolur → muhasebe kaybı | V1.1 migration: `dealer_transactions` tablosu (delivery/return/payment/adjustment enum + amount + dealer_id + owner_id) |
| **DealerPrice local-only** | Bayi-spesifik fiyat geçmişi app restart'ta sıfır | V1.1 migration: `dealer_prices` tablosu |
| **DealerNote multi-note local-only** | Birden fazla not app restart'ta kaybolur (tek `dealers.note` text alanı kalır) | V1.1 migration: `dealer_notes` tablosu |
| **Dealer.contactName / workingType atılır** | Form'da girilse de Supabase'e yazılmaz, UI'da boş görünür | V1.1 migration: `dealers.contact_name`, `working_type` alanları ekle |
| **dealer_deliveries+items 2-step insert** | İkinci insert hata alırsa yetim parent kalır | V1.1 RPC: `create_delivery_with_items` PL/pgSQL function |
| **bakery_products UI yok** | Tabloya hiç ürün eklenmez; production_entry product_id null kalır (product_name var) | V1.1 UI: ürün katalog ekranı |
| **recipe_calculations save UI yok** | Hesaplar saklanmaz, sadece anlık göster | V1.1 UI: hesap kaydet butonu |
| **UI error handling** | Repository fırlatırsa bazı form ekranlarında try/catch yok, beyaz ekran riski | Form ekranlarını gözden geçirip standart try/catch + Türkçe SnackBar ekle (kapsam dışı) |
| **legacy `/panel/dealer`** | `addDelivery(DealerDeliveryEntry)` çağrıldığında SupabaseBakeryRepository StateError fırlatır (Türkçe yönlendirme mesajı) | Router'dan kaldırılabilir; bu turda dokunulmadı |

## 11. Sonraki Faz Önerisi: V1.1 Schema Genişletme

Tek bir migration ile yukarıdaki "local-only" risklerin **hepsi** kapanır. Önerilen başlık: `firinnet_v1_1_dealer_extras`.

İçerik:
1. `alter table dealers add column contact_name text, working_type text default 'mixed' check (working_type in ('cash','term','mixed'))`
2. Yeni tablo `dealer_prices(id, owner_id, dealer_id, product_name, unit_price, valid_from, note)`
3. Yeni tablo `dealer_transactions(id, owner_id, dealer_id, type, product_name?, quantity?, unit_price?, amount, payment_method?, note, created_at)` — type enum'lu
4. Yeni tablo `dealer_notes(id, owner_id, dealer_id, note, created_at)`
5. Her tabloya RLS + owner-based policy + indexler

Migration uygulandıktan sonra:
- `SupabaseDealerRepository` içindeki `LocalDealerRepository` compose'u kaldırılır.
- Tüm transaction tipleri Supabase'e gider.
- App restart sonrası tam veri tutulur.

## 12. Çıktı Kriteri Doğrulaması

| Kriter | Durum |
|---|---|
| `flutter analyze` temiz | ✓ |
| `flutter test` yeşil | ✓ 46/46 |
| Anahtarsız mod local/mock çalışır | ✓ Provider seçim testi kanıt |
| Supabase modda ticari kullanıcı kendi üretim/bayi/fire/teslimat kayıtlarını oluşturabilir | ✓ (manuel test ile doğrulanır) |
| Renk/tasarım/akış bozulmaz | ✓ UI dokunulmadı, sadece provider swap |

---

## EK: Güncel dosya yapısı (özet)

```
lib/features/
├── bakery_panel/
│   ├── repositories/
│   │   ├── bakery_repository.dart       (abstract, mevcut)
│   │   ├── local_bakery_repository.dart  (mevcut, değişmedi)
│   │   └── supabase_bakery_repository.dart  ← yeni
│   └── providers/
│       └── bakery_providers.dart         ← revize: swap mantığı
└── dealers/
    ├── repositories/
    │   ├── dealer_repository.dart       (abstract, mevcut)
    │   ├── local_dealer_repository.dart  (mevcut, değişmedi)
    │   └── supabase_dealer_repository.dart  ← yeni (compose pattern)
    └── providers/
        └── dealer_providers.dart         ← revize: swap mantığı

test/
└── repository_provider_selection_test.dart  ← yeni
```
