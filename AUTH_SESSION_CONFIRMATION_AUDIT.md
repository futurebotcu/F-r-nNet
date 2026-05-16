# Auth / Session / Confirmation Audit

**Tarih:** 2026-05-16
**Branch:** `main` @ `595b46b`
**Tip:** Sadece araştırma. Kod değişmedi, commit yok.

---

## 1. Observed Behavior

Kullanıcı yeni bir e-posta ile **Profil Oluştur** akışını denedi:
- Form gönderildi.
- Ekranda "confirm" tarafında bir hata mesajı belirdi.
- Buna rağmen app onu Feed ekranına götürmüş gibi göründü.
- Loglarda (PID 20103, app yeniden başlatıldıktan sonra) tek anlamlı kayıt: `13:00:46 I/flutter: supabase.auth: INFO: Signing out user with scope: SignOutScope.local`.
- `signUp` HTTP isteği için **exception/AuthException/PostgrestException/4xx/5xx yok** — yani request başarılı (HTTP 200) döndü.

## 2. Runtime Session State — Supabase Auth Settings

Public endpoint `<SUPABASE_URL>/auth/v1/settings` (anon key ile) sorgulandı:

```json
{
  "external": { "email": true, ... },
  "disable_signup": false,
  "mailer_autoconfirm": false,
  "phone_autoconfirm": false,
  ...
}
```

**Kritik alan:** `mailer_autoconfirm: false`.

### Bu ne anlama gelir?

Supabase Auth dokümanı:
- `mailer_autoconfirm = true` → signUp anında `session` set edilir; kullanıcı doğrulanmış sayılır.
- `mailer_autoconfirm = false` → signUp **user oluşturur ama session VERMEZ**; kullanıcı e-postasındaki link'i tıklayana kadar `auth.users.email_confirmed_at = null`. SDK tarafında `client.auth.currentUser = null` kalır (session yok).

Yani bu projede email confirmation **AÇIK**.

## 3. Code Path

### 3.1 `SupabaseAuthRepository.signUp` (lib/features/auth/repositories/supabase_auth_repository.dart:24-43)

```dart
final res = await _client.auth.signUp(
  email: email,
  password: password,
  data: metadata,
);
final user = res.user;
if (user == null) {
  throw Exception('Kayıt tamamlandı ama oturum açılmadı.');
}
return _from(user)!;
```

- `res.user` `mailer_autoconfirm: false` durumunda **dolu döner** (yeni oluşturulmuş user objesi).
- `res.session` ise **null'dır** (confirm beklenir).
- Kod **sadece `user`'ı kontrol ediyor, `session`'ı yok sayıyor.**
- Kullanıcıya "kayıt başarılı, oturum açıldı" sinyali verir → AuthUser döner.

### 3.2 `CreateProfileScreen._save` (lib/features/profile/screens/create_profile_screen.dart:251-267)

```dart
await auth.signUp(
  email: email, password: password,
  metadata: <String, dynamic>{...},
);
await ref.read(guestModeProvider.notifier).setGuest(false);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text(AppStrings.authProfileCreatedSnack)),
);
context.go(AppRoutes.splash);
```

- signUp success kabul edilir.
- **`guest = false`** set edilir.
- "Profil oluşturuldu" snackbar'ı gösterilir.
- Splash'a yönlendirilir.

### 3.3 `SplashScreen._route` (lib/features/onboarding/screens/splash_screen.dart:42-90)

6 olası rota şartlandırılır. İlgili branş:

```dart
final user = ref.read(currentAuthUserProvider);
if (user == null) {
  if (guest) {
    ...; context.go(AppRoutes.feed);   // Route 4
  } else {
    context.go(AppRoutes.authEntry);   // Route 3
  }
  return;
}
```

- `currentAuthUserProvider` → `client.auth.currentUser`.
- `mailer_autoconfirm: false` + sadece signUp yapılmış → `currentUser == null` (session yok).
- `guest = false` (signup öncesi setGuest(false) çağrıldı).
- **Splash sevk eder: `/auth` (AuthEntryScreen).**

