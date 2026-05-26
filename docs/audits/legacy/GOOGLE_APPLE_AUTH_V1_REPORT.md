# Google + Apple Sign-In — V1 Code Drop Report

**Tarih:** 2026-05-16
**Branch:** `main` @ önceki HEAD `bae8eab`
**Tip:** Kod tarafı tamamen hazır; gerçek çalışması için **dashboard ve provider tarafında manuel setup gerekir** (bkz. §10).

---

## 1. Executive Summary

V1 auth deneyimini sadeleştirmek için **Google ile devam et** (tüm platformlar) ve **Apple ile devam et** (iOS-only) butonları AuthEntryScreen + LoginScreen'in üstüne yerleştirildi. Email/şifre akışı, "Kayıt olmadan devam et" ve email confirmation fix korunuyor — hiçbiri bozulmadı.

Provider mimari kararı: **browser-based Supabase OAuth** (`_client.auth.signInWithOAuth(...)`). Deep link callback: `firinnet://auth-callback`. Android `AndroidManifest.xml` intent-filter, iOS `Info.plist` `CFBundleURLTypes` eklendi. Auth state change geldiğinde AuthEntry/Login ekranı `ref.listen(currentAuthUserProvider)` ile Splash'a yönlendirir.

**Çalışır hâle gelmek için yapılması gereken manuel adımlar:** §6 + §7 + §8 + §10.

## 2. Current Auth State (audit özeti)

`/auth/v1/settings` (anon key ile):
- `email: true` — aktif
- `google: false` — **Dashboard'da etkin değil**
- `apple: false` — **Dashboard'da etkin değil**
- `mailer_autoconfirm: false` — email confirmation açık (V1.4 önceki fix bunu hâlâ yakalar)

Kodda mevcut:
- `SupabaseAuthRepository` → email/password + signOut + updateEmail + resetPassword + deleteAccount.
- `AuthEntryScreen` → Giriş Yap / Hesabım yok üye ol / Kayıt olmadan devam et.
- `LoginScreen` → email + şifre form + üye ol link.
- `CreateProfileScreen` → email + şifre + role + city + badge; `_isCompletion` modu mevcut (profil eksiklik tamamlama).
- AndroidManifest: deep link YOKTU (eklendi).
- iOS Info.plist: URL scheme YOKTU (eklendi).
- Supabase Flutter `^2.5.6` → `OAuthProvider` enum + `signInWithOAuth` API + transitive `app_links` deep link delivery dahili.

## 3. Why Google + Apple

- **Friction azaltma**: V1 launch'ta yeni kullanıcı 30 saniyede üye olur (Google tek tıkla).
- **App Store gereksinimi**: Apple App Store Review Guidelines 4.8 — uygulamada Google/Facebook/Twitter gibi üçüncü taraf social login varsa "Sign in with Apple" sunulmalı. iOS sürümü Apple olmadan reddedilir.

## 4. Apple App Store Requirement Note

Apple Sign-In **iOS sürümünde zorunlu** (yalnız Google sunan iOS app reddedilir). Android'de Apple butonu **gerekmez** ve UI'da gizlidir. Bu sprint:
- iOS'ta Apple butonu üst kısımda Google'a eşdeğer konumda görünür.
- Android'de yalnız Google görünür.
- Browser-based OAuth (Apple flow Safari/WKWebView). **Native Apple Sign-In** (`sign_in_with_apple` package + iOS capability) sonraki sürümde değerlendirilebilir; App Store şu hâlinde de geçer.

## 5. Code changes

