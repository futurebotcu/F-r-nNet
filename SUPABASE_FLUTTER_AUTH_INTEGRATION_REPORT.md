# FırınNet Flutter — Supabase Auth + Profile Entegrasyonu Raporu

Tarih: 2026-05-12
Kapsam: Yalnız Auth + Profile altyapısı. Fırın Paneli / Bayi / Üretim / Fire repository'leri **bu PR'da Supabase'e bağlanmadı**.

---

## 1. Eklenen Paketler

| Paket | Sürüm | Neden |
|---|---|---|
| `supabase_flutter` | ^2.5.6 (çözünen 2.12.4) | Auth + REST + Realtime client. Tek paket; ayrıca dotenv eklemedik. |

`flutter pub get` çıktısı: 34 yeni transitive paket eklendi (gotrue, postgrest, realtime_client, storage_client, shared_preferences ailesi, web_socket_channel vb.). Servis bağımlılığı yok — pure Dart.

## 2. Config Yöntemi: `dart-define`

**Karar: dart-define** (flutter_dotenv yerine).

**Gerekçe:**
- Ek paket yok (`flutter_dotenv` 5MB+ asset paketi gerektirir).
- Build-time enjekte; runtime'da dosya okuma yok → sızıntı yüzeyi daha küçük.
- CI/CD'de doğal destek: `flutter build --dart-define=…`
- IDE/launch.json'a kolayca eklenir, repo'ya commit etmeden.

**Eksiklik:** Kullanıcı her `flutter run` çağrısında flag'leri vermeli. Bunu tek seferlik VS Code `launch.json` ya da `Makefile` ile çözmek uygulamanın görevi.

**Anahtarların kaynağı:**
```
flutter run \
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```

**Hiçbir yere yazılmadı:**
- Repo, `.env`, `lib/`, README, log, markdown — temiz.
- `service_role` key kullanılmadı.
- Supabase PAT kullanılmadı.
- Database password kullanılmadı.

## 3. Değişen / Eklenen Dosyalar

**Yeni:**
- `lib/core/config/app_config.dart` — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `supabaseEnabled` getter.
- `lib/features/auth/models/auth_user.dart` — minimal value object (id, email).
- `lib/features/auth/utils/auth_error_translator.dart` — Supabase hatalarını TR'ye çevirir.
- `lib/features/auth/repositories/auth_repository.dart` — abstract.
- `lib/features/auth/repositories/supabase_auth_repository.dart` — Supabase implementasyonu.
- `lib/features/auth/providers/auth_providers.dart` — Riverpod provider'lar.
- `lib/features/auth/screens/login_screen.dart` — sade giriş ekranı.
- `lib/features/profile/repositories/profile_repository.dart` — abstract.
- `lib/features/profile/repositories/supabase_profile_repository.dart` — Supabase implementasyonu.

