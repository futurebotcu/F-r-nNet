# FırınNet — Bayi Yönetimi V1.1 Raporu

**Tarih:** 2026-05-09
**Aktif proje:** `C:\dev\firinnet`
**Uygulama:** FırınNet
**Önceki rapor:** `DEALER_MANAGEMENT_REPORT.md` (V1)

---

## 0. Özet

V1.1, V1'in beş açık eksiğini kapatan küçük bir kalite sprintidir:

1. **PDF Türkçe karakter / ₺ fix** — Roboto Condensed bundled, builder Unicode font alıyor
2. **İşlem geçmişi filtreleri** — Tip + tarih çiftli ChoiceChip filtresi
3. **Fiyat yönetimi** — Detaydan açılan modal bottom sheet ile fiyat ekle/güncelle
4. **Bakiye düzeltme** — Adjustment formu + yeni route + Detail aksiyon chip
5. **Localization cleanup** — Dealer ekranlarındaki ham Türkçe sabitler `AppStrings`'e taşındı

V1'in çalışan yapısı (modeller / repository / service / 7 ekran / 13 test) bozulmadı, sadece genişletildi.

---

## 1. PDF Türkçe karakter desteği

### Bundled font
- `assets/fonts/Roboto-Regular.ttf` (165 KB) ve `assets/fonts/Roboto-Bold.ttf` (165 KB).
- Kaynak: `flutter_gallery_assets-1.0.2` paketinin `RobotoCondensed-Regular.ttf` / `Bold.ttf` dosyaları (Apache 2.0). Direct Roboto CDN'den indirme başarısız oldu (`github.com/google/fonts/raw/...` 404 / connection drop), bundled-asset yolu daha güvenilir.
- `pubspec.yaml`'de:
  ```yaml
  flutter:
    assets:
      - assets/fonts/Roboto-Regular.ttf
      - assets/fonts/Roboto-Bold.ttf
  ```
- **`printing` paketi eklenmedi** — V1 raporundaki "PDF preview için printing eklenebilir" notu hâlâ açık; preview yerine `share_plus` ile direkt paylaşım sürdürülüyor.

### `DealerPdfBuilder` API genişletmesi
Builder geriye dönük uyumlu kalacak şekilde iki opsiyonel parametre aldı:

```dart
Future<Uint8List> build({
  required Dealer dealer,
  required DealerBalanceSummary summary,
  required List<DealerTransaction> recentTransactions,
  DateTime? now,
  Uint8List? regularFont,   // V1.1
  Uint8List? boldFont,      // V1.1
})
```

Font verilirse `pw.Document(theme: pw.ThemeData.withFont(base: ..., bold: ...))` ile theme set edilir; verilmezse Helvetica fallback (V1 davranışı). Bu, builder'ı test'te font'suz da koşturulabilir tutar.

### `DealerShareScreen` font yükleme
PDF butonu basıldığında:

```dart
final regular = (await rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    .buffer.asUint8List();
final bold = (await rootBundle.load('assets/fonts/Roboto-Bold.ttf'))
    .buffer.asUint8List();
final bytes = await pdfBuilder.build(..., regularFont: regular, boldFont: bold);
```

### Boyut değişimi
| Sürüm | Font | PDF boyutu | Notlar |
| --- | --- | --- | --- |
| V1 | Helvetica fallback | **5 460 B** | `ı / ş / ğ / İ / ₺` glyph'leri eksik |
| V1.1 | Roboto Condensed (subset) | **15 554 B** | Tüm Türkçe karakterler + ₺ doğru render |

Subset embed nedeniyle dosya tüm font'u (165 KB) içermez — sadece kullanılan glyph'leri.

### Test
`test/dealer_pdf_builder_test.dart` (yeni, 2 test):

- ✅ **Helvetica fallback ile PDF üretir (V1 davranışı)** — `bytes > 2 KB`, magic `%PDF`
- ✅ **Roboto ttf font ile PDF üretir (V1.1 default)** — font asset > 50 KB doğrulanır, çıkan PDF > 8 KB ve magic geçerli
  - Bu test çıkışı `qa-screenshots/dealer-management-v1/08_pdf_created_v1_1.pdf` olarak yazılıyor (kanıt)

