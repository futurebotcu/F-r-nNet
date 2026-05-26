# AUTH_ENTRY_REBUILD_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.3 — Auth Entry + Onboarding sistemi yeniden kuruldu
**Test:** `flutter analyze` temiz, `flutter test` **116/116** yeşil (96 mevcut + 20 yeni)
**Schema:** Değişmedi. Yeni migration **yok.**

> Önceki audit: [AUTH_ONBOARDING_ENTRY_AUDIT.md](AUTH_ONBOARDING_ENTRY_AUDIT.md)

---

## 1. Eski akışın problemi

Audit'te 3 ana sıkıntı tespit edilmişti:

1. **3 farklı entry ekranı** (LoginScreen / OnboardingScreen / CreateProfileScreen) state'e göre farklı çağrılıyordu → kullanıcı hangi ekranda olduğunu anlamıyor, akış parçalı.
2. **Persisted local flag yoktu** — `SharedPreferences`/`secure_storage` hiç kullanılmıyordu. "Kayıtsız Devam Et" Riverpod state'inde uçucu kalıyordu; app restart sıfırlıyordu.
3. **Profile completion gating yoktu** — eksik `display_name`/`city` ile kullanıcı `/panel`'e girip yarım profile ile çalışmaya başlayabiliyordu.

---

## 2. Yeni ilk ekran — `AuthEntryScreen`

**Route:** `/auth` (yeni boot landing)
**Dosya:** `lib/features/auth/screens/auth_entry_screen.dart`

Başlık + alt metin + 3 net buton:

```
🔥
FırınNet'e hoş geldin
Fırıncılar, ustalar ve toptancılar için iş, reçete ve paylaşım ağı.

[ Giriş Yap ]                  ← AppPrimaryButton (copper)
[ Hesabım yok, üye ol ]        ← OutlinedButton (copper border)
  Kayıtsız devam et            ← TextButton (muted)
```

