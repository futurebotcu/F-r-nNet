# Rol Bazlı Panel Güncellemesi — Rapor

**Tarih:** 2026-05-12
**Kapsam:** Profil katmanına `wholesaler` ekleme, Panel tab'ını role göre kartlandırma, app adı standardizasyonu.

---

## 1. Mevcut Yapı Özeti

FırınNet — Flutter 3.9+, Riverpod 2.6, GoRouter 14.8, Material 3 koyu premium tema.

Önceki durumda Panel tab'ı (`/panel`) doğrudan `BakeryPanelScreen`'i gösteriyordu. Profil modelinde sadece iki hesap türü (`commercial`, `individual`) vardı, üçüncü rol için yer yoktu. Bayi yönetimi `/dealers` altında zaten tam çalışır durumdaydı, sadece Panel tab'ı içinden bir dispatch yoktu.

Ortak akış (Feed / Gruplar / Market / İlanlar) bottom nav'da herkes için aynı.

---

## 2. Değişen / Eklenen Dosyalar

| Dosya | Tür | Ne değişti |
|---|---|---|
| `lib/features/profile/models/bakery_profile.dart` | Edit | `AccountType` enum'una `wholesaler` eklendi + `label` extension'ı |
| `lib/core/constants/app_strings.dart` | Edit | `accountWholesaler` + role-bazlı kart etiketleri (~20 yeni sabit) |
| `lib/features/profile/screens/create_profile_screen.dart` | Edit | `SegmentedButton` yerine 3 kart `_AccountTypePicker` |
| `lib/features/profile/screens/profile_screen.dart` | Edit | Hesap etiketi `accountType.label` üzerinden (3 değer destekli) |
| `lib/features/dashboard/services/role_panel_cards.dart` | **Yeni** | Rol → 4 kart eşlemesi (`PanelCard` model + `RolePanelCards` servisi) |
| `lib/features/dashboard/screens/role_dashboard_screen.dart` | **Yeni** | Panel tab'ının yeni kök ekranı; profilden role bakar, kart listesi render eder |
| `lib/app/router/app_router.dart` | Edit | `/panel` → `RoleDashboardScreen`, yeni `/panel/bakery` → `BakeryPanelScreen` |
| `android/app/src/main/AndroidManifest.xml` | Edit | `android:label` `firin_defter` → `FırınNet` |
| `ios/Runner/Info.plist` | Edit | `CFBundleDisplayName` `Firin Defter` → `FırınNet` |

**Toplam:** 7 dosya düzenlendi, 2 dosya eklendi. Hiçbir mevcut ekran (BakeryPanel, Dealers, Feed, Jobs, Market, Groups) iç mantığında değişmedi.

---

## 3. Eklenen Enum / Model / Servis Yapısı

### `AccountType` enum (genişletildi)
```dart
enum AccountType { commercial, individual, wholesaler }

extension AccountTypeLabel on AccountType {
  String get label; // 'Ticari' / 'Bireysel' / 'Toptancı'
}
```
- `wholesaler` eklendi. `BakeryProfile.guest` hâlâ `individual` (geriye dönük).
- `label` getter'ı sayesinde profil/dashboard'da ternary if/else kalmadı.

### `PanelCard` modeli (yeni)
```dart
class PanelCard {
  final String label;
  final String subtitle;
  final IconData icon;
  final String? route;        // null ise comingSoon=true
  final bool comingSoon;
}
```

### `RolePanelCards` servisi (yeni)
- `forAccount(AccountType)` → 4 elemanlı `List<PanelCard>` döner.
- `subtitleFor(AccountType)` → header subtitle string'i.
- Rol-eylem mapping'i tek bir yerde — UI bunu sadece render eder.

### `RoleBadges` (mevcut, dokunulmadı)
Meslek rozeti listesi `lib/core/constants/app_products.dart` altında zaten doğru sırayla ve istenen 10 değerle var: Usta Fırıncı, Fırın Sahibi, Uncu, Mayacı, Susamcı, Toptancı, Pastacı, Ekipman Satıcısı, Çalışan/Usta, Diğer.