| Dosya | Değişiklik |
|---|---|
| `lib/core/config/app_config.dart` | `authRedirectUrl = 'firinnet://auth-callback'` const |
| `lib/features/auth/repositories/auth_repository.dart` | `signInWithGoogle()` + `signInWithApple()` interface |
| `lib/features/auth/repositories/supabase_auth_repository.dart` | İki yeni implementasyon — `OAuthProvider.google/apple` + `redirectTo: AppConfig.authRedirectUrl` |
| `lib/features/auth/utils/auth_error_translator.dart` | OAuth `provider_disabled` ve `cancel` durumlarına Türkçe mesaj |
| `lib/features/auth/widgets/social_auth_buttons.dart` | **Yeni** — Google + Apple (iOS-only) button group. `ValueKey('social_btn_google'/'social_btn_apple')`. iOS detect via `Theme.of(context).platform == TargetPlatform.iOS` |
| `lib/features/auth/screens/auth_entry_screen.dart` | `SocialAuthButtons` üste eklendi + `ref.listen(currentAuthUserProvider)` ile auth state change → `context.go(splash)` |
| `lib/features/auth/screens/login_screen.dart` | Aynı — social butonlar form üstünde + auth state listener |
| `lib/core/constants/app_strings.dart` | 6 yeni Türkçe string: `authContinueWithGoogle`, `authContinueWithApple`, `authSocialDivider`, `authProviderDisabled`, `authOAuthCancelled`, `authOAuthFailed` |
| `android/app/src/main/AndroidManifest.xml` | OAuth callback intent-filter (scheme `firinnet`, host `auth-callback`) |
| `ios/Runner/Info.plist` | `CFBundleURLTypes` + `firinnet` URL scheme |
| `test/auth_provider_reactive_test.dart` | Fake repo'ya `signInWithGoogle/Apple` UnimplementedError stub |
| `test/auth_signup_confirmation_test.dart` | Aynı fake stub güncellemesi |
| `test/social_auth_buttons_test.dart` | **Yeni** — 5 widget test (platform visibility, enabled state, divider) |

## 6. Supabase Dashboard Requirements (manuel — KOD ÇALIŞMAZ olmadan)

Dashboard → Authentication → URL Configuration:
- **Site URL**: `firinnet://auth-callback` (önerilen — production app deep link)
- **Additional Redirect URLs**: `firinnet://auth-callback`

Dashboard → Authentication → Providers → **Google**:
- Toggle: **ON**
- Client ID: Google Cloud Console'dan alınır (§7)
- Client Secret: Google Cloud Console'dan alınır
- Authorized Client IDs (for mobile native): boş bırakılabilir (browser flow için)

Dashboard → Authentication → Providers → **Apple**:
- Toggle: **ON**
- Service ID: Apple Developer'dan alınır (§8)
- Team ID: Apple Developer ID
- Key ID: Apple Developer Sign-In key ID
- Secret Key: Apple Developer'dan indirilen .p8 dosyasının içeriği

Hiçbiri ayarlanmadan kod tarafı butonu gösterir; tıklanınca Supabase 400 + `provider_disabled` döner → translator "Bu giriş yöntemi henüz yapılandırılmadı..." Türkçe mesajını basar. Crash yok.

## 7. Google Cloud Console Requirements

1. https://console.cloud.google.com → Project create/select.
2. APIs & Services → OAuth consent screen → External (V1 için Internal sınırlı).
3. APIs & Services → Credentials → Create credentials → **OAuth client ID**:
   - Type: **Web application** (Supabase server-side flow için; mobile native değil).
   - Authorized redirect URIs:
     - `https://<project-ref>.supabase.co/auth/v1/callback`
4. Client ID + Client Secret → Supabase Dashboard'a yapıştır.

**Android native opsiyon** (ileride native flow için): Android OAuth client ID + SHA-1 + package name `com.firinnet.firin_defter`. V1 için gerekli değil.

## 8. Apple Developer Requirements

1. https://developer.apple.com → Certificates, Identifiers & Profiles.
2. **Identifier (App ID)**: Sign In with Apple capability'sini aktif et (Runner.xcodeproj'da bundle ID için).
3. **Service ID** oluştur (web-based OAuth için):
   - Description: "FırınNet Web Auth"
   - Identifier: `com.firinnet.firin_defter.web`
   - Sign In with Apple → Configure:
     - Primary App ID: app'in App ID'si
     - Web Domain: `<project-ref>.supabase.co`
     - Return URL: `https://<project-ref>.supabase.co/auth/v1/callback`
4. **Key** oluştur: Sign In with Apple → .p8 indirilir + Key ID notlanır.
5. Service ID + Team ID + Key ID + .p8 içeriği → Supabase Dashboard Apple provider'ına yapıştır.

**iOS Xcode tarafı** (native Apple Sign-In değil, browser flow için bile):
- Xcode → Runner → Signing & Capabilities → **+ Capability** → Sign In with Apple.
- Bu olmazsa Apple browser flow hata verir.

## 9. Redirect / Deep Link Plan

