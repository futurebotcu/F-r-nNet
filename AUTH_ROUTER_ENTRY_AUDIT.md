# AUTH_ROUTER_ENTRY_AUDIT

**Tarih:** 2026-05-13
**Tür:** Read-only audit — kod değişikliği yok, sadece bu rapor dosyası yazıldı.
**Kapsam:** Splash → Onboarding / Login / Create-Profile / Panel akışı; auth + profile provider'lar; rol bazlı dashboard'a geçiş.
**Yöntem:** `splash_screen.dart`, `onboarding_screen.dart`, `login_screen.dart`, `create_profile_screen.dart`, `auth_providers.dart`, `profile_provider.dart`, `app_router.dart` okundu.

---

## 1. Boot akışı (Splash → ?)

**Dosya:** `lib/features/onboarding/screens/splash_screen.dart` (l.27-40)

```dart
void _route() {
  if (!AppConfig.supabaseEnabled) {
    context.go(AppRoutes.onboarding);          // Supabase yok
    return;
  }
  final user = ref.read(currentAuthUserProvider);
  if (user != null) {
    context.go(AppRoutes.panel);               // Oturum var
  } else {
    context.go(AppRoutes.login);               // Oturum yok
  }
}
```

1300 ms splash, sonra **3 dallı karar**:

| Durum | Hangi route'a gidiyor |
|---|---|
| `AppConfig.supabaseEnabled == false` | `/onboarding` |
| `supabaseEnabled == true` **&&** `currentAuthUser != null` | `/panel` |
| `supabaseEnabled == true` **&&** `currentAuthUser == null` | `/login` |

> `AppConfig.supabaseEnabled` getter `supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty` ile çalışır (`lib/core/config/app_config.dart` l.15-16). dart-define geçtiysen `true`.

---

## 2. State → ekran haritası (her olası kombinasyon)

| # | Senaryo | Splash kararı | Sonraki ekran | UX |
|---|---|---|---|---|
| 1 | **Temiz kurulum + Supabase dart-define + oturum yok** ← *şu anki durum* | `/login` | **LoginScreen** | 3 buton |
| 2 | Supabase + oturum var (önceki signIn) | `/panel` | **RoleDashboardScreen** | Profile yüklenir, rol kartları |
| 3 | Supabase + oturum var + profile DB'de yok | `/panel` | RoleDashboardScreen — profile null → `AccountType.individual` fallback (`role_dashboard_screen.dart` l.29) | Hero strip'te "Profil oluşturmadın" + "Oluştur" linki |
| 4 | dart-define YOK (Supabase disabled) | `/onboarding` | **OnboardingScreen** | 2 buton (Profil Oluştur + Kayıtsız) |
| 5 | "Kayıtsız Devam Et" tıklandı (guest) | `useGuest()` + `context.go('/feed')` | **FeedScreen** | profile = `BakeryProfile.guest` |
| 6 | LoginScreen'de "Profil Oluştur" tıklandı | push `/profile/create` | **CreateProfileScreen** | Supabase varsa signUp, yoksa local |
| 7 | LoginScreen'de signIn başarılı | `context.go('/panel')` | RoleDashboardScreen | ProfileController auth stream'i dinler |
| 8 | Onboarding'de "Profil Oluştur" tıklandı | push `/profile/create` | CreateProfileScreen | — |
| 9 | Profile screen'de "Çıkış" | signOut + `context.go(supabaseEnabled ? '/login' : '/onboarding')` | Login veya Onboarding | profile.clear() |

---

## 3. Her giriş ekranındaki butonlar (kanıtlı)

### LoginScreen (`/login`) — `lib/features/auth/screens/login_screen.dart`

3 aksiyon, **3'ü de görünür**:

| Buton | Stil | Eylem | Koşul |
|---|---|---|---|
| 1. **Giriş Yap** (`AppStrings.authSignInButton`) | `AppPrimaryButton` (büyük copper CTA, l.188-192) | `_signIn()` → `signInWithPassword` → `/panel` | Email+şifre alanı + `supabaseOn=true` |
| 2. **Profil Oluştur** (`AppStrings.authSignUpButton`) | `TextButton`, secondary metin (l.194-205) | push `/profile/create` | Daima aktif |
| 3. **Kayıtsız Devam Et** (`AppStrings.continueAsGuest`) | `TextButton`, muted metin (l.206-222) | `useGuest()` + `context.go('/feed')` | Daima aktif |

**Önemli koşul:** Eğer `supabaseOn == false` ise (`authRepositoryProvider` null), o zaman:
- Üstte sarı **uyarı banner'ı** çıkar (`AppStrings.authBackendDisabled` — "Sunucu bağlantısı yapılandırılmadı — bu sürümde yalnız misafir modu çalışır.", l.134-161)
- Email + şifre alanları **disabled**
- "Giriş Yap" butonu **görünür ama tıklanamaz** (onPressed: null, l.191)
- "Profil Oluştur" + "Kayıtsız Devam Et" hâlâ tıklanabilir