---

## 4. Rol Bazlı Dashboard Mantığı

`/panel` route'u artık `RoleDashboardScreen`. Ekran:
1. `profileControllerProvider`'dan profili izler (profil yoksa `AccountType.individual` varsayar — guest deneyimi bozulmaz).
2. `RolePanelCards.forAccount(role)` ile 4 kart alır.
3. İlk kart `featured`, diğerleri normal — mevcut `QuickActionTile` widget'ı kullanıldı (yeni tasarım sistemi yok).
4. Kart tıklamasında `card.route` doluysa nav yapılır:
   - Ana tab'lara (`/jobs`, `/market`, `/feed`, `/groups`) `context.go(..)` ile geçiş (alt tab değişir).
   - Diğer ekranlara (`/dealers`, `/panel/bakery`, `/profile`) `context.push(..)` ile derinleşme.
5. `card.comingSoon == true` olan kartlar SnackBar ile "Yakında aktif olacak" gösterir; ileride placeholder ekrana veya gerçek feature'a bağlanır.

### Rol → Kart eşlemesi

**Ticari** (`commercial`)
| # | Kart | Hedef |
|---|---|---|
| 1 | Fırın Paneli | `/panel/bakery` → mevcut `BakeryPanelScreen` |
| 2 | Bayi Paneli | `/dealers` → mevcut `DealerListScreen` |
| 3 | İlanlarım | `/jobs` → mevcut `JobsScreen` |
| 4 | Mesajlar | _Yakında_ (SnackBar) |

**Bireysel** (`individual`)
| # | Kart | Hedef |
|---|---|---|
| 1 | İş İlanları | `/jobs` |
| 2 | İş Arıyorum İlanı Ver | _Yakında_ |
| 3 | Mesajlar | _Yakında_ |
| 4 | Profilim | `/profile` |

**Toptancı** (`wholesaler`)
| # | Kart | Hedef |
|---|---|---|
| 1 | Ürün/Hizmet İlanı Ver | `/market` |
| 2 | Gelen Mesajlar | _Yakında_ |
| 3 | Firma Profilim | `/profile` |
| 4 | Duyuru/Fiyat Listesi | _Yakında_ |

Tüm rollerde ortak akış (Feed / Gruplar / Market / İlanlar) bottom nav'da değişmeden korundu. Profil ekranı Feed header avatar veya `/profile` push'u üzerinden erişilebilir (mevcut davranış).

---

## 5. Supabase'e İleride Nasıl Bağlanacak

Tasarım, ileri taşımayı kolaylaştırmak için bilinçli olarak şu şekilde yapıldı:

1. **`AccountType` enum değerleri (`commercial`/`individual`/`wholesaler`)** Supabase profiles tablosundaki `account_type text` sütununa doğrudan map'lenebilir; ad-değer ilişkisi hâlâ koruma altında.
2. **`ProfileController`** zaten StateNotifier; içerideki `save()` / `clear()` metodlarının gövdesi şu an in-memory. Supabase eklendiğinde:
   - `save(profile)` → `supabase.from('profiles').upsert(profile.toJson()).then((_) => state = profile)`.
   - `useGuest()` → anonim oturum aç.
   - Splash başlangıcında `supabase.auth.currentSession` kontrolü ile state hidrasyonu.
3. **`RolePanelCards.forAccount()`** kart-eylem mapping'i kod içinde sabit; istenirse Supabase'de `panel_layouts(account_type, cards jsonb)` tablosuna taşınabilir ve `getPanelCards(accountType)` adında bir `FutureProvider` ile beslenebilir.
4. **`comingSoon == true` kartları** (Mesajlar, İş Arıyorum İlanı Ver, Duyuru/Fiyat Listesi) feature flag mantığıyla server-side aktive edilecek noktalar — şu an SnackBar gösteriyor.
5. **`BakeryProfile.copyWith`** zaten mevcut, JSON serileştirme eklenecekse `toJson()` / `fromJson()` factory'leri tek dosyaya eklenecek (model temiz duruyor).