```
[App] → SocialAuthButtons.signInWithGoogle()
     → SupabaseAuthRepository.signInWithOAuth(google, redirectTo: 'firinnet://auth-callback')
     → SDK launches in-app browser to https://accounts.google.com/...
     → User confirms Google sign-in
     → Browser redirects to https://<ref>.supabase.co/auth/v1/callback?code=...
     → Supabase exchanges code → builds final redirect: firinnet://auth-callback#access_token=...
     → Android intent-filter (scheme=firinnet, host=auth-callback) → MainActivity (singleTop)
     → app_links plugin (transitive of supabase_flutter) delivers Uri to Dart
     → Supabase SDK detects URL, stores session, emits authStateChanges
     → ref.listen(currentAuthUserProvider) on AuthEntry/Login ekranında → context.go(/splash)
     → Splash boot kararı: profile complete → /feed; incomplete → /profile/create (_isCompletion mode)
```

iOS akışı `firinnet://` URL scheme'in `CFBundleURLTypes`'da kayıtlı olması ile aynı şekilde tamamlanır.

## 10. UI Changes

### AuthEntryScreen
```
┌─────────────────────────────┐
│       FırınNet'e hoş geldin │
│       (subtitle text)       │
│                             │
│  [Google ile devam et]      │  ← yeni
│  [Apple ile devam et] (iOS) │  ← yeni, iOS-only
│  ─────── veya ────────      │  ← yeni divider
│  [Giriş Yap]                │  (mevcut)
│  [Hesabım yok, üye ol]      │  (mevcut)
│  [Kayıt olmadan devam et]   │  (mevcut)
│       (Yasal footer)        │
└─────────────────────────────┘
```

### LoginScreen
```
┌─────────────────────────────┐
│         [FN logo]           │
│        Giriş yap            │
│                             │
│  [Google ile devam et]      │  ← yeni
│  [Apple ile devam et] (iOS) │  ← yeni
│  ─────── veya ────────      │  ← yeni
│  Email: ___________         │
│  Şifre: ___________         │
│         Şifremi unuttum     │
│  [Giriş Yap]                │
│  Hesabın yok mu? Üye ol     │
└─────────────────────────────┘
```

Buton tasarımı:
- Google: beyaz zemin + ince border, `Icons.account_circle_rounded` (asset eklenmedi; Sprint sonrası gerçek Google G logosuyla değiştirilir).
- Apple: siyah zemin + beyaz `Icons.apple_rounded`.
- Disabled state: %55 opaklık.

## 11. Profile Completion Behavior

Mevcut `CreateProfileScreen` zaten `_isCompletion = (existing != null)` modunu destekliyor — bu modda:
- email field disabled (signed-in iken auth update gerektirir).
- şifre field gizli (`if (supabaseOn && !_isCompletion)` koşulu).
- Yasal kabul checkbox gizli (kabul signup anında alınmıştı).

Social login akışı:
1. Google/Apple tamamlanır → Supabase user oluşur (`handle_new_user` trigger profil insert eder — display_name, account_type defaults, city/badge boş).
2. Splash → `currentAuthUserProvider != null` → `fetchProfile` çağrılır → `!profile.isComplete` (city + badge boş).
3. Splash → `/profile/create` route.
4. CreateProfileScreen `_isCompletion = true` → email/şifre gizli → kullanıcı role + city + badge doldurur → `updateProfile`.
5. Splash → `/feed`.

**Hiçbir social login kullanıcısına şifre veya e-posta onayı sorulmaz.**

## 12. Error Handling

`auth_error_translator.dart` yeni durumlar:

| Hata | Mesaj |
|---|---|
| Code `provider_disabled` veya msg "provider is not enabled" | "Bu giriş yöntemi henüz yapılandırılmadı. Lütfen e-posta ile devam et." |
| Code `oauth_provider_not_supported` veya msg içeren "oauth" + "cancel" | "Giriş iptal edildi." |
| Mevcut: `AuthRetryableFetchException` (5xx/network) | "Sunucuya ulaşılamadı. Birkaç saniye sonra tekrar dene." |
| Mevcut: `AuthUnknownException` ("Failed to decode error response", yanlış URL) | "Sunucu bağlantısı yapılandırılamadı..." |

Raw SDK / İngilizce mesaj UI'a basılmaz.

## 13. Tests

- `flutter analyze --no-pub` → **No issues found**
- `flutter test --no-pub` → **262/262 passed** (önceki 257 + 5 yeni `social_auth_buttons_test.dart`)
- Yeni test kapsamı:
  - iOS modunda Google + Apple birlikte görünür.
  - Android modunda yalnız Google görünür, Apple gizli.
  - `authRepositoryProvider` null → butonlar disabled.
  - iOS + Supabase aktif → her iki buton enabled.
  - Compact=false → "veya" divider metni görünür.
