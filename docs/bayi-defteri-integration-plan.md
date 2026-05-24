# Bayi Defteri — Integration Plan

> **Karar dokümanı, kod değil.** Bu doküman Bayi Defteri'nin sonraki sprint
> grubunun "neden", "ne", "ne ile", "ne zaman değil" sorularını netleştirir.
> Hiçbir kod henüz yazılmadı; hiçbir migration apply edilmedi.

**Doküman tarihi:** 2026-05-24
**Branch:** `feat/bayi-defteri-metrics-foundation` (Phase 1 metrics foundation
commit'i `454d1cb` aynı branch'te)
**Ana referans commit'ler:** `861bbee` C1 fix · `454d1cb` Phase 1 metrics

---

## 0. Çerçeve kararları (audit trail, değiştirilemeyen 9 madde)

Bu dokümanın geri kalanı bu 9 maddenin somutlaştırılmasıdır.

1. **FırınNet'in mevcut Bayi Defteri özelliği korunacak.** Mevcut repository
   katmanı (`DealerRepository` abstract + Local + Supabase + Guarded
   decorator), `DealerBalanceService.summarize` davranışı, `DealerTransaction`
   4-tip enum'u, `Dealer.copyWith _sentinel` paterni, PDF/Share builder'ları
   ve mevcut 9 ekran dokunulmadan kalır. Sonraki sprint'ler **mevcudun yanına
   ekler**, yerine geçmez.

2. **Donor sistem (flutter-pos-system) komple alınmayacak.** Donor
   uygulamasının auth/Provider state mgmt/sqflite wrapper/Firebase suite/
   Syncfusion charts/Google Drive export bileşenleri **alınmayacak**. Donor
   bağımlılıklarından hiçbiri `pubspec.yaml`'a eklenmeyecek.

3. **flutter-pos-system'dan yalnız domain flow / stashed order / settlement
   / cashier mantığı uyarlanacak.** Spesifik olarak: (a) `stashed_orders.dart`
   tablo + serialization paterni → draft transaction altyapısına, (b)
   `surplus_page.dart` 4-kolon DataTable + tap-edit-confirm akışı → gün sonu
   mutabakat ekranına, (c) `cashier.dart` denomination + change-finding
   mantığı → tahsilat formuna opsiyonel calculator widget'ına, (d)
   `Seller.getMetricsInPeriod` CAST-bucket SQL paterni → ileride DB-side
   aggregate view yazılırken ADR olarak, (e) `GoalsCardView` EMA-over-20-days
   baseline mantığı → "bu hafta normalden yüksek/düşük" pulse card'ına.

4. **Bireysel Bayi Defteri açık kalacak.** C1 commit `319981f` bireyselin
   kendi defterini kapatıp `EmptyAuthorizedState` gösteriyordu — yanlış
   ürün modeliydi. C1 fix commit `861bbee` ile düzeltildi: **bireysel
   kullanıcı kendi normal `/dealers` defterini açar, ticari ile aynı
   davranış.** Bu durum yetkilendirme akışından bağımsız ve değişmeyecek.

5. **Ticari kullanıcı Bayi Defteri içinde "Şoför / Yetkili Kullanıcı ekle"
   paneli ile bireyselin FırınNet ID'sini yetkilendirecek.** Bu panel,
   ticari kullanıcının Bayi Defteri ekranında yeni bir sekme/alt-route
   olarak yer alır. Yetkilendirme `dealer_staff` tablosuna yazılır
   (C2 migration'ları zaten hazır). FırınNet ID politikası (`FN-YYYY-NNNNNN`,
   yalnız sahibe gösterilen) bu RPC için tek istisna: ticari, FırınNet ID
   ile bireysele invite çıkarır.

6. **Yetkilendirilen bireysel kullanıcı kendi Bayi Defteri içinde "Usta
   Fırın adına işlem yapıyorsun" context'iyle işlem yapacak.** Bireysel
   kendi defterini görmeye devam eder; üstüne, yetkilendirildiği her
   ticari işletme için ayrı bir context seçimi gelir. Context değiştiğinde
   `activeOwnerContextProvider` o ticari sahibinin owner_id'sini kullanır.

