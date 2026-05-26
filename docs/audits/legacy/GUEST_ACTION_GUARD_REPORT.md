# GUEST_ACTION_GUARD_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.3.1 — Guest write action gating + Profile create escape hatch
**Test:** `flutter analyze` temiz, `flutter test` **122/122** yeşil (116 mevcut + 6 yeni)

---

## 1. Guest kullanıcı ne yapabilir?

**Gezme + okuma:** Hiçbir Supabase write yapmayan akışlar açıktır.

| Akış | Erişim | Not |
|---|---|---|
| Feed gezme + post okuma | ✅ | LocalFeedRepository seed |
| Public reçete okuma | ✅ | Profil sayfasındaki "Açık Reçeteler" RLS okur |
| Reçete listesi + detay görüntüleme | ✅ | Sahip yoksa boş; başka kullanıcının public reçeteleri okunabilir |
| **Hesaplama Makinesi** (`/calculator`) anlık hesap | ✅ | RecipeCalculator stateless — write yapmaz |
| Panel kartlarını görme | ✅ | Rol bazlı dashboard |
| Market/Jobs/Gruplar tab gezme | ✅ | Mock data seed |
| Reçete WhatsApp paylaşımı (örnek metin) | ⚠ | Editor "Paylaş" butonu kayıtlı reçete olmadan çalışmaz; calculator "Paylaş" çalışır |

---

## 2. Guest kullanıcı hangi işlemlerde kayıt/girişe yönlenir?

Aşağıdaki butonlardan birine basınca **`AuthRequiredSheet`** açılır:

| Aksiyon | Ekran | Tier |
|---|---|---|
| Reçete kaydet / güncelle | `RecipeEditorScreen._save` | 1 |
| Üretim kaydet | `ProductionEntryScreen._save` | 1 |
| Fire kaydet | `WasteEntryScreen._save` | 1 |
| Bayi / Müşteri ekle | `AddDealerScreen._save` | 1 |
| Ustalık profili kaydet | `WorkerProfileScreen._save` | 1 |
| İş arıyorum ilanı kaydet | `JobSeekPostFormScreen._save` | 1 |
| Bayi teslimat (Ürün Ver) | `DealerDeliveryFormScreen._save` | 2 |
| Bayi tahsilat | `DealerPaymentFormScreen._save` | 2 |
| Bayi iade | `DealerReturnFormScreen._save` | 2 |
| Bayi düzeltme | `DealerAdjustmentFormScreen._save` | 2 |
| Çalışma geçmişi (tecrübe) ekle | `WorkerExperiencesScreen._AddExperienceSheet._save` | 2 |

**11 yazma noktası** merkezi guard ile sarıldı. Read-only ekranlar bozulmadı.

---

## 3. Merkezi guard nasıl kuruldu?

### `AuthRequiredGuard` — `lib/features/auth/services/auth_required_guard.dart`

```dart
class AuthRequiredGuard {
  /// Pure logic — test edilebilir.
  static bool canWrite({
    required bool isGuest,
    required bool supabaseEnabled,
    required AuthUser? currentUser,
    required BakeryProfile? profile,
  }) {
    if (isGuest) return false;
    if (supabaseEnabled) return currentUser != null;
    // Supabase off — legacy local profile yazabilir.
    if (profile == null) return false;
    if (identical(profile, BakeryProfile.guest)) return false;
    return true;
  }

  /// WidgetRef üzerinden hızlı kontrol.
  static bool canWriteWithRef(WidgetRef ref) { ... }

  /// İzin varsa action'ı çalıştır; yoksa sheet aç.
  /// Döner: true → action ran, false → blocked.
  static Future<bool> runOrPrompt(
    BuildContext context,
    WidgetRef ref, {
    required Future<void> Function() action,
  }) async { ... }
}
```

### Karar matrisi (testle doğrulandı)

| `isGuest` | `supabaseEnabled` | `currentUser` | `profile` | Sonuç |
|---|---|---|---|---|
| true | * | * | * | **engelle** |
| false | true | non-null | * | **izin** |
| false | true | null | * | **engelle** |
| false | false | * | non-null + non-guest | **izin** (legacy local) |
| false | false | * | null veya guest | **engelle** |

### Ekran tarafında pattern

İki kullanım stili:

