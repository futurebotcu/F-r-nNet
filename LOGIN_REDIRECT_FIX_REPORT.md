# LOGIN_REDIRECT_FIX_REPORT

**Tarih:** 2026-05-13
**Faz:** V1.3.4 — Post-login redirect bug düzeltildi
**Test:** `flutter analyze` temiz, `flutter test` **154/154** yeşil (151 mevcut + 3 yeni)
**Schema:** Migration yok.
**Sınıf:** **P0 bug fix** (kullanıcı emülatörde "giriş yapamıyor" yaşadı)

---

## 1. Root cause

### Bug açıklaması
Kullanıcı email/şifre girip "Giriş Yap" basınca:
- Supabase tarafında signIn **başarılı** (DB doğrulaması: `last_sign_in_at = 2026-05-13 10:35`)
- Profil DB'de **complete** (Fatih, commercial, Manisa, Usta Fırıncı)
- Beklenen: `/panel` (RoleDashboard)
- **Gerçek davranış:** `/auth` (AuthEntryScreen) — kullanıcının "onboarding'in başına atıyor" dediği

### Teknik kök neden

`lib/features/auth/providers/auth_providers.dart` (eski hâli):

```dart
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo?.currentUser;   // ← SNAPSHOT, body bir kez çalışır
});
```

Riverpod `Provider<T>` semantiği: **body bir kez çalışır, sonuç cache'lenir**. Bağımlılık (`ref.watch(authRepositoryProvider)`) değişmediği sürece provider **rebuild olmaz**.

`authRepositoryProvider` da Provider — `AppConfig.supabaseEnabled` compile-time const olduğu için **hiç değişmez**. Yani:

1. App boot'ta `currentAuthUserProvider` ilk okunur → body çalışır → `repo.currentUser` o an **null** (boot'ta oturum yok) → cache'lenir.
2. Kullanıcı LoginScreen'de email/şifre girer → `auth.signIn(...)` çağrılır → Supabase SDK içinde `_client.auth.currentUser` artık dolu, ayrıca `onAuthStateChange` stream emit eder.
3. LoginScreen `context.go('/')` → Splash mount.
4. Splash `_route()` → `ref.read(currentAuthUserProvider)` → **eski cache'lenmiş null** döner (provider rebuild olmamış).
5. Splash `user == null` görür → `context.go('/auth')`.

### Etkisi

- Login UX'i kırık (kullanıcı giriş yapamıyor algısı).
- **Ek olarak yan etki:** `bakeryRepositoryProvider`, `dealerRepositoryProvider`, `recipeRepositoryProvider`, `workerRepositoryProvider`, `canWriteCheckProvider` hepsi `ref.watch(currentAuthUserProvider)` kullanıyor. Stale provider hepsini etkilerdi — örn. signed-in kullanıcı `LocalBakeryRepository` döner (Supabase repo yerine), kayıtlar in-memory'e gider, restart'ta kaybolur. Sessiz veri kaybı riski.

---

## 2. DB profile durumu (kontrol)

```sql
SELECT id, email, email_confirmed_at IS NOT NULL AS confirmed,
       last_sign_in_at, raw_user_meta_data
  FROM auth.users WHERE email = 'fatihkartal75@gmail.com';
```

Çıktı:
```
id:                abf96b42-0d17-40b1-9b0f-cbf910f9e2a4
email:             fatihkartal75@gmail.com
confirmed:         true                      ← email confirmation OK
last_sign_in_at:   2026-05-13 10:35:19+00    ← signIn BAŞARILI olmuş
raw_user_meta_data: {
  display_name:      "fatih",
  account_type:      "commercial",
  city:              "manisa",
  profession_badge:  "Usta Fırıncı"
}
```

```sql
SELECT * FROM public.profiles WHERE id = '...';
```
Çıktı: profile row var, complete (`displayName`+`accountType`+`city`+`roleBadge` hepsi dolu).

**Kanıt:** Supabase tarafında her şey sağlam. Bug yalnız client provider katmanında.

---

## 3. Hangi route yanlış çalışıyordu

`splash_screen.dart` `_route()`:

```dart
final user = ref.read(currentAuthUserProvider);
if (user == null) {
  // ...
  context.go(AppRoutes.authEntry);   // ← stale null nedeniyle buraya geliyor
}
```