**Davranış:**
- **Giriş Yap** → `context.push('/login')` (LoginScreen — sadeleştirildi).
- **Hesabım yok, üye ol** → `context.push('/auth/role-select')` (yeni RoleSelectScreen).
- **Kayıtsız devam et** → `guestModeProvider.setGuest(true)` (SharedPreferences'a yazar) + `profile = guest` + `context.go('/feed')`.

**Backend off durumu:** Üstte sarı uyarı banner'ı: *"Canlı giriş kapalı. Kayıtsız devam edebilirsin."* + İlk iki buton disabled, "Kayıtsız devam et" aktif.

---

## 3. Login akışı

**Route:** `/login` (push)
**Dosya:** `lib/features/auth/screens/login_screen.dart` — sadeleştirildi:

```
🔥
Giriş Yap
FırınNet — Fırıncının dijital ağı

[ E-posta             ]
[ Şifre               ]

[ Giriş Yap ]                   ← copper CTA
  Hesabın yok mu? Üye ol        ← TextButton → /auth/role-select
```

**"Kayıtsız Devam Et" buradan kaldırıldı** — yalnız AuthEntry'de.

Login başarılı → `guestModeProvider.setGuest(false)` + `context.go('/')` → Splash redirect mantığı `profile.isComplete` kontrolü ile `/panel` veya `/profile/create`'e yönlendirir.

Türkçe hata mesajları `AuthErrorTranslator` ile zaten çalışıyor (audit'te doğrulandı).

---

## 4. Üye ol + role seçimi akışı

**Yeni:** `RoleSelectScreen` — `/auth/role-select`
**Dosya:** `lib/features/auth/screens/role_select_screen.dart`

```
Hangi rol senin için?
Sektördeki yerini seç — formdaki alanları rolüne göre düzenleriz.

┌─────────────────────────────────────────────┐
│ 🏪 Ticari                                   │
│    Fırın işletmesi, bayi ve üretim yönetimi │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ 👤 Bireysel                                 │
│    Usta profili, iş arama ve reçeteler      │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ 🚚 Toptancı                                 │
│    Müşteri, ürün, fiyat ve teslimat yönet.  │
└─────────────────────────────────────────────┘
```

Tıklayınca `context.push('/profile/create?role=<commercial|individual|wholesaler>')`.

### CreateProfileScreen role-aware oldu

- `initialAccountType` parametresi alır (router query'den gelir).
- Account type chip'leri o role pre-selected gelir; kullanıcı isterse değiştirebilir.
- **Meslek rozeti listesi role bazlı:**
  - Ticari: Usta Fırıncı, Fırın Sahibi, İşletmeci, Pastacı, Diğer
  - Bireysel: Usta Fırıncı, Mayacı, Hamurcu, Simitçi, Poğaçacı, Pasta Ustası, Çırak, Kalfa, Diğer
  - Toptancı: Toptancı, Uncu, Susamcı, Ekipman Satıcısı, Diğer
- Account type değiştirilince badge listesi otomatik güncelleniyor.

### SignUp metadata sözleşmesi (mevcut)

Brief'in istediği gibi `handle_new_user` trigger sözleşmesi **bozulmadı**:
```dart
auth.signUp(email, password, metadata: {
  'display_name': displayName,
  'account_type': _accountType.name,   // commercial | individual | wholesaler
  'profession_badge': _badge,
  'city': city,
});
```

Trigger `public.profiles` satırını otomatik oluşturuyor. Client `profiles`'a doğrudan INSERT atmıyor.

### Profile completion mode

CreateProfileScreen `_isCompletion` modunda (mevcut profile null değil, eksik durumda):
- Email + şifre alanları disabled (signed-in kullanıcı için).
- `signUp` yerine `profileController.save()` → mevcut profile satırı UPDATE.

---

## 5. Profile completion contract

**`BakeryProfile.isComplete`** (yeni getter — `bakery_profile.dart`):

```dart
bool get isComplete =>
    displayName.trim().isNotEmpty &&
    city.trim().isNotEmpty &&
    roleBadge.trim().isNotEmpty;
```

**Zorunlu alanlar:** `display_name`, `account_type` (enum daima dolu), `city`, `profession_badge`. Email signed-in user için `auth.users`'tan gelir.

**Form validators:**
- `display_name`: zorunlu (`'Profil adı gerekli'`)
- `city`: **artık zorunlu** (`'Şehir gerekli'`) — eskiden optional'dı.
- `email`: zorunlu (Supabase enabled + yeni signup)
- `password`: zorunlu + min 6 char (Supabase enabled + yeni signup)
- `profession_badge`: chip default ile daima dolu

**Splash karar mantığı:**
```
profile == null OR !profile.isComplete  →  /profile/create  (zorunlu)
profile.isComplete                       →  /panel
```

---

## 6. Guest / Kayıtsız devam kalıcılığı

### Yeni: `GuestModeStorage` + `guestModeProvider`

**Dosya:** `lib/features/auth/services/guest_mode_storage.dart` + `lib/features/auth/providers/guest_mode_provider.dart`

```dart
// SharedPreferences key: 'firinnet.guest_mode'
await GuestModeStorage.instance.write(true);   // Kayıtsız seçildi
final isGuest = await GuestModeStorage.instance.read();  // boot'ta okunur
await GuestModeStorage.instance.clear();       // logout/signIn temizler
```

### Davranış

- **Kayıtsız Devam Et** tıklandığında: `setGuest(true)` → SharedPreferences'a yazılır. App restart sonrası **korunur**.
- **App restart + guest=true**: Splash → `/feed` (guest demo akışı).
- **Login başarılı**: `setGuest(false)` otomatik (signIn'de + signUp'ta).
- **Logout**: `setGuest(false)` + `profile.clear()` + Supabase signOut + `context.go('/auth')`.
- **`adb shell pm clear`**: SharedPreferences temizlenir → guest=false → Splash `/auth`.

---

## 7. Router karar tablosu

`splash_screen.dart` `_route()` 6-yollu (eski 3-yolluya genişletildi):

| # | `supabaseEnabled` | `currentAuthUser` | `guest` | `profile.isComplete` | Yönlendirme |
|---|---|---|---|---|---|
| 1 | false | n/a | false | n/a | `/auth` (yeni boot landing) |
| 2 | false | n/a | true | n/a | `/feed` (local guest demo) |
| 3 | true | null | false | n/a | `/auth` |
| 4 | true | null | true | n/a | `/feed` |
| 5 | true | var | n/a | true | `/panel` (+ guest flag clear) |
| 6 | true | var | n/a | false (veya profile null) | `/profile/create` (zorunlu completion) |

**Eski Splash 3-yolluydu** (audit'te belgelendi); yenisi state'e tam duyarlı.

---

## 8. Değişen dosyalar

### Yeni dosyalar
- `lib/features/auth/services/guest_mode_storage.dart` — SharedPreferences wrapper
- `lib/features/auth/providers/guest_mode_provider.dart` — Riverpod katmanı
- `lib/features/auth/screens/auth_entry_screen.dart` — yeni boot landing
- `lib/features/auth/screens/role_select_screen.dart` — signup öncesi rol seçimi
- `test/auth_entry_v1_3_test.dart` — 20 yeni test
- `AUTH_ENTRY_REBUILD_REPORT.md` (bu rapor)
- `AUTH_ROUTER_ENTRY_AUDIT.md`, `AUTH_ONBOARDING_ENTRY_AUDIT.md` (öncül audit'ler)

### Düzenlenen dosyalar
- `pubspec.yaml` — `shared_preferences: ^2.3.2` dependency
- `lib/app/router/app_router.dart` — `/auth`, `/auth/role-select` route'ları + `?role=` query parser
- `lib/features/onboarding/screens/splash_screen.dart` — 6-yollu karar; guest+profile completeness kontrolü
- `lib/features/auth/screens/login_screen.dart` — "Kayıtsız Devam Et" kaldırıldı; "Hesabın yok mu? Üye ol" eklendi; signIn sonrası Splash redirect mantığına bağlandı
- `lib/features/profile/screens/create_profile_screen.dart` — `initialAccountType` param; role-aware badge listesi; completion mode (incomplete profile için update path); `city` validator eklendi
- `lib/features/profile/screens/profile_screen.dart` — logout artık guest flag temizler + `/auth`'a gider
- `lib/features/profile/models/bakery_profile.dart` — `isComplete` getter
- `lib/core/constants/app_strings.dart` — yeni V1.3 stringleri
- `lib/core/constants/app_products.dart` — `RoleBadges.commercial/individual/wholesaler` listeleri

### Silinen
**(Yok.)** — Mevcut `OnboardingScreen` legacy alias olarak korundu (route `/onboarding` hâlâ erişilebilir, ama Splash artık oraya gitmiyor).

---

## 9. `flutter analyze` sonucu

```
Analyzing firinnet...
No issues found! (ran in 0.6s)
```

---

## 10. `flutter test` sonucu

```
00:02 +116: All tests passed!
```

### Test dağılımı (toplam 116)

| Dosya | Test sayısı |
|---|---|
| **`auth_entry_v1_3_test.dart`** (yeni) | **20** |
| `panel_v1_2_test.dart` | 19 |
| `recipe_share_text_builder_test.dart` | 6 |
| `recipe_calculator_test.dart` | 4 |
| `local_recipe_repository_test.dart` | 11 |
| `recipe_quantity_visibility_test.dart` | 14 |
| `feed_repository_test.dart` | 11 |
| `social_group_repository_test.dart` | 11 |
| `dealer_balance_test.dart` | 7 |
| `dealer_repository_test.dart` | 4 |
| `dealer_share_builder_test.dart` | 2 |
| `dealer_pdf_builder_test.dart` | 2 |
| `repository_provider_selection_test.dart` | 2 |
| `feed_composer_layout_test.dart` | 2 |
| `widget_test.dart` | 1 |

### Yeni 20 testin gruplandırılması

| Grup | Test |
|---|---|
| Guest mode persistence | (4) default false ✓; write+restart korunur ✓; clear false yapar ✓; Notifier setGuest persist eder ✓ |
| BakeryProfile.isComplete | (5) full complete ✓; displayName boş incomplete ✓; city boş incomplete ✓; roleBadge boş incomplete ✓; guest incomplete ✓ |
| Role bazlı meslek rozetleri | (4) commercial ✓; individual ✓; wholesaler ✓; legacy `all` korundu ✓ |
| Route sözleşmesi | (4) `authEntry='/auth'` ✓; `roleSelect='/auth/role-select'` ✓; `createProfile='/profile/create'` ✓; `login='/login'` ✓ |
| Auth Entry stringleri | (3) 3 buton metni ✓; backend off uyarısı ✓; 3 rol açıklamaları ✓ |

> Brief'teki 11 test başlığının tamamı bu 20 testle örtüşür (bazı testler birden fazla başlığı kapsar).

---

## 11. Manuel test adımları

### Emülatörde temiz test

```powershell
adb shell pm clear com.firinnet.firin_defter
flutter run -d emulator-5554 `
  --dart-define="SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co" `
  --dart-define="SUPABASE_ANON_KEY=<publishable_anon_key>"
```

### Beklenen davranış

1. **Splash** (700 ms) → "FırınNet" + slogan.
2. **AuthEntryScreen** açılır:
   - Başlık: "FırınNet'e hoş geldin"
   - Alt metin: "Fırıncılar, ustalar ve toptancılar için iş, reçete ve paylaşım ağı."
   - 3 buton: **Giriş Yap** (büyük copper), **Hesabım yok, üye ol** (outlined), **Kayıtsız devam et** (muted)
3. **"Giriş Yap"** → `/login`'e gider, email + şifre formu. fatihkartal75@gmail.com ile giriş → Splash → eğer profil complete ise `/panel`; değilse `/profile/create` zorunlu.
4. **"Hesabım yok, üye ol"** → `/auth/role-select`. 3 rol kartı. Birini seç → `/profile/create?role=...`. Form pre-selected rol ile açılır. Kaydet → Supabase signUp + Splash → `/panel`.
5. **"Kayıtsız devam et"** → SharedPreferences'a `firinnet.guest_mode=true` yazılır → `/feed`. **App restart edersen** Splash → `/feed` (guest flag korunur).
6. **Profile sekmesinde "Profilden Çık"** → Supabase signOut + guest flag temizle + `/auth`.

### Edge case'ler

- **Dart-define geçilmedi** (SUPABASE_URL boş): Splash → `/auth`. AuthEntry sarı banner: "Canlı giriş kapalı. Kayıtsız devam edebilirsin." İlk 2 buton disabled.
- **Profile yarım** (city silinmiş): Splash → `/profile/create` zorunlu, "Profili Tamamla" başlığı, email disabled.
- **Login sonrası profile complete**: Splash → `/panel`. Guest flag clear.

---

## 12. Git

Commit + push aşağıda yapılacak.

**Mesaj formatı:**
```
fix(firinnet): rebuild auth entry and onboarding flow
```

---

## 13. Kalan işler (sonraki faz)

| İş | Öncelik |
|---|---|
| Email confirmation senaryosu (Supabase confirm-email aktifse `res.session==null` ayrımı) — şu an signUp sonrası `/panel`'e gönderir ama session yok | P1 |
| "Şifremi unuttum" akışı (`auth.resetPasswordForEmail()`) | P2 |
| OnboardingScreen tamamen kaldırılabilir (artık ulaşılmıyor) — temizlik | P3 |
| Top-level GoRouter `redirect` callback ile auth gating'i merkezi yap (şu an Splash + screen-level kontrol) | P2 |
| Guest user veri yazmaya çalışınca "Bu işlem için giriş yapman gerekiyor" snackbar — repository write metotlarına guard | P2 |

---

## 14. Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Panel/reçete/bayi/toptancı/worker sistemlerine dokunma | ✅ Hiçbiri değişmedi |
| Supabase schema/RLS değiştirme | ✅ Migration yok |
| Yeni migration yapma | ✅ |
| Renk paletini değiştirme | ✅ AppColors/AppShadow dokunulmadı |
| Mevcut Auth/Profile/Supabase yapısını bozma | ✅ AuthRepository sözleşmesi aynı, handle_new_user trigger aynı |
| service_role / PAT / DB password | ✅ Yok |
| Secret hardcode | ✅ Yok |
| Mevcut 96 test bozulmasın | ✅ 96/96 → +20 = **116/116** |

---

**Hedef gerçekleşti.** Uygulama artık her açılışta şunu gösteriyor:

```
FırınNet'e hoş geldin
Fırıncılar, ustalar ve toptancılar için iş, reçete ve paylaşım ağı.

[ Giriş Yap ]
[ Hesabım yok, üye ol ]
  Kayıtsız devam et
```

Üye ol seçilince önce rol seçilir (Ticari / Bireysel / Toptancı), sonra rol bazlı profil formu açılır. Profil tamamlanınca kullanıcı doğru role paneline gider. Kayıtsız devam et seçimi SharedPreferences ile kalıcı; restart sonrası da korunur. Logout her şeyi temizler ve kullanıcıyı boot landing'e döndürür.