```dart
// Pattern A — kısa check
if (!AuthRequiredGuard.canWriteWithRef(ref)) {
  await showAuthRequiredSheet(context, ref);
  return;
}
// ... normal save logic

// Pattern B — wrap inside
await AuthRequiredGuard.runOrPrompt(
  context,
  ref,
  action: () async {
    // ... save logic burada
  },
);
```

Tercih: Pattern A — validation sonrası tek satırla guard.

---

## 4. AuthRequired sheet UX

`showModalBottomSheet` → `_AuthRequiredSheet` widget:

```
═══ tutamak ═══
🔥 Hesabını oluştur, kaydın sende kalsın

Bu işlemi kaydetmek için FırınNet hesabı gerekir.
Hesap oluşturduğunda reçetelerin, bayi kayıtların ve
ilanların sana özel saklanır.

[ Hesap oluştur ]              ← copper FilledButton → /auth/role-select
[ Giriş yap ]                  ← outlined → /login
  Şimdilik gezmeye devam et    ← muted TextButton → dismiss
```

### Davranış

- **Hesap oluştur** → `guestMode=false` (otomatik) + `Navigator.pop` + `context.push('/auth/role-select')`
- **Giriş yap** → `guestMode=false` + `Navigator.pop` + `context.push('/login')`
- **Şimdilik gezmeye devam et** → `Navigator.pop`. Guest flag korunur, kullanıcı uygulamayı gezmeye devam eder.

> Brief: *"Hesap oluştur veya Giriş yap seçilirse guestMode false yapılabilir."* — uygulandı. Böylece signUp/signIn akışına girerken artık guest olarak işaretlenmemiş oluyor.

---

## 5. Profile create escape hatch

**Brief'in 2. parçası:** Profil oluşturma ekranında "Üye olmadan gezmeye devam et" seçeneği.

`CreateProfileScreen` altına ikincil TextButton + alt yardım metni eklendi:

```
[ Kaydet ]                        ← AppPrimaryButton (mevcut)

  Üye olmadan gezmeye devam et    ← TextButton (muted, yeni)
  İstersen daha sonra hesap oluşturabilirsin.
```

### `_continueAsGuest()` davranışı (3 senaryo)

```dart
Future<void> _continueAsGuest() async {
  // 1. Form dolu mu? Confirm dialog.
  if (dirty) {
    final keep = await showDialog<bool>(...);
    if (keep != true) return;
  }
  // 2. signed-in ama incomplete profile → signOut + state clear
  if (currentUser != null) {
    await auth!.signOut();
    profileController.clear();
  }
  // 3. Her durumda guest=true + /feed
  await guestModeProvider.setGuest(true);
  profileController.useGuest();
  context.go('/feed');
}
```

### Form dirty confirm dialog

```
┌────────────────────────────────────────┐
│ Formdan çıkılsın mı?                   │
├────────────────────────────────────────┤
│ Girdiğin profil bilgileri              │
│ kaydedilmeyecek. Kayıtsız gezmeye      │
│ devam edebilirsin.                     │
├────────────────────────────────────────┤
│       [ Forma dön ]  [ Gezmeye devam ] │
└────────────────────────────────────────┘
```

`dirty` = name/city/email/password'dan en az biri doluysa.

### 3 senaryo özeti

| Senaryo | Davranış |
|---|---|
| signUp henüz yapılmadı (currentUser=null) + form boş | Doğrudan `setGuest(true)` + `/feed` |
| signUp henüz yapılmadı + form dolu | Confirm dialog → onay → `setGuest(true)` + `/feed` |
| signUp yapıldı ama profile incomplete (currentUser=var) | `auth.signOut()` + `profileController.clear()` + `setGuest(true)` + `/feed` — **eksik profil session'ı paneli kirletmez** |

---

## 6. Değişen dosyalar

### Yeni
- `lib/features/auth/services/auth_required_guard.dart` — Guard + sheet
- `test/auth_required_guard_test.dart` — 6 yeni test
- `GUEST_ACTION_GUARD_REPORT.md` (bu rapor)