**Revize edilen:**
- `pubspec.yaml` — `supabase_flutter: ^2.5.6` eklendi.
- `.gitignore` — `.env`, `.env.*` exclusion (`.env.example` izinli).
- `lib/main.dart` — `AppConfig.supabaseEnabled` ise `Supabase.initialize` çağrısı.
- `lib/features/profile/providers/profile_provider.dart` — `ProfileController` artık auth state'i dinler, signed-in olunca `profiles` satırını çeker; eski `useGuest/save/clear` API'si korundu (mock test'leri bozulmadı).
- `lib/features/profile/screens/create_profile_screen.dart` — Supabase varsa şifre alanı + `AuthRepository.signUp` çağrısı (metadata sözleşmesiyle); local mode'da eski mock davranış.
- `lib/features/auth/screens/login_screen.dart` — yeni.
- `lib/features/onboarding/screens/splash_screen.dart` — auth-aware routing (`supabaseEnabled` + `currentUser` durumuna göre `/login` / `/panel` / `/onboarding`).
- `lib/features/profile/screens/profile_screen.dart` — "Profilden Çık" artık Supabase signOut + yerel clear + uygun başlangıç ekranına yönlendirme.
- `lib/app/router/app_router.dart` — `AppRoutes.login = '/login'` ve `LoginScreen` route'u.
- `lib/core/constants/app_strings.dart` — TR auth string'leri (`authLoginTitle`, `authBackendDisabled`, validation mesajları vb.).

**Hiç dokunulmayan (önemli):**
- Fırın Paneli, Bayi Yönetimi, Reçete Hesaplama, Üretim, Fire, Gün Sonu — repository'leri hâlâ local. Bu PR kapsamı dışı.
- Tüm tema (`app_theme.dart`, `app_colors.dart`, `app_tokens.dart`).
- Existing 42 test — hiçbiri değiştirilmedi.

## 4. Local / Mock Fallback Nasıl Korundu

**İkili pattern:**

| Kaynak | `supabaseEnabled = true` | `supabaseEnabled = false` |
|---|---|---|
| `authRepositoryProvider` | `SupabaseAuthRepository` | **null** |
| `profileRepositoryProvider` | `SupabaseProfileRepository` | **null** |
| `ProfileController` ctor | `authStateChanges` dinler | dinlemez, in-memory only |
| Splash sonu | `/login` veya `/panel` | `/onboarding` (eski) |
| CreateProfileScreen.save() | `auth.signUp(metadata)` | eski mock `profileController.save()` |
| LoginScreen | aktif form | "Sunucu bağlantısı yapılandırılmadı" banner'ı, giriş butonu disabled |
| Misafir akışı (`useGuest`) | Her iki modda aktif | Her iki modda aktif |

**Sonuç:** Anahtarlar verilmeden `flutter run` çağrıldığında uygulama crash etmez, eski mock akışında çalışır — geliştirici hayatına dokunulmadı.

## 5. Signup Metadata Sözleşmesi

`SupabaseAuthRepository.signUp` Supabase Auth'a şu şekli gönderir:

```dart
await client.auth.signUp(
  email: email,
  password: password,
  data: {
    'display_name'    : displayName,           // form 'Profil adı'
    'account_type'    : accountType.name,      // 'commercial' | 'individual' | 'wholesaler'
    'profession_badge': badge,                 // form 'Meslek rozeti'
    'city'            : city,                  // form 'Şehir'
  },
);
```

`avatar_url` şimdilik gönderilmiyor (storage entegrasyonu V2'ye bırakıldı). `email` ayrıca metadata'ya konmuyor — `auth.users.email`'in kendisi yetkili kaynak ve trigger profile satırına onu yazıyor.

## 6. Profile Trigger ile İlişki

- **`handle_new_user`** (Supabase tarafı): signup sonrası `public.profiles` satırını otomatik oluşturur — display_name fallback, account_type whitelist, profession_badge/city nullif+trim.
- **Client davranışı**: `SupabaseProfileRepository`:
  - `fetchProfile(userId)` — `select(...).eq('id', userId).maybeSingle()` ile okur. RLS `id = auth.uid()` policy'siyle filtrelenir.
  - `updateProfile(...)` — yalnız `display_name / account_type / profession_badge / city` alanlarını UPDATE eder. **`email` alanını yazmaz** (bilinçli).
- **`sync_profile_email`** (Supabase tarafı): kullanıcı email değiştirdiğinde — `auth.updateUser(email:)` çağrısı sonucu `auth.users.email` UPDATE triggerla profiles.email senkron olur. Client'tan `profiles.email`'e manuel yazma **yok**.

Sonuç: **Client `profiles` tablosuna INSERT etmez**, sadece SELECT + UPDATE (kendi RLS scope'unda).

## 7. Güvenlik Kontrol Listesi

| Kural | Durum |
|---|---|
| `service_role` key client'a | ❌ kullanılmadı |
| Supabase PAT client'a | ❌ kullanılmadı |
| Database password client'a | ❌ kullanılmadı |
| Hardcoded key | ❌ — dart-define ile build-time |
| `.env` repo'ya commit edilir mi | ❌ — `.gitignore` blokladı |
| RLS gevşetildi mi | ❌ — backend RLS'ine hiç dokunulmadı |
| Public/anon write | ❌ — yalnız `authenticated` policy'leri etkin (önceki migrationlardan) |
| Client'tan `profiles` INSERT | ❌ — handle_new_user trigger üstlendi |
| Email update doğrudan profiles'a | ❌ — `auth.updateUser` + sync trigger |

## 8. Test Sonucu

- `flutter analyze` → **No issues found** ✓
- `flutter test` → **42 passed, 0 failed** ✓ (8 dosya: dealer_repository, dealer_pdf_builder, dealer_share_builder, dealer_balance, feed_repository, recipe_calculator, social_group_repository, widget_test)

> Not: Auth/profile repository'lerin Supabase impl'leri için mock unit test eklenmedi; canlı Supabase client'a bağımlı oldukları için mock'lamak Supabase SDK'sının internal'ına dokunmayı gerektirir. Bunun yerine entegrasyon doğrulaması "Manuel Test" bölümünden yapılır.

## 9. Manuel Test Akışı

### 9.1 Anahtarlarla çalıştırma
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://sjeqwiqgwzagengdukye.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable_anon_key>
```

(Anon key'i `mcp__supabase__get_publishable_keys` veya Supabase dashboard'tan al — repo'ya yazma.)

### 9.2 Yeni kullanıcı kaydı
1. Uygulamayı yukarıdaki komutla aç.
2. Splash → **/login** ekranına düşer (oturum yok).
3. **Profil Oluştur** linkine tıkla.
4. Formu doldur:
   - Hesap türü: **Ticari**
   - Profil adı: **Ahmet Usta**
   - Şehir: **Konya**
   - E-posta: ahmet@firinnet.local
   - Şifre: en az 6 karakter
   - Meslek rozeti: Usta Fırıncı
5. **Kaydet** → Snackbar "Hesabın oluşturuldu", **/panel** açılır.

### 9.3 Backend doğrulaması (Supabase dashboard veya MCP)
- `auth.users` → yeni satır var, `raw_user_meta_data` = `{display_name, account_type:'commercial', profession_badge, city}`.
- `public.profiles` → aynı `id` ile satır oluşmuş (trigger), `display_name=Ahmet Usta`, `account_type=commercial`, `city=Konya`, `profession_badge=Usta Firinci`, `email=ahmet@firinnet.local`.

### 9.4 Role-based dashboard
- Profile çekildi → Panel ekranı **Ticari** kart setini gösterir (Fırın Paneli, Bayi Paneli, İlanlarım, Mesajlar).

### 9.5 Çıkış / tekrar giriş
1. Feed → header avatar tap → Profile ekranı → **Profilden Çık**.
2. Supabase signOut çağrılır + yerel state temizlenir → **/login** açılır.
3. Aynı email/şifre ile giriş yap → **/panel** açılır.
4. Profile bilgileri (Ticari, Konya, Ahmet Usta) korunmuş olmalı — trigger ilk signup'ta yarattı, fetch'te tekrar yüklendi.

### 9.6 Hata akışları
- Yanlış şifre → "E-posta veya şifre hatalı."
- Mevcut email'le tekrar signup → "Bu e-posta zaten kayıtlı. Giriş yapmayı dene."
- İnternet kapalı → "İnternet bağlantısı yok."
- Zayıf şifre → form validation "Şifre en az 6 karakter olmalı".

### 9.7 Local/mock fallback (anahtarsız çalıştırma)
```bash
flutter run
```
- Splash → **/onboarding** (eski akış, hiçbir değişiklik yok).
- "Profil Oluştur" butonu açılır, şifre alanı **yok**, eski mock davranış: in-memory profile, doğrudan /panel.
- "Kayıtsız Devam Et" → guest profile, /feed.

## 10. Sonraki Faz Önerisi

1. **Fırın Paneli repository → Supabase**: `bakeries`, `bakery_products`, `production_entries`, `recipe_calculations`, `waste_entries`, `dealer_deliveries`, `dealer_delivery_items`, `dealers` için `SupabaseXRepository` katmanları + provider seçimi (mevcut Local impl'ler yedek olarak kalır).
2. **Storage bucket**: `avatars/` — owner-scoped policy, profile ekranından upload.
3. **Realtime publication**: profile değişimlerini canlı yansıt (opsiyonel UX).
4. **Email confirm akışı**: Supabase Auth dashboard'tan email confirmation açıkken signup sonrası "E-posta onayını kontrol et" ekranı.
5. **handle_new_user advisor uyarılarını kapat**: HIBP password protection vs.

## 11. Güncel Dosya Yapısı (özet)

```
lib/
├── core/
│   └── config/
│       └── app_config.dart              ← yeni
├── features/
│   ├── auth/                            ← yeni feature dizini
│   │   ├── models/auth_user.dart
│   │   ├── providers/auth_providers.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   └── supabase_auth_repository.dart
│   │   ├── screens/login_screen.dart
│   │   └── utils/auth_error_translator.dart
│   ├── profile/
│   │   ├── models/bakery_profile.dart         (değişmedi)
│   │   ├── providers/profile_provider.dart    ← revize
│   │   ├── repositories/                       ← yeni dizin
│   │   │   ├── profile_repository.dart
│   │   │   └── supabase_profile_repository.dart
│   │   └── screens/
│   │       ├── create_profile_screen.dart     ← revize
│   │       └── profile_screen.dart            ← revize (signOut)
│   └── onboarding/screens/splash_screen.dart  ← revize (auth-aware)
├── app/router/app_router.dart                  ← revize (/login)
├── main.dart                                   ← revize (Supabase.initialize)
└── core/constants/app_strings.dart             ← revize (auth strings)
```