Splash kararı kod tarafında doğru; ama `user` parametresi yanlış (cache'lenmiş null) → yanlış dala düşüyor.

---

## 4. Nasıl düzeltildi

### Tek satırlık reactive fix

`lib/features/auth/providers/auth_providers.dart`:

```dart
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return null;
  // V1.3.4 — Auth stream'i watch et → emit (signIn/signOut/token refresh)
  // sonrası bu provider rebuild olur. Watch edilen değer kullanılmıyor;
  // yalnız dependency oluşturmak için gerekli.
  ref.watch(authUserStreamProvider);
  return repo.currentUser;
});
```

### Neden bu yeterli

- `authUserStreamProvider` zaten vardı (V1.3'ten beri) — Supabase SDK'nın `onAuthStateChange` stream'ini yayınlıyor.
- `ref.watch(authUserStreamProvider)` çağrısı `currentAuthUserProvider`'ı **stream'in dependency**'si yapıyor.
- Stream her emit'te (signIn/signOut/token refresh) AsyncValue değişir → `currentAuthUserProvider` invalidate olur → bir sonraki read body'yi yeniden çalıştırır → `repo.currentUser` **taze** SDK durumunu döner.

### Yan fayda

Tüm auth-bağımlı provider'lar (`bakeryRepositoryProvider`, `dealerRepositoryProvider`, `recipeRepositoryProvider`, `workerRepositoryProvider`, `canWriteCheckProvider`) `ref.watch(currentAuthUserProvider)` kullandığından, otomatik olarak signIn/signOut sonrası rebuild oluyor:
- signIn → `bakeryRepositoryProvider` → `SupabaseBakeryRepository`'ye geçer (önceden Local'da kalıyordu)
- signOut → tekrar `LocalBakeryRepository`'ye düşer
- `canWriteCheckProvider` closure her çağrıda taze değer okur ✓

---

## 5. Test sonuçları

### `flutter analyze`
```
Analyzing firinnet...
No issues found! (ran in 0.5s)
```

### `flutter test`
```
00:05 +154: All tests passed!
```

### Yeni 3 test (`test/auth_provider_reactive_test.dart`)

| Test | Senaryo | Beklenen | Sonuç |
|---|---|---|---|
| signIn sonrası provider taze user'ı döner | FakeAuthRepository.simulateSignIn(u1) → ref.read | `u1` | ✅ |
| signOut sonrası provider null döner | simulateSignIn → simulateSignOut → ref.read | `null` | ✅ |
| Auth-bağımlı providerlar transition alır | currentAuthUser null → signIn → not null | non-null | ✅ |

`_FakeAuthRepository`: in-memory broadcast stream + currentUser snapshot. Supabase SDK'sının davranışını minimum replikasyonla simüle ediyor.

### Mevcut 151 test bozulmadı
Tam suite çalıştı: 154/154 yeşil (151 + 3).

---

## 6. Manuel test adımları

```powershell
adb shell pm clear com.firinnet.firin_defter
flutter run -d emulator-5554 `
  --dart-define="SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co" `
  --dart-define="SUPABASE_ANON_KEY=<publishable_anon_key>"
```

### Test 1 — Fatih ile login → /panel
1. Splash → AuthEntryScreen (3 buton).
2. **Giriş Yap** → email: `fatihkartal75@gmail.com`, şifre: doğru.
3. Beklenen: Splash kısa flash → **/panel** (RoleDashboardScreen, Ticari rol kartları).
4. **Bug regression kontrolü:** Eğer hâlâ `/auth`'a atarsa fix uygulanmamış demektir.

### Test 2 — Logout → AuthEntry
1. Profile (Feed header avatar tap → /profile) → "Profilden Çık".
2. Beklenen: signOut + guest clear + → `/auth`.

### Test 3 — Yeni signUp → ProfileCreate complete → /panel
1. AuthEntry → "Hesabım yok, üye ol" → rol seç → form.
2. Email + şifre + display_name + city + profession_badge.
3. Kaydet → Splash → user var + profile complete → **/panel**.

### Test 4 — Login + incomplete profile → /profile/create (regression önleme)
Manuel olarak Supabase'de bir profil satırının `city` veya `display_name`'ini boşalt.
1. O kullanıcı ile login.
2. Beklenen: Splash → **/profile/create** (zorunlu completion).

---

## 7. Değişen dosyalar

### Düzenlenen
- `lib/features/auth/providers/auth_providers.dart` — `currentAuthUserProvider` body'sine `ref.watch(authUserStreamProvider)` eklendi (3 satır)

### Yeni
- `test/auth_provider_reactive_test.dart` — 3 reactive provider testi
- `LOGIN_REDIRECT_FIX_REPORT.md` (bu rapor)

### Silinen
**(Yok.)**

---

## 8. Etki / kapsam

| Dolaylı düzelen yan davranış | Açıklama |
|---|---|
| **bakeryRepositoryProvider** signIn sonrası SupabaseBakeryRepository'ye geçer | Önceden stale provider → hep LocalBakeryRepository → veriler in-memory kalıyordu |
| **dealerRepositoryProvider** same | Aynı pattern |
| **recipeRepositoryProvider** same | Aynı pattern |
| **workerRepositoryProvider** same | Aynı pattern |
| **canWriteCheckProvider** closure taze auth state okur | Closure her çağrıda fresh ref.read yapıyor; provider invalidation onu da dolaylı tetikler |
| **profileRepositoryProvider** Supabase tarafı | Zaten signIn'den sonra ProfileController stream'le profili çekiyordu (separate path) — etkilenmedi |

**Sonuç:** Bu fix sadece login redirect'i değil, **tüm auth-state-aware repository selection'ı** doğru çalıştıran tek nokta düzeltmeydi.

---

## 9. Kırmızı çizgi kontrolü

| Kural | Durum |
|---|---|
| Panel/reçete/bayi/worker/toptancı koduna dokunma | ✅ Sadece auth_providers.dart 3 satır |
| Supabase schema/RLS değiştirme | ✅ Migration yok |
| Guest guard mimarisini bozma | ✅ Wrapper'lar olduğu gibi |
| Token/key/secret yazma | ✅ Yok |
| Mevcut 151 test bozulmasın | ✅ 151 → +3 = **154/154** |

---

## 10. Sonraki adım

Bu fix sonrası kullanıcının login akışı çalışmalı. Etkileşimli emülatör testi:
1. `pm clear` → fresh build → AuthEntry açılır
2. Fatih ile giriş → **/panel**'e gitmeli (önceden /auth'a atıyordu)
3. Auth panel kartları + Fırın Paneli açılır mı doğrula
4. Çıkış → AuthEntry'ye dön
5. Guest devam et → Feed gez → write butonlarında AuthRequired sheet görünür mü doğrula

Bu fix sonrası önceki audit raporu olan `FULL_APP_V1_3_3_SMOKE_AUDIT.md`'in **5. Auth kullanıcı smoke** bölümü gerçekten test edilebilir hâle geldi.
