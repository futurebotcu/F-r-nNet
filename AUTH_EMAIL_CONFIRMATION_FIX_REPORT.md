# Auth Email Confirmation Fix Report

**Tarih:** 2026-05-16
**Branch:** `main` @ önceki HEAD `595b46b`
**Tip:** Kod fix. DB migration yok, storage yok, dependency yok, Supabase Dashboard ayarı değişmedi.

---

## 1. Root cause (özet — tam audit `AUTH_SESSION_CONFIRMATION_AUDIT.md`)

Supabase Auth ayarı `mailer_autoconfirm: false` (anon key ile `/auth/v1/settings` üzerinden doğrulandı). Yani signUp:
- `auth.users` satırı oluşturur.
- `email_confirmed_at = null` set eder.
- `AuthResponse(user: User, session: null)` döner — **session vermez**.

`SupabaseAuthRepository.signUp` sadece `res.user`'ı kontrol ediyordu, session null kontrolü yoktu. Caller (CreateProfileScreen) "başarılı" sanıp `context.go(AppRoutes.splash)` yapıyordu. Splash `currentUser == null` görüp `/auth`'a geri atıyordu → kullanıcı kafa karışıklığı içinde, ya guest mode'a düşüyor ya da AuthEntry'de "Confirm hatası" gibi yorumlanan bir snackbar görüyordu.

## 2. Before / after flow

### Before
```
[Form] _save
  └→ auth.signUp(...)        // res.session null gibi davranılır
  └→ guest=false
  └→ snackbar: "Hesabın oluşturuldu. Hoş geldin!"   // YANILTICI
  └→ context.go(/)            // Splash
        └→ currentUser == null
        └→ guest == false
        └→ context.go(/auth)  // kullanıcı AuthEntry'de bulur — niçin?
```

### After
```
[Form] _save
  └→ result = auth.signUp(...)
  └→ guest=false
  └→ if result.needsEmailConfirmation:
        ├→ AlertDialog (barrierDismissible: false)
        │   title: "E-postanı onayla"
        │   body : "Sana bir doğrulama linki gönderdik..."
        │   action: "Tamam" → pop
        └→ context.go(/login)        // kullanıcı doğrulama sonrası giriş yapacak
     else:
        ├→ snackbar: "Hesabın oluşturuldu. Hoş geldin!"
        └→ context.go(/)             // Splash → Feed
```

## 3. SignUpResult değişikliği

Yeni dosya: `lib/features/auth/models/sign_up_result.dart`
```dart
class SignUpResult {
  const SignUpResult({
    required this.user,
    required this.needsEmailConfirmation,
  });
  final AuthUser user;
  final bool needsEmailConfirmation;
}
```

Interface: `AuthRepository.signUp` artık `Future<SignUpResult>` döner (önce `Future<AuthUser>`).

Implementor: `SupabaseAuthRepository.signUp`:
```dart
final res = await _client.auth.signUp(...);
final user = res.user;
if (user == null) throw Exception('Kayıt tamamlanamadı.');
return SignUpResult(
  user: _from(user)!,
  needsEmailConfirmation: res.session == null,
);
```

`mailer_autoconfirm` farklı session/user kombinasyonları:

| Senaryo | `res.user` | `res.session` | `needsEmailConfirmation` |
|---|---|---|---|
| Auto-confirm ON | dolu | dolu | `false` |
| Auto-confirm OFF | dolu | **null** | **true** |
| Beklenmedik (user null) | null | — | exception ('Kayıt tamamlanamadı.') |

## 4. CreateProfileScreen davranışı

`lib/features/profile/screens/create_profile_screen.dart` `_save` metodu:
- `auth.signUp(...)` çağrısı `SignUpResult` değişkenine alınır.
- `guest=false` her durumda set edilir (form gönderildiği için kullanıcı niyetli).
- `needsEmailConfirmation` → `AlertDialog` + `context.go(AppRoutes.login)`.
  - Dialog `barrierDismissible: false` → kullanıcı dışına tıklayıp atlayamaz; bilgi mesajını görmek zorunda.
- `else` → mevcut snackbar + `context.go(AppRoutes.splash)` akışı korunur.