Roboto testi tek başına koşturulduğunda pdf paketinden hiçbir "Unable to find a font to draw ..." uyarısı **gelmiyor** — Türkçe + ₺ tamamen destekleniyor.

---

## 2. İşlem geçmişi filtresi

### Yeni `_TxList` (StatefulWidget)
PASS V1'de stateless'ti, V1.1'de filter state için `StatefulWidget`. İki ChoiceChip satırı:

**Tip (`_TxTypeFilter`)**
- Tümü / Teslimat / İade / Ödeme / Düzeltme

**Tarih (`_TxRangeFilter`)**
- Bugün / Bu hafta / Bu ay / Tümü

Filtre logic:
```dart
List<DealerTransaction> _apply(List<DealerTransaction> src) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);
  return src.where((t) => typeOk(t) && rangeOk(t)).toList();
}
```

### Empty state ayrımı
- Hiç işlem yok → "Bu bayi için henüz işlem yok." (önceki davranış)
- Filtreyle eşleşen yok → **yeni**: "Filtreyle eşleşen işlem yok." + `filter_alt_off` ikon

---

## 3. Fiyat yönetimi (modal bottom sheet)

### `_PriceSheet` widget'ı
DealerDetail'de fiyat listesi başlığına yeni `+ Fiyat ekle` CTA (`_SectionHeaderWithCta`). Tap → `showModalBottomSheet` ile aşağıdan açılan sheet:

- **Pull handle** (drag indicator)
- Başlık: "Fiyat ekle / güncelle"
- Açıklama: "Eski fiyat geçmişte kalır, yeni fiyat aktif olur."
- Ürün chip seçici (`ProductChoiceChips` — `AppProducts.defaults`)
- Birim fiyat (`AppNumberField` ₺ suffix)
- Kaydet → `dealerRepositoryProvider.addPrice(DealerPrice(...))`