- Mevcut testler (auth_provider_reactive_test, auth_signup_confirmation_test) yeni fake stub'larla uyumlu, regression yok.
- AuthEntry/Login widget testleri eklenmedi (router + ProviderScope + go_router setup karmaşası; manuel smoke buna karşılık).

## 14. Manual Smoke Runbook

### Android — Google ile devam et
1. APK rebuild (`dart-define` `SUPABASE_URL`/`SUPABASE_ANON_KEY` ile).
2. Emülatöre kur, app aç → AuthEntryScreen.
3. "Google ile devam et" tap.
   - **Eğer Dashboard'da provider OFF (mevcut durum)**: "Bu giriş yöntemi henüz yapılandırılmadı. Lütfen e-posta ile devam et." snackbar.
   - **Eğer Dashboard ON**: browser açılır → Google sign-in → callback → app foreground'a döner → Splash → Feed veya CreateProfile (_isCompletion).
4. Mevcut Google user: doğrudan Feed.
5. Yeni Google user: CreateProfile (_isCompletion mode) → role/city/badge doldur → Feed.

### iOS — Apple ile devam et
(Android emülatörde test edilemez. Cihaz/simulator gerekir.)
1. iOS app build → AuthEntry'de Apple butonu görünür.
2. Apple tap → Apple sign-in sheet → callback → Splash.

### Guest / email akışları (regression)
1. "Kayıt olmadan devam et" hâlâ çalışır → Feed (guest).
2. "E-posta ile giriş yap" → Login → social butonlar üstte, email form altta.
3. Yeni e-posta ile üye ol → "E-postanı onayla" dialog → Login (email confirmation fix korundu).

### Snackbar/UI sağlamlığı
- `service_role` / hardcoded JWT yok (grep temiz).
- `_noop` / boş `onPressed: () {}` / `onTap: () {}` `lib/features/auth` + `lib/features/profile` altında yok.
- Raw "Failed to decode" / İngilizce hata mesajı görünmez (translator yakalar).

## 15. Remaining Manual Setup

| Sıra | Görev | Kim |
|---|---|---|
| 1 | Google Cloud Console: OAuth Client ID (Web) + redirect URI | Sen |
| 2 | Supabase Dashboard → Auth → URL Configuration → Site URL + Additional Redirect (`firinnet://auth-callback`) | Sen |
| 3 | Supabase Dashboard → Auth → Providers → Google: ON + Client ID + Secret | Sen |
| 4 | Apple Developer: Service ID + Sign-In key + .p8 indir | Sen (iOS launch öncesi) |
| 5 | Supabase Dashboard → Auth → Providers → Apple: ON + Service ID + Team ID + Key ID + .p8 | Sen |
| 6 | Xcode → Runner → Signing & Capabilities → Sign In with Apple | Sen (iOS launch öncesi) |
| 7 | Cihazda Android Google smoke (1-5) | Sen |
| 8 | iOS device/simulator smoke (Apple flow) | Sen (iOS launch öncesi) |

§1-3 olmadan Android Google butonu tıklandığında yumuşak hata (Türkçe snackbar) görünür. §4-6 olmadan iOS Apple butonu tıklandığında aynı şekilde Türkçe snackbar; crash yok.

## 16. Things Not Done

- **Yeni dependency eklenmedi** (`sign_in_with_apple`, `google_sign_in` — native flow Sprint sonrası).
- DB migration yok.
- Storage yok.
- Supabase Dashboard ayarı **değiştirilmedi** — manuel setup §15.
- `service_role` kullanılmadı.
- `.env.local` / `.env.admin.local` değerleri yazdırılmadı.
- Fatih hesabına dokunulmadı.
- Release AAB alınmadı.
- Email/şifre akışı + "Kayıt olmadan devam et" + email confirmation fix **dokunulmadı**.
- Google asset (gerçek G logosu PNG/SVG) eklenmedi — `Icons.account_circle_rounded` placeholder; ileride asset değişimi tek satır.
- iOS device/simulator olmadığı için iOS smoke ben tarafından yapılmadı (manuel kontrol §14 listede).
- AuthEntry/Login widget testleri kapsam dışı; SocialAuthButtons widget testi + manuel smoke yeterli.
- Commit hazırlandı ama **push yapılmadı**.