### Düzenlenen (11 ekran + 2 string + 1 model)
- `lib/core/constants/app_strings.dart` — 5 sheet + 5 escape stringi
- `lib/features/profile/screens/create_profile_screen.dart` — escape hatch (`_continueAsGuest`, dirty check, confirm dialog, footer button)
- `lib/features/bakery_panel/screens/recipe_editor_screen.dart` — `_save` guard
- `lib/features/bakery_panel/screens/production_entry_screen.dart` — `_save` guard
- `lib/features/bakery_panel/screens/waste_entry_screen.dart` — `_save` guard
- `lib/features/dealers/screens/add_dealer_screen.dart` — `_save` guard
- `lib/features/dealers/screens/dealer_delivery_form_screen.dart` — `_save` guard
- `lib/features/dealers/screens/dealer_payment_form_screen.dart` — `_save` guard
- `lib/features/dealers/screens/dealer_return_form_screen.dart` — `_save` guard
- `lib/features/dealers/screens/dealer_adjustment_form_screen.dart` — `_save` guard
- `lib/features/worker/screens/worker_profile_screen.dart` — `_save` guard
- `lib/features/worker/screens/worker_experiences_screen.dart` — `_AddExperienceSheet._save` guard
- `lib/features/worker/screens/job_seek_post_form_screen.dart` — `_save` guard

### Silinen
**(Yok.)**

---

## 7. `flutter analyze` sonucu

```
Analyzing firinnet...
No issues found! (ran in 0.5s)
```

---

## 8. `flutter test` sonucu

```
00:03 +122: All tests passed!
```

### Yeni 6 test (`auth_required_guard_test.dart`)

| Test | İçerik |
|---|---|
| `guest=true her durumda yazma engellenir` | Supabase on + signed-in olsa bile guest=true → false |
| `Supabase enabled + signed-in → izin` | Normal write flow |
| `Supabase enabled + user null → engelle` | Sheet açılır |
| `Supabase disabled + local non-guest profile → izin (legacy)` | Anahtarsız mod local write korunur |
| `Supabase disabled + profile null → engelle` | Boş local state'te write engellenir |
| `Supabase disabled + BakeryProfile.guest → engelle` | Misafir profile object yazma yetkisi vermez |

### Test dağılımı (toplam 122)

| Dosya | Sayı |
|---|---|
| `auth_required_guard_test.dart` (YENİ) | **6** |
| `auth_entry_v1_3_test.dart` | 20 |
| `panel_v1_2_test.dart` | 19 |
| `recipe_quantity_visibility_test.dart` | 14 |
| `local_recipe_repository_test.dart` | 11 |
| `feed_repository_test.dart` | 11 |
| `social_group_repository_test.dart` | 11 |
| `dealer_balance_test.dart` | 7 |
| `recipe_share_text_builder_test.dart` | 6 |
| `recipe_calculator_test.dart` | 4 |
| `dealer_repository_test.dart` | 4 |
| `feed_composer_layout_test.dart` | 2 |
| `dealer_share_builder_test.dart` | 2 |
| `dealer_pdf_builder_test.dart` | 2 |
| `repository_provider_selection_test.dart` | 2 |
| `widget_test.dart` | 1 |

---

## 9. UX metinleri (sözlük)

**`app_strings.dart` — V1.3.1 eklemeleri:**

| Key | Metin |
|---|---|
| `authRequiredTitle` | Hesabını oluştur, kaydın sende kalsın |
| `authRequiredBody` | Bu işlemi kaydetmek için FırınNet hesabı gerekir. Hesap oluşturduğunda reçetelerin, bayi kayıtların ve ilanların sana özel saklanır. |
| `authRequiredCreate` | Hesap oluştur |
| `authRequiredSignIn` | Giriş yap |
| `authRequiredKeepBrowsing` | Şimdilik gezmeye devam et |
| `profileCreateGuestEscape` | Üye olmadan gezmeye devam et |
| `profileCreateGuestHint` | İstersen daha sonra hesap oluşturabilirsin. |
| `profileCreateDiscardTitle` | Formdan çıkılsın mı? |
| `profileCreateDiscardBody` | Girdiğin profil bilgileri kaydedilmeyecek. Kayıtsız gezmeye devam edebilirsin. |
| `profileCreateDiscardKeep` | Forma dön |
| `profileCreateDiscardLeave` | Gezmeye devam et |

Dil tonu: **doğal, yumuşak**. "Yapamazsın" / "Yasak" kullanılmadı. Cezalandırıcı dil yok.

---

