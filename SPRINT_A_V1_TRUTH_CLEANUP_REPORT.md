# Sprint A — V1 "Yalan Temizliği" Raporu

**Tarih:** 2026-05-16
**Branch:** `main`
**Tip:** Sadece UI/kod. DB migration yok, storage bucket yok, yeni dependency yok, release AAB yok.

---

## 1. Removed fake feed image placeholder

`lib/core/widgets/premium/feed_post_card.dart`:
- `5/4 AspectRatio` + `LinearGradient` arka planı + "Görsel yüklenmedi" overlay'i (Icons.photo_outlined + 11px etiket) tamamen kaldırıldı.
- `final List<Color>? imageGradient;` field + constructor param'ı kaldırıldı.
- Kart artık yazar satırı → içerik → etiketler → etkileşim satırı sırasıyla **sahte görsel slot'u olmadan** render olur.

`lib/features/feed/screens/feed_screen.dart`:
- `_PostCardWired.build` içindeki `imageGradient: post.gradient` callsite'ı kaldırıldı.

Model `FeedPost.gradient` field'ı dokunulmadı — repository hala üretebilir (ölü ama zararsız). Sprint B'de gerçek `media_urls`/`feed_post_media` geldiğinde bu kavram refactor edilir.

## 2. Removed fake story/anlık strip

`lib/features/feed/screens/feed_screen.dart`:
- `static const _stories = <_Story>[...]` 9 hardcoded sahte kullanıcı listesi silindi.
- `_Story` private model class silindi.
- `_StoryStrip` widget class silindi.
- `_StoryAvatar` widget class silindi.
- Build sliver listesinden `SectionLabel(title: feedSectionStories)` + `_StoryStrip` ikilisi kaldırıldı. Feed artık header → groups carousel → composer → posts sırasıyla görünür.

`lib/core/constants/app_strings.dart`:
- `static const String feedSectionStories = 'Atölyeden anlık';` kaldırıldı (lib altında başka kullanım yok).

Storage/migration eklenmedi. Gerçek story sistemi Sprint C'ye (veya V2'ye) ertelendi.

## 3. Product "Diğer" free-text behavior

`lib/core/widgets/product_choice_chips.dart`:
- StatelessWidget → StatefulWidget'a çevrildi.
- Predefined `AppProducts.defaults` chip'lerinin sonuna "Diğer" chip'i eklendi.
- "Diğer" tıklanınca altında inline `TextField` (`labelText: "Ürün adı"`, `hintText: "Örn. Tahinli, Kurabiye"`) açılır.
- Her keystroke `onSelected(value.trim())` çağırır. Boş ise boş string döner → caller boş-guard'ına takılır.
- `didUpdateWidget` ile external `selected` predefined dışı bir değerse "Diğer" modu otomatik aktifleşir + TextField doldurulur.
- DB değişikliği YOK — `dealer_prices.product_name` zaten `TEXT` (FK değil).

Form-side guard güçlendirildi — boş ürün adı kaydı engellenir:

| Dosya | Önce | Sonra |
|---|---|---|
| `dealer_detail_screen.dart` `_PriceSheet._save` | `if (_product == null)` | `final productName = _product?.trim() ?? ''; if (productName.isEmpty)` |
| `dealer_delivery_form_screen.dart` `_save` | aynı | aynı pattern |
| `dealer_return_form_screen.dart` `_save` | aynı | aynı pattern |
| `production_entry_screen.dart` `_save` | aynı | aynı pattern |
| `waste_entry_screen.dart` `_save` | aynı | aynı pattern |

Hata mesajları (Turkish) korundu: `dealerErrPickProduct`, `dealerErrPickReturn`, `'Önce bir ürün seç.'`. `productName` lokal var DealerTransaction/DealerPrice/ProductionEntry/WasteEntry'lerin `product*` alanlarına ve SnackBar interpolation'larına geçirildi.

## 4. Locale cleanup

`lib/app/app.dart`:
- `supportedLocales`'tan `Locale('en', 'US')` kaydı kaldırıldı. Liste artık `[Locale('tr', 'TR')]`.
- `MaterialApp.locale` zaten `tr_TR`'a hardcoded; OS sisteminde EN dilini kullanan kullanıcı için Material widget'ları ile uygulama metni arasındaki tutarsızlık riski silindi.
- `initializeDateFormatting('tr_TR')` `main.dart`'ta zaten vardı; dokunulmadı.

V1 Türkçe-only kalır. Settings dil seçeneği zaten yok (kullanıcıya görünür değil) — değişiklik yapılmadı.

## 5. Files changed