### 3.4 Çelişki

Kullanıcı **Feed'e gittiğini** söylüyor. Splash kodu mantığına göre `/auth`'a gitmeliydi. İki açıklama:

**Hipotez A — Email link onaylandıktan sonra auth state change:**
1. signUp → session null → Splash → AuthEntryScreen.
2. AuthEntry'de "Kayıtsız devam et" tıklandı → `guest = true` → Feed (Route 4).
3. Kullanıcı e-posta link'ini tıkladı → Supabase'in `mailer/verify` endpoint'i session set etti.
4. `authStateChanges` stream emit etti → `currentAuthUserProvider` rebuild → currentUser != null.
5. Ancak `guest = true` hâlâ — `AuthRequiredGuard.canWrite()` ilk şart `if (isGuest) return false;` → guest gibi davranmaya devam ediyor.

**Hipotez B — Manuel login:**
- Kullanıcı AuthEntry → Login ekranı → e-posta + şifre ile sign-in → session geldi → Splash → Feed.
- Bu durumda mailer_autoconfirm OFF olduğu için **email confirmation yapılmadan da sign-in mümkün** olabilir? Hayır, Supabase email_not_confirmed durumda sign-in'i 400 ile reddeder.
- Onay link'i tıklandıysa email_confirmed_at dolar, sign-in başarılı olur.

**Hipotez C — Süreçte kullanıcı "confirm hata oldu" snackbar'ı görüp sonra yeniden denedi:**
- İlk signUp 4xx-non-JSON döndü mü? Translator zaten Türkçe çevirir.
- Veya kullanıcı doğrulama linkini tıklayıp tıklamadığını karıştırmış olabilir.

Hepsi tek bir gerçeği değiştirmiyor: **`SupabaseAuthRepository.signUp` session null durumunu silent geçiştirir, kullanıcıya/akışa belirgin bir sinyal vermez.**

## 4. Root Cause

`SupabaseAuthRepository.signUp` Supabase'in iki farklı response biçimini ayırt etmiyor:
- **Auto-confirm AÇIK** → `res.user != null && res.session != null` → kullanıcı oturum açmış.
- **Auto-confirm KAPALI** → `res.user != null && res.session == null` → kullanıcı **oluşturuldu ama oturum AÇIK DEĞİL**, e-posta onayı bekleniyor.

Ek olarak `CreateProfileScreen._save`:
- "Profil oluşturuldu" snackbar'ı her durumda gösteriliyor — confirm bekliyorken yanıltıcı.
- Splash'a sevk ediyor — Splash null currentUser ile AuthEntry'ye geri atıyor → kullanıcı kayıt yaptığını sanırken AuthEntry'de buluyor → ya "Kayıtsız devam" tıklayıp guest oluyor (yazma engellenir!) ya da kafası karışıyor.

## 5. Fix Recommendation (henüz uygulanmadı)

### 5.1 Repository tarafı — `SupabaseAuthRepository.signUp`

```dart
class SignUpResult {
  const SignUpResult({required this.user, required this.needsEmailConfirmation});
  final AuthUser user;
  final bool needsEmailConfirmation;   // true ise session yok
}

Future<SignUpResult> signUp(...) async {
  final res = await _client.auth.signUp(...);
  final user = res.user;
  if (user == null) throw Exception('Kayıt tamamlanamadı.');
  return SignUpResult(
    user: _from(user)!,
    needsEmailConfirmation: res.session == null,
  );
}
```

`AuthRepository` interface signature güncellenir; mevcut callerlar (CreateProfileScreen) `needsEmailConfirmation`'a göre davranır.

### 5.2 UI tarafı — `CreateProfileScreen._save`