### OnboardingScreen (`/onboarding`) — yalnız Supabase DISABLED mod

| Buton | Stil | Eylem |
|---|---|---|
| **Profil Oluştur** | `AppPrimaryButton` (büyük CTA) | push `/profile/create` |
| **Kayıtsız Devam Et** | `TextButton` muted | `useGuest()` + go `/feed` |

> **"Giriş Yap" yok.** Çünkü buraya gelmek için zaten Supabase disabled (anahtarsız) mod gerekiyor; giriş yapacak backend yok.

### CreateProfileScreen (`/profile/create`)

- 1 buton: **Kaydet / Profil Oluştur**
- Supabase varsa `signUp(email, password, metadata)` çağrılır → `handle_new_user` trigger profili oluşturur → `/panel`
- Supabase yoksa local profile state'i güncellenir → `/panel`

---

## 4. Şu anki ekran beklenen mi?

**Evet.** Senaryo #1:
- `adb shell pm clear` → tüm app data + Supabase oturumu temizlendi
- `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` ile başlatıldı → `AppConfig.supabaseEnabled = true`
- `Supabase init completed` logu doğruluyor
- Oturum yok → splash → **`/login`**

Login ekranında olman gerekiyor ve **"Giriş Yap" CTA üstte görünmeli**. Eğer görünmüyorsa:
- LoginScreen'in üstünde sarı uyarı banner'ı var mı?  
  → Varsa: `authRepositoryProvider` null dönmüş demektir → `AppConfig.supabaseEnabled` runtime'da false → muhtemelen dart-define hatalı geçildi.
- Banner yok ve "Giriş Yap" hâlâ yok mu?  
  → Bu yalın koddan çıkmıyor; ekrandaki render başka bir şey (örn. eski Onboarding ekranı kaldıysa) — bu durumda gerçek ekran tarif gerekli.

---

## 5. Daha önce farklı ekranlar görmüş olabilmenin nedenleri

| Geçmiş gözlem | Olası neden |
|---|---|
| "Onboarding gibi Profil Oluştur + Kayıtsız Devam Et gördüm, Giriş Yap yoktu" | `AppConfig.supabaseEnabled == false` (dart-define geçilmemiş) → Splash `/onboarding`'e gitmiş. Senaryo #4. |
| "Feed'e otomatik düştü" | Önceki oturumda **Kayıtsız Devam Et** seçildi → `useGuest()` → guest profile + `/feed`. Senaryo #5. |
| "Direkt Panel açıldı" | Eski oturum cache'i hâlâ Supabase tarafında geçerliydi → `currentAuthUser != null` → Splash `/panel`. Senaryo #2. |
| "Profil oluşturma ekranı açıldı" | LoginScreen veya Onboarding'den "Profil Oluştur" linki push'landı. Senaryo #6/#8. |
| "Tamamen boş/eski tasarım" | Eski (V1.0/V1.1) build emülatörde kalmıştı, `pm clear` öncesi yeni install yapılmamıştı. |

**Şu anki temiz durumda hiçbiri uygulanmıyor** → senaryo #1 → LoginScreen.

---

## 6. Bug var mı?

**Hayır, akış kod tarafında tutarlı.** Üç farklı entry ekranı var (Login / Onboarding / CreateProfile) çünkü üç farklı state senaryosu var:

| Ekran | Hangi state için | Hangi koşulda kullanıcı görür |
|---|---|---|
| LoginScreen | Backend hazır + oturum yok | Standart ilk açılış (Supabase dart-define varken, ilk açılış / signOut sonrası) |
| OnboardingScreen | Backend hazır değil | Sadece anahtarsız build (`flutter run` ile dart-define geçilmediğinde) |
| CreateProfileScreen | Yeni kullanıcı | Login veya Onboarding'den push ile |

Bunlar **tasarım** — bug değil. Tek bir ekran yerine state'e duyarlı 3 ekran var; bu çok normal.

---

## 7. UX gap'leri (bug değil ama iyileştirilebilir)

| Gap | Etki | Önem |
|---|---|---|
| **OnboardingScreen'de "Giriş Yap" link'i yok** | Supabase-off modda kullanıcı login'e dönemez (zaten backend yok, mantıklı ama future-proof değil) | Düşük |
| **LoginScreen'de "Şifremi unuttum" yok** | Şifresini unutmuş kullanıcı manuel reset yapamıyor | Orta |
| **LoginScreen'de "Hesap doğrulama" akışı yok** | Yeni signUp sonrası email confirmation gerekirse kullanıcı sıkışır | Orta — Supabase confirm-email ayarı kapalıysa sorun yok |
| **`/panel`'e profile olmadan girilebiliyor (senaryo #3)** | RoleDashboardScreen profile null → `individual` fallback gösterir; kullanıcı kart push'larında profil eksikse ekranlarda anonim deneyim | Düşük — handle_new_user trigger çoğu durumda profili oluşturuyor |
| **Splash 1300 ms sabit gecikme** | Test/UX için yavaş hissedilebilir; hızlı geçişi engelliyor | Düşük |
| **`useGuest()` sonra `/feed`'e gidiyor; rol bazlı kart hiç görmemiş olabiliyor** | Guest kullanıcı paneli hiç görmüyor; UX akışı tek yön (Feed) | Orta — guest için Panel tab'ı yine de erişilebilir, sadece auto-route Feed'e |