```
lib/app/app.dart
lib/core/constants/app_strings.dart
lib/core/widgets/premium/feed_post_card.dart
lib/core/widgets/product_choice_chips.dart
lib/features/bakery_panel/screens/production_entry_screen.dart
lib/features/bakery_panel/screens/waste_entry_screen.dart
lib/features/dealers/screens/dealer_delivery_form_screen.dart
lib/features/dealers/screens/dealer_detail_screen.dart
lib/features/dealers/screens/dealer_return_form_screen.dart
lib/features/feed/screens/feed_screen.dart
```

Yeni dosya eklenmedi (rapor hariç). Migration / pubspec / AndroidManifest / iOS plist hiçbiri değişmedi.

## 6. Tests

- `flutter analyze --no-pub`: **No issues found**
- `flutter test --no-pub`: **254/254 passed** (Sprint A öncesi 254 testten regression yok)
- Grep doğrulaması:
  - `Görsel yüklenmedi`, `_StoryStrip`, `_StoryAvatar`, `feedSectionStories`, `Locale('en'`: hepsi temiz.
  - `jobsApplyComingSoon`: yalnız mevcut regression test'inde ("artık snackbar göstermiyor" doğrulaması) — Sprint A kapsamında değil, kasıtlı bırakıldı.
  - `_noop`: feed_screen.dart:63 yorum satırında (commit `970de7f`'in açıklayıcı yorumu). Kod değil.
  - `service_role` / `SUPABASE_SERVICE_ROLE`: sadece `scripts/admin/*.ps1` (env-driven admin smoke scripts) ve `supabase/functions/delete-account/index.ts` (Edge function, server-side only). Mobile/Flutter kodda yok.
  - `eyJ[A-Za-z0-9_-]{20,}` (JWT pattern): repo'da hardcoded yok.

## 7. Remaining Sprint B items

Sprint A bu PR'da bitti. Sprint B (P1) eldeki sıradaki paketler:

1. **Feed image attachment (gerçek)**
   - Migration: `feed_post_media (id, post_id, owner_id, kind, url, width, height, ordering, created_at)` + RLS owner-only insert/delete, authenticated select.
   - Storage bucket `feed-media` + upload path zorunluluğu `<auth.uid()>/<post_id>/<uuid>` + MIME whitelist + size limit.
   - pubspec: `image_picker`, `permission_handler`.
   - AndroidManifest: `READ_MEDIA_IMAGES` (Android 13+) + `READ_EXTERNAL_STORAGE` (legacy).
   - iOS Info.plist: `NSPhotoLibraryUsageDescription`.
   - FeedComposer: "+ Fotoğraf" butonu → picker → upload → post insert. Upload fail → post atılmaz.
   - FeedPostCard: media row varsa `Image.network` (AspectRatio + fit + error fallback). Sprint A'da kaldırılan slot artık gerçek görsel ile yeniden hayata gelir.
   - `FeedPost.gradient` ölü field'ı bu noktada temizlenir.

2. **`bakery_products` CRUD UI**
   - Repo + Provider + `/panel/products` (veya Panel kartı) listele/ekle/sil ekranı.
   - Mevcut form chip listesi `AppProducts.defaults ∪ userBakeryProducts` union'u olur.
   - "Diğer" affordance'ı (Sprint A) `bakery_products`'a kayıt eden bir CTA ile genişletilebilir.

3. **Video attachment, kamera capture, story, follow** → Sprint C parça parça.

## 8. Things not done (Sprint A scope kuralı)

- DB migration uygulanmadı.
- Yeni Storage bucket veya policy eklenmedi.
- Yeni dependency eklenmedi (pubspec.yaml dokunulmadı).
- AndroidManifest izinleri değişmedi.
- iOS plist dokunulmadı.
- `FeedPost.gradient` field'ı silinmedi (ölü ama zararsız; Sprint B'de media migration sırasında temizlenir).
- Release keystore, AAB, ImagePicker / camera / video_player dependency'leri eklenmedi.
- `service_role` kullanılmadı.
- Fatih hesabına dokunulmadı.
- `.env.local` değerleri yazdırılmadı.
- Commit'lendi ama **push edilmedi**.

## 9. Manual smoke checklist

Push öncesi cihazda doğrulama önerilen:
- Feed scroll: header → groups carousel → composer → posts. Anlık şeridi YOK. Post kartlarında sahte görsel slot'u YOK.
- Dealer detail → "Fiyat ekle" sheet → predefined chip + "Diğer" + free-text. Boş text → "Önce bir ürün seç" snackbar'ı.
- Dealer delivery form → "Diğer" ile özel ürün → kayıt başarılı, snackbar custom ürün adıyla.
- Dealer return form → aynı.
- Production entry, Waste entry → aynı.
- Sistem dili EN olan cihazda app açılışında Material widget metinleri Türkçe gelir (en_US ölü kaldırıldı; `tr_TR` zorlanır).