```dart
final result = await auth.signUp(...);
await ref.read(guestModeProvider.notifier).setGuest(false);

if (result.needsEmailConfirmation) {
  // Kullanıcıya açık bilgi + login ekranına yönlendir.
  if (!mounted) return;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('E-postanı onayla'),
      content: Text(
        '$email adresine bir doğrulama linki gönderdik. '
        'Linki tıkladıktan sonra giriş yapabilirsin.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(_).pop(),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  if (!mounted) return;
  context.go(AppRoutes.login);
  return;
}

// Session geldi → Splash'a (Feed'e) gider.
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text(AppStrings.authProfileCreatedSnack)),
);
context.go(AppRoutes.splash);
```

### 5.3 Login tarafı — `email_not_confirmed` zaten translator'da var

`auth_error_translator.dart:15-17` zaten:
```dart
if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
  return 'E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et.';
}
```
Yani onay yapmayan kullanıcı login denerse temiz mesaj alır.

### 5.4 Alternatif (operasyonel karar)

Eğer V1 launch için kullanıcı sürtünmesini minimize etmek istenirse:
- Supabase Dashboard → Authentication → Providers → Email → **"Confirm email" toggle'ını KAPAT** → `mailer_autoconfirm = true`.
- Kod tarafı dokunulmaz; signUp anında session gelir.
- Trade-off: e-posta sahteliği doğrulanmaz; spam/throwaway hesaplar daha kolay.

V1 için tavsiye edilen yol: **Confirm AÇIK kalsın + kod fix uygulansın** (5.1 + 5.2). Çünkü:
- Hesap silme akışı zaten gerçek (delete-account Edge function).
- Job messaging / dealer / vb. işlemler kötüye kullanılırsa e-posta sahteliği problem olur.
- UX kaybı: kayıt anında bir alert + login ekranına yönlendir → 5 saniyelik ekstra adım.

## 6. Tests Needed

- Unit / widget test: `SupabaseAuthRepository.signUp` mock'lanmış SDK ile:
  - `session != null` senaryosu → `needsEmailConfirmation = false`.
  - `session == null` senaryosu → `needsEmailConfirmation = true`.
- Widget test: `CreateProfileScreen` confirm-required senaryosunda alert + login route'a sevk.
- Live smoke: yeni rastgele e-posta ile signup → alert görünür → e-posta onayı → login → Feed'e ulaşır.

## 7. Sorulara Net Karar

| Soru | Cevap |
|---|---|
| Kayıt sonrası session var mı? | **Hayır** — Supabase ayarı `mailer_autoconfirm: false`, signUp `session: null` döner. |
| Session yoksa app neden Feed'e gidiyor? | Splash kodu Feed'e değil **`/auth`'a** gönderir. Kullanıcının Feed'e ulaşmış olması ya (a) AuthEntry'den "kayıtsız devam et" → guest + Feed, ya da (b) e-posta link'i onaylandıktan sonra auth state change ile session geldi + manuel login. Mevcut kod akışı bu kavşağı kullanıcıya **şeffaf bildirmiyor**. |
| Kullanıcı aslında auth mı, guest mi? | **Belirsiz** — runtime'da ekran kontrolü gerekir. Eğer Feed'de "post beğen → AuthRequiredSheet" çıkıyorsa guest, çıkmıyorsa auth. |
| Email confirmation gerekiyorsa UI ne göstermeli? | Açık alert: "Gelen kutuna doğrulama linki gönderildi. Linki tıkla, sonra giriş yap." + Login ekranına yönlendir. |
| "Confirm hata ama giriş oldu" gerçek login mi, yanlış route mu? | Büyük olasılıkla **yanlış route + sessiz session yokluğu**. Kullanıcı "giriş oldu" sandı çünkü Feed gördü, ama session yokken AuthRequiredGuard yazma aksiyonlarını engelliyor. |
| Fix gerekli mi? | **Evet** — Section 5.1 + 5.2. Bu PR'da uygulanmadı; rapor ilk. |

## 8. Things Not Done

- Kod değişmedi.
- Migration yok.
- Commit/push yok.
- `service_role` kullanılmadı.
- `.env.local` değerleri yazdırılmadı.
- Fatih hesabına dokunulmadı.
- Hesap silme yapılmadı.
- Supabase Dashboard ayarı değiştirilmedi.