7. **Bu context'te yazılan işlemler ticari işletmenin defterine yazılır.**
   Bireysel kullanıcının kendi defterine sızmaz. Yazma payload'ı:
   `owner_id = ticari sahip`, `created_by = bireysel staff user`. RLS
   (C2 migration `200200_dealer_ledger_rls_staff.sql`) bu ayrımı zaten
   tanımlı; Dart tarafı bağlanacak.

8. **Staff / driver sprinti C2 DB/RLS test ortamı hazır olmadan
   production'a uygulanmayacak.** Mevcut C2 untracked migration dosyaları
   (`supabase/migrations/20260524200000_dealer_staff_v1.sql` + 3 sibling)
   yalnız (a) Docker Desktop + `supabase start` ya da (b) izole dev
   Supabase projesi hazır olduğunda apply edilir. Production'a doğrudan
   apply YOK. Bu kural sprint planının pre-condition'ıdır.

9. **Sıradaki gerçek sprint'ler — sıra önemli:**
   - Sprint 1: **Staff Dart bağlantısı** (`activeOwnerContextProvider` +
     `StaffScopeDealerRepository` decorator + `_ensureDefaultBakeryId`
     refactor + repository payload'larına `created_by` + staff invite UI)
   - Sprint 2: **Draft transaction** (`dealer_transaction_drafts` tablo
     + `DraftDealerTransactionRepository` + draft inbox UI)
   - Sprint 3: **Range UI** (Phase 1 commit'inde hazır olan `DealerPeriod`
     + `DealerRangeMetrics` + `summarizeRange()`'i tüketen rapor ekranı)
   - Sprint 4: **Settlement / gün sonu mutabakat** (`dealer_settlements`
     tablo + donor `surplus_page` lift + persistent close log)
   - Sprint 5: **Edit / Delete / Multi-item delivery + tarih seçici**
     (dealer edit ekranı, swipe-to-deactivate, form tarih picker,
     multi-line `dealer_delivery_items` insert)

---

## 1. Yönetici özeti

FırınNet'in mevcut Bayi Defteri kemiği sağlam: temiz repository + decorator,
dependency-free hesap servisi, dual local/Supabase implementasyonu,
exhaustive switch ile yeni tx tipi eklemeyi compile-time yakalayan model.

Eksikler: tek-item delivery hapishanesi, edit/delete UI'sının yokluğu, vade
/ aging kavramı, kullanıcı tarafından seçilebilir tarih, range raporu UI'sı,
gün sonu mutabakat akışı, draft tx kavramı ve staff context bağlantısı.

Donor `flutter-pos-system` bunların 5'i için temiz lift sağlıyor; 3'ü
tamamen FırınNet'in kendi işi (edit UI, vade, staff context bağlantısı).

Riski en düşük entegrasyon sırası **Madde 9**'da listelenen 5 sprint.
Toplam efor: ~3-4 hafta, monolitik değil ayrı PR'lar.

---

## 2. FırınNet mevcut Bayi Defteri — özet snapshot

> Tam current state audit ayrı session raporunda. Burada yalnız integration
> kararını ilgilendiren özet.

**Mevcut yapı:**
- **9 ekran:** dealer_list, dealer_detail, add_dealer, 4 form ekranı
  (delivery/return/payment/adjustment), dealer_share, wholesale_customers.
- **6 model:** Dealer, DealerTransaction, DealerBalanceSummary, DealerPrice,
  DealerNote, DealerRangeMetrics (Phase 1'de eklendi).
- **4 repository:** abstract `DealerRepository` + `LocalDealerRepository`
  (seed) + `SupabaseDealerRepository` + `GuardedDealerRepository`
  (decorator, guest write engelliyor).
- **13 provider:** `dealerChangesProvider` (Stream\<void\>) merkezli;
  yazmadan sonra `_notify()` tüm bağlı `FutureProvider.autoDispose` zincirini
  invalidate eder.
- **DB şeması:** `dealers` + `dealer_deliveries` + `dealer_delivery_items`
  (parent-child, line_total trigger) + `dealer_transactions` (non-delivery
  tipler) + `dealer_prices` + `dealer_notes`.

**Mevcut akış (örnek: teslimat ekleme):**
detail screen → "Teslim" action chip → `/dealers/:id/delivery` →
`DealerDeliveryFormScreen` → product seç → autofill fiyat
(`repo.currentPriceFor`) → save → `GuardedDealerRepository.addTransaction`
→ `SupabaseDealerRepository._addDeliveryToSupabase` → `dealer_deliveries`
parent insert + `dealer_delivery_items` child insert → `_notify()` →
provider invalidation → UI refresh.

**Gap'ler (mini-POS beklentilerine göre):** edit dealer UI yok, deactivate
/ delete UI yok, multi-item delivery UI yok (DB hazır), tarih seçici yok
(`createdAt = now` hard-coded), açılış bakiyesi (devir) yok, vade/aging
yok, range raporu UI yok (Phase 1 groundwork hazır ama bind edilmemiş),
gün sonu mutabakat yok, draft tx yok, staff context yok, başka cihazdan
gelen tx için realtime sync yok.

---

## 3. Donor (flutter-pos-system) — kapsam

**Donor:** evan361425/flutter-pos-system, Apache-2.0, mobile-portrait POS,
Flutter 3.41+, Provider state mgmt, sqflite + sembast, Firebase
observability. Aktif maintained (son release 2026-05-10).

**Niye bu donor:** İki bağımsız audit'in (RetailSale GPL-3.0 + SaleFlex
AGPL-3.0 + multi-role-flutter-auth license'sız + uber-clone license'sız)
sonunda kod-lift için tek lisans-temiz, mobile portrait, aktif maintained
aday.

**Audit edilen 5 alternative:** Tablo halinde detay için bkz. session
notları. Özet: flutter-pos-system (Apache-2.0) tek lift adayı; RetailSale
yalnız rapor taksonomisi (kavramsal); SaleFlex yalnız mimari ADR'ları;
diğer 2 reddedildi (lisans).

---

## 4. Karar tabloları — ne yapılır, ne yapılmaz

### 4.1 FırınNet'te KORUNACAK (dokunulmaz)

| Korunacak | Sebep |
|-----------|-------|
| `DealerRepository` abstract interface | 13 metod, simetrik 3 implementasyon, decorator pattern hazır |
| `LocalDealerRepository` + seed | Guest mode + UI test sürdürülebilirliği |
| `GuardedDealerRepository` decorator | Cross-cutting concern (staff scope, audit log) yeni katman olarak eklenir; UI dokunulmaz |
| `DealerBalanceService.summarize()` davranışı | Mevcut 7 test geçiyor, bakery panel hero ve detail screen tüketiyor |
| `DealerTransactionType` enum + 9-yer-switch sigortası | Yeni tip eklemek compile-time exhaustive |
| `Dealer.copyWith` `_sentinel` paterni | Explicit-null'a izin verir |
| `DealerPdfBuilder` / `DealerShareBuilder` | Saf metodlar, provider-bağı yok, yeni varyant yan-yana eklenir |
| `DealerPeriod` + `DealerRangeMetrics` + `summarizeRange` (Phase 1, commit `454d1cb`) | Hazır temel, Sprint 3 UI'ı tüketecek |
| Dual-write konvansiyonu (city/cityCode + district/districtCode) | Profil feature'larıyla tutarlı |
| `bakery_id` cache (`_cachedBakeryId`) | Owner tek-fırın varsayımı için optimizasyon (staff için context değişecek) |

### 4.2 Donor'dan KOD ALINACAK (Apache-2.0 attribution ile)

| Donor dosya | FırınNet hedefi | Efor | Lisans aksiyonu |
|-------------|-----------------|------|-----------------|
| `lib/models/repository/stashed_orders.dart` (~50 satır) | `lib/features/dealers/repositories/draft_dealer_transaction_repository.dart` | S | NOTICE + Apache header + THIRD_PARTY_LICENSES.md |
| `lib/ui/cashier/surplus_page.dart` (4-kolon DataTable + tap-edit-dialog + Confirm) | `lib/features/dealers/screens/dealer_settlement_screen.dart` | S | Aynı |
| `lib/ui/order/checkout/checkout_cashier_calculator.dart` (Paid + Change + numeric keypad) | `lib/features/dealers/widgets/cash_tendered_calculator.dart` | S | Aynı |
| `lib/helpers/util.dart` ufak set (`toUTC` / `fromUTC` / `toCurrencyNum` / `getDateRange`) | `lib/core/util/datetime_x.dart` + `currency_x.dart` | S | Aynı |

**Toplam: ~250 satır production, 0 yeni dep, 0 MB ekleme.**

### 4.3 Donor'dan MANTIK alınacak (sıfırdan FırınNet-side yazılır)

| Donor pattern | FırınNet hedefi |
|---------------|------------------|
| `Seller.getMetricsInPeriod` SQL `CAST((createdAt - $begin) / $interval AS INT) day GROUP BY day` | İleride Supabase view/RPC ADR; **şimdilik backend dokunulmuyor** |
| `Seller.push` multi-table txn + denormalize createdAt | Multi-item delivery için Postgres function (Sprint 5, backend dokunur) |
| `Cart.checkout` 3-await partial-failure problemi | Önce öğren, sonra **kaçın** — FırınNet'te tekrar etme |
| `GoalsCardView` EMA-over-20-days baseline | `lib/features/dealers/widgets/dealer_pulse_card.dart` (saf Dart EMA) |
| `OrderObject.toStashMap()` id-only vs `toMap()` denormalized name ayrımı | Draft tx jsonb tasarımında **baştan** dual-id+name (catalog rename silent drop bug'ını biz yapmayız) |
| `Period` enum + `nextDate(unit)` rolling reset | Phase 1'de `DealerPeriod` ile kapatıldı |

### 4.4 KESİN ALINMAYACAK (skip)

| Donor parçası | Neden alınmıyor |
|---------------|-----------------|
| `lib/ui/order/order_page.dart` + `order_checkout_page.dart` | Restoran masa siparişi UX'i; fırın bayi teslimatıyla alakası yok |
| `lib/ui/analysis/analysis_view.dart` (user-configurable chart object grid) | V1 için overkill, chart authoring UI yıllar sonrası |
| `lib/services/database.dart` (sqflite wrapper, raw string interpolation) | Supabase API zaten daha iyi; SQLi-unsafe abstraction'a gerek yok |
| Provider 6.x + ChangeNotifier + singleton | FırınNet Riverpod; donor'un `X.instance.Y` çağrı paterni translate edilmeden hiçbir satır alınmaz |
| Firebase Analytics/Crashlytics/Performance/In-App Messaging deps | Donor'dan dep alma kuralı çiğnenir |
| `syncfusion_flutter_charts` | Community license commercial SaaS için riskli |
| `googleapis` + `google_sign_in` Drive export | FırınNet kendi PDF/share builder'ı zaten var |
| `Stock` repository + ingredient decrement | Üretim ↔ teslim arası "fire" hesabı ayrı sprint, Bayi Defteri'ne karıştırılmaz |
| `Cart.checkout` BuildContext-into-domain-method coupling | Anti-pattern |

---

## 5. Şoför / Yetkili Kullanıcı (staff) akışı — entegrasyon noktası

> Madde 5-6-7'nin somutlaştırılması.

### 5.1 Ürün modeli (özet)

- **Ticari kullanıcı (Fırın sahibi):** Bayi Defteri'nin sahibidir. Kendi
  defterini yönetir + Şoför/Yetkili paneline bireyselleri davet eder.
- **Bireysel kullanıcı:** Kendi normal /dealers defterini açar (C1 fix
  sonrası, Madde 4). Ayrıca yetkilendirildiği her ticari işletme için
  context seçer ve o sahibe ait deftere yazar.
- **Toptancı:** Bayi Defteri diline hiç girmez (mevcut redirect korunur).

### 5.2 Davet akışı (Madde 5)

1. Ticari kullanıcı Bayi Defteri içinde "Şoför / Yetkili Kullanıcı" sekmesi
   açar (yeni ekran: `dealer_staff_management_screen.dart`).
2. "Yetkili ekle" butonu → bireyselin FırınNet ID'sini girer
   (`FN-YYYY-NNNNNN` format).
3. RPC `invite_dealer_staff(target_firinnet_id, role)` (C2 migration'da
   tanımlı) çağrılır. Server tarafında target FırınNet ID owner ID'ye
   çevrilir; `dealer_staff` tablosuna `status = invited` satırı yazılır.
4. Bireysel kullanıcı bir sonraki açılışta bildirimi görür → kabul / red.
5. Kabulde `dealer_staff.status = active`.

> FırınNet ID politikası (`project_firinnet_id_policy` memory) tek istisna:
> RPC giriş parametresi olarak ID kabul edilir. Public surface'ta hâlâ
> görünmez (response payload sadece davet onayı döner, ID yansımaz).

### 5.3 Context seçimi (Madde 6)

- Yeni provider: `activeOwnerContextProvider` (`Provider<String?>`).
- Owner için identity = `currentUser.id`.
- Staff için seçim ekranı (`staff_owner_picker_screen.dart`): aktif
  staff atamaları listelenir → biri seçilince `activeOwnerContext = o
  owner_id`. shared_preferences'a persist (oturum boyunca hatırlanır).
- Bireysel kullanıcı UI'sında yetkilendirme varsa header'da "Usta Fırın
  X adına işlem yapıyorsun" banner gösterilir + "Kendi defterime dön"
  toggle.

### 5.4 Yazma payload'ı (Madde 7)

`SupabaseDealerRepository` refactor (Sprint 1):
- `_requireUserId()` (= staff user id, yazan kişi) → `created_by` kolon
- `_resolveOwnerId()` (yeni) = `activeOwnerContextProvider` değeri →
  `owner_id` kolon
- `_ensureDefaultBakeryId(_effectiveOwnerId)` — owner için bakery, staff
  context'inde de owner'ın bakery'sini bulur

RLS (C2 `200200_dealer_ledger_rls_staff.sql` zaten tanımlı):
- staff aktif ise owner_id'ye INSERT izni var
- DELETE patron-only (staff silemez)
- `dealer_delivery_items` parent-lookup-only

### 5.5 Hangi ekranlar staff context'i bilir, hangileri agnostik

| Bilir | Agnostik |
|-------|----------|
| `dealer_delivery_form_screen` (şoför ana use-case) | `DealerBalanceService` (saf calc) |
| `dealer_payment_form_screen` (şoför nakit toplar) | `DealerPdfBuilder`, `DealerShareBuilder` |
| `dealer_return_form_screen` (şoför iade getirir) | `LocalDealerRepository` (guest mode) |
| `dealer_list_screen` (staff yalnız atandığı owner'ın bayilerini görür) | Tüm model sınıfları |
| `dealer_detail_screen` Hero (staff görür ama bazı action'lar gizli) | |
| `add_dealer_screen` (staff genelde ekleyemez, guard role check) | |

Staff awareness yalnız **1 yeni provider + 1 yeni decorator + 2 yeni ekran
+ repository payload patch** noktalarında toplanır.

---

## 6. Sprint roadmap (Madde 9 detayı)

> **Pre-condition (Madde 8):** Sprint 1 başlatılmadan ÖNCE izole dev
> Supabase environment hazır olmalı. Production'a doğrudan apply yok.

| # | Sprint | Efor | Backend dokunur? | Branch önerisi |
|---|--------|------|------------------|----------------|
| 1 | Staff Dart bağlantısı + C2 apply (izole env) | M (~3-5 gün) | EVET (C2 apply izole env'de) | `feat/dealer-staff-foundation` |
| 2 | Draft transaction altyapısı | S (~2-3 gün) | EVET (yeni tablo `dealer_transaction_drafts`) | `feat/dealer-draft-tx` |
| 3 | Range UI bind (Phase 1 tüketicisi) | S (~1-2 gün) | HAYIR | `feat/dealer-range-report` |
| 4 | Settlement / gün sonu mutabakat | M (~2-3 gün) | EVET (yeni tablo `dealer_settlements`) | `feat/dealer-settlement` |
| 5 | Edit / Delete / Multi-item delivery + tarih seçici | M (~3-5 gün) | EVET (Postgres function multi-item) | 3 ayrı PR |

**Toplam:** ~3-4 hafta full-time tek dev. Monolitik değil, 5 sprint × 1-3 PR.

### 6.1 Sprint 1 detay — Staff Dart bağlantısı

Yapılacak:
- `activeOwnerContextProvider` (yeni)
- `StaffScopeDealerRepository` (yeni decorator katmanı, `GuardedDealerRepository` üzerinde)
- `SupabaseDealerRepository._ensureDefaultBakeryId` refactor (`effectiveOwnerId`)
- `_addDeliveryToSupabase` + `_addExtraToSupabase` payload'una `created_by`
- `DealerStaffRepository` (yeni, invite/accept/revoke RPC wrapper)
- `dealer_staff_management_screen.dart` (yeni, ticari için)
- `staff_owner_picker_screen.dart` (yeni, staff login sonrası)
- Context banner widget (bireysel için "Usta Fırın X adına işlem
  yapıyorsun")

C2 apply: izole dev env'de M1 → M2 → M2.5 → M3 sırasıyla + smoke script.

### 6.2 Sprint 2 detay — Draft transaction

Yapılacak:
- Migration: `dealer_transaction_drafts` (id, dealer_id, owner_id,
  created_by_staff_id, payload jsonb, status enum {draft, posted,
  discarded}, created_at, posted_at?)
- RLS: staff yazabilir/listeleyebilir kendi draft'larını, owner
  listeler+update edebilir
- `DraftDealerTransactionRepository` interface + Supabase impl
- `dealer_drafts_inbox_screen.dart` (owner için bekleyen taslaklar)
- Form ekranlarına "Taslak olarak kaydet" butonu (staff için varsayılan;
  owner için opsiyonel)
- Donor `stashed_orders.dart` paterni lift; **jsonb'de dual-id+name
  tutulur** (catalog rename silent drop bug'ını baştan çöz)

### 6.3 Sprint 3 detay — Range UI bind

Phase 1 commit `454d1cb`'de hazır:
- `DealerPeriod` (today/thisWeek/thisMonth/lastNDays/previousWeek/previousMonth)
- `DealerRangeMetrics` model
- `DealerBalanceService.summarizeRange()` method

Yapılacak:
- Yeni ekran: `dealer_range_report_screen.dart`
  - Üstte period chip row (Bugün / Bu hafta / Bu ay / Geçen hafta / Geçen ay / Özel)
  - Özel için date range picker
  - Body: KPI tiles (Teslim/İade/Tahsilat/Düzeltme + netChange + txCount)
  - "Bu aralık PDF" butonu → `DealerPdfBuilder.buildRange(...)` (yeni metod)
- Tüketici provider: `dealerRangeMetricsProvider((dealerId, period))`
- `DealerPulseCard` (dealer detail Hero altı, donor `GoalsCardView` EMA
  mantığı uyarlaması)

### 6.4 Sprint 4 detay — Settlement / gün sonu

Yapılacak:
- Migration: `dealer_settlements` (id, dealer_id, owner_id, closed_at,
  balance_at_close, cash_counted, diff, note, created_by)
- `DealerSettlementRepository` (yeni)
- `dealer_settlement_screen.dart` — donor `surplus_page` 4-kolon
  DataTable port (Unit / Sayım / Fark / Beklenen) + tap-row-to-edit
  dialog + Confirm → `dealer_settlements` row insert
- Dealer detail'e 5. action chip "Gün Sonu"
- `DealerPdfBuilder.buildSettlement(...)` (yeni metod)

**Donor'a göre fark:** donor `surplus()` yalnız drawer'ı default'a
resetler, hiç persistent close log yazmaz. FırınNet **her close'u
audit log olarak persist eder** (regulatory + dispute resolution).

### 6.5 Sprint 5 detay — Edit/Delete/Multi-item/Tarih

Bağımsız user-facing gap'ler, 3 ayrı PR:

**PR-A: Edit + Deactivate**
- `edit_dealer_screen.dart` (yeni; `repo.upsertDealer` zaten upsert)
- Dealer list satırda swipe-to-action → pasifleştir / sil
- (Donor `slide_to_delete.dart` paterni logic-lift)

**PR-B: Tarih seçici**
- 4 form ekranına `DateTimePicker` (createdAt user-controlled, default = now)
- "Dün/önceki gün için tx yazma" use case

**PR-C: Multi-item delivery** ⚠️ **Backend dokunur, kullanıcı onayı şart**
- Postgres function: `add_delivery_with_items(dealer_id, items jsonb[])`
- `dealer_delivery_form_screen` yenilensin:
  - Cart-benzeri transient state (line item list)
  - Tek save → multi-line `dealer_delivery_items` insert (atomic via function)

---

## 7. Operasyonel kurallar (her sprintte geçerli)

1. **Donor kod lift'i yapılan her dosyaya** Apache-2.0 header satırı:
   `// Adapted from evan361425/flutter-pos-system, Apache-2.0.
   See THIRD_PARTY_LICENSES.md.`
2. **Sprint 2'de** `THIRD_PARTY_LICENSES.md` (ilk gerçek code lift)
   eklenir; sonraki sprint'lerde lift gelirse aynı dosyaya entry eklenir.
3. **Migration apply yalnız izole dev Supabase env'de.** Production
   smoke geçmeden production'a apply YOK.
4. **`flutter analyze` temiz + `flutter test` tam pass** her sprint
   commit öncesi.
5. **Emulator smoke** UI değişen sprint'lerde gerekli (Sprint 1, 2, 3, 4, 5
   hepsi).
6. **Code review:** her sprint en az 1 PR, küçük + fokuslu (M sprint'leri
   2-3 PR'a bölünebilir).
7. **Hiçbir sprint donor'dan yeni dep import etmeyecek.** Yeni dep
   kararı ayrı tartışma.

---

## 8. Riskler

| Risk | Şiddet | Mitigasyon |
|------|--------|-----------|
| Sprint 1 izole dev env yok → apply riski | YÜKSEK | Madde 8 kuralı: env yoksa sprint başlamaz |
| `dealersOverviewProvider` perf çöküşü (50+ bayi × 50k tx) | YÜKSEK (büyüme) | Sprint 3 sırasında DB-side aggregate view ADR; apply ayrı sprint |
| Sprint 5-C multi-item için Postgres function | ORTA | En sona alındı; kullanıcı onayı şart |
| Realtime sync eksikliği (başka cihazdan tx görünmüyor) | ORTA | Supabase Realtime subscribe Sprint 1-2 sırasında eklenebilir |
| Donor `stashed_orders` catalog rename silent drop bug | DÜŞÜK | Sprint 2 tasarımında dual-id+name baştan çöz |
| Form ekranlarının optimistic update eksikliği (double-tap) | DÜŞÜK | Sprint 5-A'da butona loading state ekle (mevcut bug, lift değil) |

---

## 9. Karar geçmişi (audit trail)

- **2026-05-24** Bu plan oluşturuldu (bu doküman).
- **2026-05-24** Donor audit'i revize edildi — flutter-pos-system primary,
  RetailSale/SaleFlex concept-only, multi-role-flutter-auth + uber-clone
  license olmadığı için reddedildi.
- **2026-05-24** C1 fix commit `861bbee` push edildi origin/main — bireysel
  Bayi Defteri açık (Madde 4).
- **2026-05-24** Phase 1 metrics foundation commit `454d1cb` push edildi
  `feat/bayi-defteri-metrics-foundation` branch'ine — Sprint 3 için temel.
- **2026-05-24** C1 (`319981f`) yanlış ürün modeli olduğu için partial
  revert yapıldı.
- **2026-05-23** C1 (`319981f`) origin/main'e push edildi (yanlış model,
  ertesi gün düzeltildi).

---

## 10. Hatırlatma — bu doküman ne değildir

- **Sprint kabul tarihi içermez.** Tarihler kullanıcı kararıyla atanır.
- **Implementation detail değildir.** Her sprint kendi içinde tasarım
  kararları gerektirir (RPC imzaları, RLS koşulları, UI mockup vs.).
- **Bağlayıcı sözleşme değildir.** Ürün gerekleri değişirse plan revize
  edilir; bu doküman güncellenir (en az "Karar geçmişi"ne entry eklenir).
- **Kod değildir.** Hiçbir Dart/SQL satırı henüz yazılmadı. Hiçbir
  migration apply edilmedi. Hiçbir dependency eklenmedi.

---

**İlgili dokümanlar / commit'ler:**
- `lib/features/dealers/services/dealer_period.dart` (Phase 1, commit `454d1cb`)
- `lib/features/dealers/models/dealer_range_metrics.dart` (Phase 1, commit `454d1cb`)
- `lib/features/dealers/services/dealer_balance_service.dart` — `summarizeRange` method (Phase 1, commit `454d1cb`)
- `supabase/migrations/20260524200000_dealer_staff_v1.sql` (C2, untracked, apply bekliyor)
- `supabase/migrations/20260524200100_dealer_ledger_created_by.sql` (C2, untracked)
- `supabase/migrations/20260524200150_dealer_ledger_created_by_guards.sql` (C2, untracked)
- `supabase/migrations/20260524200200_dealer_ledger_rls_staff.sql` (C2, untracked)
- `scripts/admin/dealer_staff_v1_smoke.sql` (C2, untracked)