---

## 8. Temiz kurulumda beklenen davranış (özet)

```text
1. App açılır → Splash (1.3s)
2. dart-define ile SUPABASE_URL + SUPABASE_ANON_KEY geçtin
3. supabaseEnabled = true; currentAuthUser = null  (pm clear sonrası)
4. Splash → /login
5. LoginScreen görünür:
   ┌────────────────────────────┐
   │   [🔥]                     │
   │   Giriş Yap                │  ← başlık
   │   FırınNet — Fırıncının…   │  ← alt yazı
   │                            │
   │   ┌──── E-posta ────────┐  │
   │   │ firin@ornek.com     │  │
   │   └─────────────────────┘  │
   │   ┌──── Şifre ──────────┐  │
   │   │ ********            │  │
   │   └─────────────────────┘  │
   │                            │
   │   [   Giriş Yap   ]        │  ← AppPrimaryButton (copper)
   │      Profil Oluştur        │  ← TextButton
   │      Kayıtsız Devam Et     │  ← TextButton
   └────────────────────────────┘
```

Eğer ekranda **bu üç buton mevcutsa** → davranış doğru, panel testine devam edebilirsin.

Eğer **"Giriş Yap" yoksa veya disabled görünüyorsa** → tek olası neden dart-define'ların runtime'a geçmemiş olması:
- LoginScreen üstünde sarı uyarı banner'ı varsa kanıtlanır
- Bu durumda fix: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` syntax'ını doğrula (PowerShell'de backtick line-continuation'ları `` ` `` doğru olmalı, boş satır olmamalı)

---

## 9. Cevaplar

> **Temiz kurulumda beklenen ilk ekran ne?**

`/login` — LoginScreen. Senaryo #1.

> **Oturum varsa beklenen ekran ne?**

`/panel` — RoleDashboardScreen. Profile yüklenir (varsa).

> **Profil yoksa beklenen ekran ne?**

`/panel` — RoleDashboardScreen, profile null fallback ile `AccountType.individual` rol kartlarını gösterir. Hero strip'te "Profil oluşturmadın → Oluştur" linki var.

> **Kayıtsız devam varsa beklenen ekran ne?**

`/feed` — `useGuest()` çağrılır, profile = `BakeryProfile.guest`, bottom nav görünür. Kullanıcı Panel tab'ına manuel geçebilir (orada individual kartları görür).

> **Şu an bir bug var mı, yoksa normal state farkı mı?**

**Normal state farkı.** Splash 3 dallı karar veriyor; senin gördüğün farklı ekranlar farklı boot state'lerinin sonucu. Şu anki temiz durumda LoginScreen göstermesi doğru.

> **Gerekirse minimum fix önerisi ne?**

Şu an için fix gerekmiyor. Kullanıcı manuel test akışı:
1. `pm clear` ✅ yapıldı
2. dart-define ile run ✅ yapıldı
3. Splash → /login bekleniyor
4. **Eğer "Giriş Yap" görüyorsan** → fatihkartal75@gmail.com ile signIn dene → /panel'e gitmeli
5. **Eğer "Giriş Yap" yoksa veya disabled** → ekrandaki sarı banner'ı kontrol et; varsa dart-define geçmemiştir, syntax düzelt
6. **Eğer ekran tarif "Onboarding" diyorsa** → `AppConfig.supabaseEnabled` runtime'da false demektir → dart-define geçilmemiş; flutter run komutunu yeniden çalıştır

---

## 10. İsteğe bağlı V2 iyileştirmeleri (acil değil)

> Brief "minimum fix" diyor — şu an gerek yok, ama listeyelim:

1. **OnboardingScreen'e "Zaten hesabım var → Giriş Yap" link'i** (Supabase off modda dahi mantıksal yer).
2. **LoginScreen'e "Şifremi unuttum" link'i** → `auth.resetPasswordForEmail()` çağrısı.
3. **Splash gecikmesini event-driven yap**: `authUserStreamProvider` ilk emit'i bekle, sonra route. 1300 ms sabit yerine "init complete" sinyalini bekle.
4. **`/panel`'e profile-eksik koşulu ile redirect**: profile null + currentAuthUser var → otomatik `/profile/create`. Şu an manuel "Oluştur" linki var.

---

**Sonuç:** Auth + router entry akışı **temiz ve tutarlı**. Şu anki ekran (LoginScreen) beklenen davranış. Önce ekrandaki butonları tarif et — "Giriş Yap" CTA üstte mi? Sarı uyarı banner'ı var mı? Cevaba göre ya signIn akışına geçeriz ya da dart-define syntax'ı doğrularız.