Yeni AppStrings (`lib/core/constants/app_strings.dart`):
```dart
authEmailConfirmTitle = 'E-postanı onayla';
authEmailConfirmBody  = 'Sana bir doğrulama linki gönderdik. Gelen kutunu kontrol et ve linke tıkladıktan sonra giriş yapabilirsin.';
authEmailConfirmOk    = 'Tamam';
```

## 5. Login tarafı

`lib/features/auth/utils/auth_error_translator.dart` zaten:
```dart
if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
  return 'E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et.';
}
```
Dokunulmadı. Kullanıcı linki tıklamadan login denerse temiz Türkçe mesaj alır.

## 6. Tests

### 6.1 Eklenen — `test/auth_signup_confirmation_test.dart`

`_ConfigurableFakeAuthRepository` ile kontrak doğrulanır:

| Test | Beklenti |
|---|---|
| `session var → needsEmailConfirmation=false` | Auto-confirm ON simülasyonu, flag `false` |
| `session null → needsEmailConfirmation=true` | Auto-confirm OFF simülasyonu, flag `true` |
| `SignUpResult immutable construction` | user + flag ctor'da doğru atanır |

### 6.2 Güncellenen — `test/auth_provider_reactive_test.dart`

`_FakeAuthRepository.signUp` signature `Future<SignUpResult>` döner (gövdesi hâlâ `UnimplementedError`; çağrılmıyor).

### 6.3 Atlanmayanlar

`CreateProfileScreen` widget testi: ProviderScope override + `GoRouter` + `SharedPreferences` mock + `auth.signUp` fake davranışı kurulumu kapsam yarattığı için bu PR'da eklenmedi. Manuel smoke (§7) buna karşılık gelir. Eksiklik raporda açıkça not.

### 6.4 Sonuçlar

- `flutter analyze --no-pub` → **No issues found**
- `flutter test --no-pub` → **257/257 passed** (254 → 257; 3 yeni `auth_signup_confirmation_test.dart`)

## 7. Manual smoke adımları

Cihazda `flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` ile yeni APK kurulduktan sonra:

1. **Yeni rastgele e-posta ile signup** (henüz var olmayan).
   - Profil Oluştur → bilgiler + şifre + yasal kabul → Kaydet.
   - **Beklenti:** "E-postanı onayla" başlıklı dialog açılır (barrier disabled), gövde Türkçe.
   - **Beklenti:** "Tamam" tıklanır → Login ekranına yönlendirilir.
   - **Beklenti:** "Profil oluşturuldu" snackbar'ı GÖRÜNMEZ.
   - **Beklenti:** Feed/Splash'a gidilmez.

2. **E-posta linki tıklanmadan login denemesi**:
   - Login ekranına aynı e-posta + şifre gir.
   - **Beklenti:** "E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et." snackbar'ı.
   - **Beklenti:** Feed'e geçiş yok.

3. **E-posta linki tıkla → tekrar Login**:
   - Doğrulama linkine tıklanır.
   - Aynı e-posta + şifre ile Login.
   - **Beklenti:** Splash → Feed; tab'lar çalışır; `AuthRequiredGuard.canWrite()` true.

4. **Regression — Auto-confirm açık olsaydı (bu projede şu an kapalı, sentetik kontrol)**:
   - Bu yol sadece dashboard'da auto-confirm açılırsa test edilebilir. Kapsam dışı.

## 8. Files changed

```
lib/core/constants/app_strings.dart                              (3 yeni string)
lib/features/auth/models/sign_up_result.dart                     (yeni)
lib/features/auth/repositories/auth_repository.dart              (signUp signature)
lib/features/auth/repositories/supabase_auth_repository.dart     (session null check)
lib/features/profile/screens/create_profile_screen.dart          (dialog + login route)
test/auth_provider_reactive_test.dart                            (fake signature)
test/auth_signup_confirmation_test.dart                          (yeni — 3 test)
```

## 9. Things not done

- DB migration yok.
- Storage yok.
- Dependency yok.
- Supabase Dashboard ayarı (`mailer_autoconfirm`) değiştirilmedi — `false` kalır.
- `service_role` kullanılmadı.
- `.env.local` / `.env.admin.local` değerleri yazdırılmadı.
- Release AAB alınmadı.
- Fatih hesabına dokunulmadı.
- Push yapılmadı — commit hazır, sen onaylayınca push.
- `CreateProfileScreen` widget testi PR scope dışı (router + provider setup karmaşası).