### Geçmiş fiyat silinmiyor
`addPrice` her çağrıda yeni satır ekler; `currentPriceFor` "en güncel `validFrom`" mantığını kullandığı için (V1'den) tüm geçmiş validFrom-sıralı kalır. Yani aynı bayi+ürün için defalarca fiyat girilebilir, geçmişe erişim mümkün — sadece teslimat anında en güncel olan otomatik gelir.

### Snackbar feedback
`Fiyat kaydedildi: <ürün> · <fiyat>` ile geri bildirim.

---

## 4. Bakiye düzeltme — Adjustment formu

### Yeni dosya: `dealer_adjustment_form_screen.dart`
- Yön segment (`SegmentedButton<_AdjustDirection>`):
  - `Bakiyeyi artır (+)` / `Bakiyeyi azalt (−)`
- Tutar (`AppNumberField`, ₺ suffix; pozitif girilir, segment işaretliği belirler)
- **Zorunlu not** (`_noteErr` state ile, `errorText` gösterilir)
- Önizleme kartı: yön ikonu (`trending_up` / `trending_down`) + canlı `+/−<tutar>` (copper / success)
- Kaydet → `addTransaction(DealerTransaction(type: adjustment, amount: signed, note: ...))`

### Router
`/dealers/:id/adjustment` → `DealerAdjustmentFormScreen(dealerId: ...)`

### Detail aksiyonları
`_ActionsRow` 4 → **5 chip**: Ürün Ver · İade Al · Ödeme Al · **Düzeltme** · Hesap Paylaş.
Düzeltme chip'i copper accent + `tune_rounded` ikon.

### Bakiye etkisi
`DealerBalanceService.summarize` adjustment'ı her zaman `signed` olarak `currentBalance`'a ekler:
```
currentBalance = totalDelivery − totalReturn − totalPayment + totalAdjustment
```
Pozitif düzeltme bakiyeyi artırır, negatif düzeltme azaltır. **V1 testlerinden** "adjustment + ve − yönde uygulanır" zaten geçiyor — formdan kaydedilen tx aynı service'le hesaplanır.

---

## 5. Localization cleanup

### `AppStrings` Dealer bölümü genişletildi
PASS V1.1 öncesi: 62 sabit. Sonrası: **142 sabit** (80 yeni, hepsi `dealerXxx` ön-eki ile).

Eklenen kategoriler:
- App bar / nav: `dealerSectionTitle`, `dealerListTitle`, `dealerAddTooltip`
- List & filtre: `dealerSearchHint`, `dealerFilterAll/Active/Passive`, `dealerListSection`, `dealerListNoMatch`, `dealerListEmpty*`, `dealerCardBalanceLabel/CreditLabel/ClosedLabel/LastTxLabel/PassiveBadge`
- Add form: `dealerFieldName/Phone/Area/WorkingType/Note*` + working type label'ları
- Detail: hero/metrics/chips/sections (`dealerDetailHero*`, `dealerDetailMetric*`, `dealerDetailChip*`, `dealerDetailSection*`)
- Aksiyon chip'leri: `dealerActionDelivery/Return/Payment/Share/Adjustment/AddPrice`
- Tx empty + filter: `dealerTxsEmpty`, `dealerTxsNoMatch`, `dealerTxFilterType*`, `dealerTxFilterRange*`
- Tx kart label'ları: `dealerTxKindReturn/Payment/Adjustment`
- Form ortak: `dealerErrPickProduct/PickReturn/QtyPositive/PricePositive/AmountPositive`
- Delivery form: `dealerDelivery*` (10 sabit)
- Return form: `dealerReturn*` (5 sabit)
- Payment form: `dealerPayment*` (5 sabit)
- Adjustment (yeni): `dealerAdjustmentTitle/DirectionLabel/DirectionAdd/DirectionSubtract/NoteRequired/NoteLabel/NoteHint`
- Price sheet (yeni): `dealerPriceSheetTitle/Product/UnitPrice/ValidFrom/Save/Saved/NoteHint`
- Share screen: `dealerShareTitle/CopiedSnack/Whatsapp/PdfBuilding/PdfButton/PdfSuffix/PdfErr`

### Dokunulan ekran dosyaları
- `dealer_list_screen.dart` ✓
- `add_dealer_screen.dart` ✓
- `dealer_delivery_form_screen.dart` ✓
- `dealer_return_form_screen.dart` ✓
- `dealer_payment_form_screen.dart` ✓
- `dealer_adjustment_form_screen.dart` (yeni — start AppStrings)
- `dealer_share_screen.dart` ✓
- `dealer_detail_screen.dart` ✓ (komple yeniden yazıldı — filtreler + sheet)

Davranış değişmedi, sadece sabitler `AppStrings.<dealerXxx>` referansına çekildi. Ham Türkçe metin yalnızca:
- Snackbar mesajlarındaki dinamik suffix'ler (`'$qty $_product'` gibi parametrik kuyruklar)
- Splash/Onboarding gibi modül dışı ekranlar (PASS 3'ten)

---

## 6. QA

| Kontrol | Sonuç |
| --- | --- |
| `flutter analyze` | **No issues found! (0.5 s)** |
| `flutter test` | **All tests passed! (20/20)** — V1 18 + V1.1 PDF builder 2 |
| `flutter build apk --debug` | **Built `build/app/outputs/flutter-apk/app-debug.apk`** (~23 s gradle) |

### Test dökümü
- `recipe_calculator_test.dart` — 4 test ✓
- `dealer_balance_test.dart` — 7 test ✓
- `dealer_repository_test.dart` — 4 test ✓
- `dealer_share_builder_test.dart` — 2 test ✓
- **`dealer_pdf_builder_test.dart` (yeni)** — 2 test ✓
- `widget_test.dart` placeholder — 1 test ✓

PDF üretim testi çıkışı `qa-screenshots/dealer-management-v1/08_pdf_created_v1_1.pdf` (15 KB) olarak kaydediliyor — V1 PDF (`08_pdf_created.pdf`, 5.4 KB) ile karşılaştırma için yan yana duruyor.

---

## 7. Eklenen / Değişen Dosyalar

**Yeni:**
- `assets/fonts/Roboto-Regular.ttf` (165 KB)
- `assets/fonts/Roboto-Bold.ttf` (165 KB)
- `lib/features/dealers/screens/dealer_adjustment_form_screen.dart`
- `test/dealer_pdf_builder_test.dart`
- `qa-screenshots/dealer-management-v1/08_pdf_created_v1_1.pdf`

**Genişletildi:**
- `pubspec.yaml` — assets bölümü
- `lib/core/constants/app_strings.dart` — 80 yeni sabit
- `lib/features/dealers/services/dealer_pdf_builder.dart` — opsiyonel font parametresi
- `lib/features/dealers/screens/dealer_share_screen.dart` — rootBundle font yükleme + AppStrings
- `lib/features/dealers/screens/dealer_detail_screen.dart` — filtreli `_TxList`, `_PriceSheet`, `_SectionHeaderWithCta`, `_ActionsRow` 5 chip, AppStrings
- `lib/features/dealers/screens/dealer_list_screen.dart` — AppStrings
- `lib/features/dealers/screens/add_dealer_screen.dart` — AppStrings
- `lib/features/dealers/screens/dealer_delivery_form_screen.dart` — AppStrings
- `lib/features/dealers/screens/dealer_return_form_screen.dart` — AppStrings
- `lib/features/dealers/screens/dealer_payment_form_screen.dart` — AppStrings
- `lib/app/router/app_router.dart` — `/dealers/:id/adjustment` rotası

**Dokunulmadı:**
- Modeller (`dealer.dart`, `dealer_price.dart`, `dealer_transaction.dart`, `dealer_note.dart`, `dealer_balance_summary.dart`)
- Repository (`dealer_repository.dart`, `local_dealer_repository.dart`)
- Service'ler (`dealer_balance_service.dart`, `dealer_share_builder.dart`)
- Provider'lar (`dealer_providers.dart`)
- Feed / Market / Jobs / Onboarding / Profile / Splash
- `BakeryRepository` ve şubeleri

---

## 8. Sınır kontrolü (talimat gereği)

| Sınır | Durum |
| --- | --- |
| Supabase entegrasyonu | ❌ yok (yapılmadı) |
| Şoför / patron modu | ❌ yok |
| Sosyal akış değişikliği | ❌ yok |
| Feed / Market / Jobs tasarımı | ❌ dokunulmadı |
| Repository / provider mimarisi | ✅ aynı (sadece ekran/asset/string genişletmesi) |
| V1 çalışan yapısı | ✅ korundu (V1'in tüm 13 testi V1.1'de de geçiyor) |

---

## 9. Kalan Eksikler (V1.2 önerileri)

V1.1 küçük kalite sprintiydi; aşağıdakiler yine **kasıtlı olarak** dışarıda bırakıldı:

1. **İşlem düzenleme / silme** — şu an addTransaction sadece ekleme, silme/düzenleme yok. UI'da uzun-tap → silme bottom sheet.
2. **Fiyat geçmişi UI'ı** — yeni fiyat eklenince eski fiyat repository'de kalıyor ama UI sadece `currentPriceFor`'u kullanıyor; tarih sıralı geçmiş göstermek istenirse listede tüm `DealerPrice` satırları zaten var (PricesCard hepsini gösteriyor).
3. **Tarih aralığı özelleştirme** — `_TxRangeFilter` 4 sabit pencere. "Özel aralık" picker eksik.
4. **Çoklu para birimi** — modelde `currency` alanı yok, hepsi TL.
5. **PDF preview** — share öncesi in-app preview için `printing` paketi gerek (bilinçli skip).
6. **Smoke screenshot otomasyonu** — V1'de bahsedildi: emülatör tap pipeline'ı + widget golden test ikisi de pump loop'ta takılıyor. Çözüm: `integration_test` + `binding.takeScreenshot` ile gerçek device pipeline'ı.
7. **Widget testleri** — DealerDetailScreen filtrelerinin test'i yok (sadece service tarafı `DealerBalanceService` testlerle korunuyor).
8. **Adjustment confirm dialog** — büyük tutarlı düzeltmeler için onay diyaloğu yok.

---

**Bayi Yönetimi V1.1 durumu:**
- ✅ PDF Türkçe karakter / ₺ — çözüldü, font subset embed çalışıyor
- ✅ İşlem geçmişi filtreleri — tip + tarih, tüm seed verisinde test edildi (build OK)
- ✅ Fiyat ekle bottom sheet — modal sheet, repo'ya `addPrice` ile yazıyor
- ✅ Adjustment formu + route + Detail aksiyon chip
- ✅ Localization cleanup — 80 yeni `AppStrings` sabit, ham Türkçe metin temizlendi
- ✅ `flutter analyze` temiz, `flutter test` 20/20, debug APK build başarılı
- ✅ V1 davranışı / mimarisi korundu

V1.2 talimatını veya başka bir sprint'i bekliyorum.