Hiçbir yere hardcoded mock data koyulmadı, hiçbir build/runtime'da Supabase SDK aranmıyor — geçiş bağımlılıksız.

---

## 6. App Adı Standartlaşması

- `MaterialApp.title`: zaten `FırınNet` (değiştirilmedi).
- `AppStrings.appName`: zaten `FırınNet` (değiştirilmedi).
- `AndroidManifest.xml` `android:label`: `firin_defter` → `FırınNet`.
- `ios/Runner/Info.plist` `CFBundleDisplayName`: `Firin Defter` → `FırınNet`.
- `pubspec.yaml` `name: firin_defter` → **bilinçli olarak dokunulmadı** (Dart paket adı; değişimi tüm modül resolution'ı etkiler, riskli ve gereksiz). Açıklama satırı zaten "FırınNet - …" diye başlıyor.
- iOS `CFBundleName` `firin_defter` → **bırakıldı** (internal bundle identifier; display name değişimi yeterli).

---

## 7. Kontroller — `flutter analyze` & `flutter test`

```
$ flutter analyze --no-fatal-infos
Analyzing firinnet...
No issues found! (ran in 0.5s)

$ flutter test
00:00 +42: All tests passed!
```

42 testin tamamı geçti. Analyzer'da uyarı/info yok. Hiçbir test dosyası değiştirilmedi.

---

## 8. Riskler / Sonraki Adımlar

### Riskler
- **`/panel/bakery` route'u yeni** — eski `/panel` ile derin link açan dış bağlantılar (varsa) Fırın Paneli'ne değil dashboard'a düşer. Şu an proje içinde `AppRoutes.panel` referansı sadece app_shell ve router'da; dış kullanım yok.
- **Profil yoksa default `individual`** — bu davranış `BakeryProfile.guest` ile zaten tutarlı, ama ürün kararıdır: bir kullanıcı profil oluşturmadan Panel tab'ına girdiğinde Bireysel kartları görüyor. İstenirse RoleDashboardScreen'de profil yokken bir "Profil Oluştur" CTA banner'ı genişletilebilir (şu an küçük chip var).
- **SnackBar placeholder'lar** — Mesajlar, İş Arıyorum, Duyuru/Fiyat Listesi kartları henüz çalışmıyor; kullanıcı eğitiminde "yakında" ile karşılaşacak. İlk Mesajlaşma feature'ı eklenince `comingSoon: false` + `route` set etmek yeterli.
- **CFBundleName & pubspec name** hâlâ `firin_defter` — store yayını için bu identifier'lar değişirse build/listing migration gerekir. Yayın yaklaşırken planlı rebrand sprint'i açılmalı.

### Sonraki adımlar (öneri)
1. **Mesajlaşma feature'ı** (rollerin 3'ünde de Panel'de var) — Supabase realtime ile en doğal sonraki adım.
2. **"İş Arıyorum İlanı Ver"** — `JobsScreen`'in zaten "İş Arıyor" segmenti var; o segmente derin link + composer ekleme küçük bir iş.
3. **Toptancı "Duyuru/Fiyat Listesi"** — `Market` altında ayrı bir sekme/segment olarak basit bir CRUD ekran.
4. **`BakeryProfile.toJson/fromJson`** — Supabase eklenmeden önce serialization layer'ı eklenmeli (kullanıcı çıkışta state kaybediyor şu an).
5. **`pubspec.yaml` name yeniden adlandırma** — store yayını öncesi tek seferlik teknik debt.

---

**Not:** Bu güncelleme, Supabase / Firebase / gerçek auth eklenmeden tamamlandı. Üç rolün de panel deneyimi local-first, in-memory profil üzerinden çalışıyor.