## 10. Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Kayıtsız devam et seçeneğini kaldırma | ✅ AuthEntry'de duruyor |
| Kayıtsız kullanıcıyı uygulamadan atma | ✅ Gezebilir |
| Sert "yasak" dili kullanma | ✅ Doğal onboarding dili |
| Supabase schema/RLS değiştirme | ✅ Migration yok |
| Panel/reçete/bayi/worker/toptancı veri modellerini bozma | ✅ Sadece save fonksiyonlarının başına guard eklendi |
| Renk/tasarım değiştirme | ✅ AppColors aynı |
| Mevcut 116 test bozulmasın | ✅ 116/116 → +6 = **122/122** |
| Profile completion zorunluluğunu bozma | ✅ İncomplete authenticated session signOut ile temizleniyor; eksik profilli auth user paneli kirletmez |

---

## 11. Manuel test adımları

```powershell
adb shell pm clear com.firinnet.firin_defter
flutter run -d emulator-5554 `
  --dart-define="SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co" `
  --dart-define="SUPABASE_ANON_KEY=<publishable_anon_key>"
```

### Test 1 — Guest gezme akışı
1. Splash → AuthEntryScreen.
2. "Kayıtsız devam et" → Feed açılır.
3. Hesaplama Makinesi'ne git → 316 hesap çalışır (write yok, izin verilir).
4. "Yeni Reçete" → form doldur → Kaydet → **AuthRequired sheet açılır**.
5. "Şimdilik gezmeye devam et" → sheet kapanır, kullanıcı guest olarak kalır.

### Test 2 — Hesap oluştur escape (AuthRequired sheet)
6. Aynı form, Kaydet → sheet → "Hesap oluştur" → guest flag temizlenir, `/auth/role-select`'e gider.
7. Rol seç → form → kaydet → Splash → /panel.

### Test 3 — Profile create escape hatch (yeni V1.3.1)
1. Splash → AuthEntry → "Hesabım yok, üye ol" → rol seç → CreateProfileScreen.
2. Hiçbir alana yazma → "Üye olmadan gezmeye devam et" → direkt /feed (dirty=false).
3. Kullanıcı /feed'de guest olarak gezer.

### Test 4 — Form dolu iken escape
1. AuthEntry → üye ol → rol seç → form.
2. Ad ve şehir yaz.
3. "Üye olmadan gezmeye devam et" → **confirm dialog açılır** ("Formdan çıkılsın mı?").
4. "Forma dön" → dialog kapanır, kullanıcı formda kalır.
5. "Gezmeye devam et" → guest=true + /feed.

### Test 5 — Incomplete signUp escape
1. AuthEntry → üye ol → rol seç → form → email/şifre/ad yaz → Kaydet.
2. Supabase signUp ekran kapatmadan başarısız oldu varsayalım (örn. ağ hatası) — kullanıcı formda kalır.
3. Eğer signUp BAŞARILI olduysa Splash → /panel veya /profile/create döner.
4. "Üye olmadan gezmeye devam et" tıklanırsa → currentUser var → signOut + clear + guest=true + /feed.

---

## 12. Git

Commit + push aşağıda.

**Mesaj:** `fix(firinnet): gate guest write actions behind auth`

---

## 13. Kalan işler (sonraki faz)

| İş | Öncelik |
|---|---|
| Feed composer (post paylaşma) için guard — `lib/features/feed/screens/feed_screen.dart`'taki composer'a entegre | P2 |
| Group message bar guard | P2 |
| DealerDetailScreen price/note bottom sheet'leri için inline guard | P2 |
| Profile screen "Profili Düzenle" akışı için guard (eğer eklenirse) | P3 |
| Reçete public toggle için ayrı guard (şu an save guard'ı ile birlikte engellenir) | P3 |
| Guest user için "kaydın yok" empty state'leri (örn. Reçetelerim listesi) | P3 |

---

**Hedef gerçekleşti.** Kayıtsız devam et seçeneği korundu; kullanıcı uygulamayı serbest gezebilir. Ama herhangi bir kalıcı işlem (reçete kaydet, bayi ekle, üretim/fire/teslimat/tahsilat/iade/düzeltme, ustalık profili, iş arıyorum ilanı) yapmak istediğinde doğal şekilde **`Hesabını oluştur, kaydın sende kalsın`** sheet'i açılır. Profile create ekranında da "Üye olmadan gezmeye devam et" ile fikrini değiştiren kullanıcı confirm dialog'dan geçerek guest moduna döner.
