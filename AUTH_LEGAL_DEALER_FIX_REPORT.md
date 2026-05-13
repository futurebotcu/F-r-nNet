# V1.3.5 — Auth + Legal + Dealer Stabilizasyon Sprint Raporu

**Tarih:** 2026-05-13
**Versiyon:** V1.3.5
**Sprint kapsamı:** 4 madde — Bayi bug fix, Login post-redirect, Şifremi unuttum, Yasal metin + signup checkbox.
**Önceki audit:** [AUTH_ENTRY_LEGAL_AND_DEALER_AUDIT.md](AUTH_ENTRY_LEGAL_AND_DEALER_AUDIT.md)

---

## 1. Bayi Eklenmiyor Bug Fix (P0)

### Kök neden
`SupabaseDealerRepository.upsertDealer` içinde `AddDealerScreen`'in ürettiği client-side ID'ler (`d_<microseconds>`, örn. `d_1778669329154623`) doğrudan `dealers.id uuid` kolonuna `eq` filter olarak gönderiliyordu. Postgres `22P02 invalid input syntax for type uuid` döndürüyor, INSERT bile denenmeden hata veriyordu.

### Düzeltme
**`lib/features/dealers/repositories/supabase_dealer_repository.dart`**
- Statik regex `_uuidPattern` + public test API `looksLikeUuid` eklendi.
- `upsertDealer` non-uuid ID için doğrudan `INSERT` çalıştırıyor; payload'tan `'id'` çıkarılarak server `gen_random_uuid()` default'una bırakıyor (DB schema değişmedi).
- UUID formatındaki ID için eski path korundu: `eq` lookup → INSERT veya UPDATE.

**`lib/features/dealers/screens/add_dealer_screen.dart`**
- `repo.upsertDealer(...)` çağrısı try/catch ile sarıldı. Backend hatası kullanıcıya Türkçe snackbar olarak gösteriliyor: "Bayi kaydedilemedi. Lütfen tekrar deneyin."

### Test
**`test/dealer_uuid_handling_test.dart`** — 5 test:
- UUID v4 (lowercase + uppercase hex) → true
- `d_<microseconds>` → false
- `d_hamdi`, `d_pasif` (seed) → false
- Boş / random text → false
- Tire eksik / hex olmayan karakter → false

Tüm testler **PASS**. Branching mantığı validator üzerinden test edildi (Supabase client mock'ı yerine pure validator yaklaşımı).

### Schema garantisi
Hiçbir migration / RLS / policy değişikliği yapılmadı. `dealers.id uuid DEFAULT gen_random_uuid()` zaten vardı; client artık o default'a güveniyor.

---

## 2. Login → /feed Redirect

### Karar
Brief gereği: Login + complete profile akışından sonra ilk ekran sektörle bağ kuran **Feed** olmalı, hesap-yönetim yüzü olan **Panel** değil. Panel bottom nav 5. tab üzerinden tek tıkla erişilebilir.

### Düzeltme
**`lib/features/onboarding/screens/splash_screen.dart`** — Senaryo 5 (`supabaseEnabled + user!=null + profile complete`):
```dart
// V1.3.5 — Login sonrası ilk açılış Feed (sektör akışı). Panel'e
// bottom nav 5. tab'dan ulaşılır. Brief ürün kararı.
context.go(AppRoutes.feed);
```

Önceki davranış (`AppRoutes.panel`) değiştirildi. Senaryo 6 (incomplete profile → `/profile/create`) ve diğer senaryolar (guest/no-auth) korundu.

### Bottom nav koşulu
Panel tab'ı `BottomNavBar`'da kayıtlı; herhangi bir guard değişmedi. Kullanıcı feed'den panel'e bottom nav 5. ikon ile ulaşır.

---

## 3. Şifremi Unuttum Akışı

### Strateji (V1)
Supabase email link → Supabase'in default web sayfasına yönlendirir → kullanıcı orada yeni şifresini belirler. Mobile in-app deep link + `UpdatePasswordScreen` akışı sonraki faza bırakıldı (kapsam dışı).

### Yeni dosyalar
**`lib/features/auth/screens/forgot_password_screen.dart`**
- E-posta input (validator: boş + format)
- "Reset Link Gönder" `AppPrimaryButton`
- Başarı state'i: yeşil onay kartı + "Mailini kontrol et" mesajı
- Backend off banner (Supabase yapılandırılmadıysa)
- Geri tuşu — `context.canPop()` ? `pop()` : `go(login)`

### Repository genişletme
**`lib/features/auth/repositories/auth_repository.dart`** — abstract interface'e:
```dart
/// V1.3.5 — Şifre sıfırlama linki gönderir (Supabase email template).
Future<void> resetPasswordForEmail(String email);
```

**`lib/features/auth/repositories/supabase_auth_repository.dart`** — implementation:
```dart
@override
Future<void> resetPasswordForEmail(String email) async {
  try {
    await _client.auth.resetPasswordForEmail(email);
  } catch (e) {
    throw Exception(translateAuthError(e));
  }
}
```

**`test/auth_provider_reactive_test.dart`** — mevcut `_FakeAuthRepository`'ye no-op override eklendi (compile-time gereği).

### Router + UX entegrasyonu
**`lib/app/router/app_router.dart`** — `/auth/forgot` route + import.

**`lib/features/auth/screens/login_screen.dart`** — şifre alanının altında sağa hizalı "Şifremi unuttum" `TextButton`. Backend off ya da submitting iken disabled.

---

## 4. Yasal Metinler + Signup Kabul Checkbox

### Yeni ekranlar (V1 taslak — hukuki final kontrol gerekir)
**`lib/features/legal/screens/terms_screen.dart`** — Kullanım Şartları:
1. FırınNet nedir, 2. Hesap & sorumluluk, 3. İçerikler, 4. Yasak kullanım, 5. Ticari kayıtlar, 6. Hizmetin gelişim aşamasında olması, 7. Hesap kapatma, 8. İletişim. Üst kısmında "V1 taslak — hukuki final kontrol gerekir" banner'ı.

**`lib/features/legal/screens/privacy_screen.dart`** — Gizlilik Politikası:
1. İşlenen veriler (email, profile, rol, şehir, reçete, panel kayıtları, ilanlar), 2. İşleme amacı, 3. Altyapı (Supabase + RLS), 4. Üçüncü taraf paylaşımı, 5. KVKK kullanıcı hakları, 6. Çerez/cihaz, 7. Hesap kapatma + veri silme, 8. İletişim. Aynı taslak banner'ı.

### Router
**`lib/app/router/app_router.dart`**:
- `/legal/terms` → `TermsScreen`
- `/legal/privacy` → `PrivacyScreen`

### Paylaşılan footer widget'ı
**`lib/features/auth/widgets/legal_footer.dart`** — `LegalFooter` (public). RichText + `TapGestureRecognizer`'lı tıklanabilir Kullanım Şartları + Gizlilik Politikası link'leri. Önce LoginScreen içine inline koyduğum versiyon refactor edildi; tek kaynak.

### Footer entegrasyonu
- **`auth_entry_screen.dart`** → 3 buton altında, "Kayıtsız devam et" sonrası `LegalFooter`. Üçlü buton mimarisi bozulmadı.
- **`login_screen.dart`** → form altında `LegalFooter`.

### Zorunlu kabul checkbox (CreateProfileScreen, sadece yeni signup)
**`lib/features/profile/screens/create_profile_screen.dart`**
- State: `bool _legalAccepted = false`, `bool _legalShowError = false`.
- Yeni `_LegalAcceptCheckbox` widget'ı (private) — Material checkbox + tıklanabilir Şartlar/Gizlilik link'leri içeren RichText.
- Görünürlük koşulu: `if (!_isCompletion)` — completion akışında (zaten signed-in profilini tamamlıyor) gösterilmez; kabul kayıt anında alınmıştı.
- `_save()` başında: `if (!_isCompletion && !_legalAccepted)` → kırmızı border + uyarı yazısı + snackbar ("Devam etmek için kullanım şartlarını ve gizlilik politikasını kabul etmelisin.") → return.
- Kabul edildikten sonra error state otomatik temizlenir.

### "Üye olmadan gezmeye devam et" escape hatch
Korundu. Checkbox guest akışını engellemiyor — yalnız signup save'ini bloke ediyor. Guest akışı yine `_continueAsGuest` üzerinden devam ediyor.

### app_strings.dart eklemeleri
```dart
authForgotPasswordTitle / Hint / Submit / Sent / Fail
legalTermsTitle / legalPrivacyTitle
legalAcceptCheckbox / legalAcceptRequired / legalFooterAccept
```

---

## 5. Doğrulama

### Static analyze
```
flutter analyze
> No issues found! (ran in 0.5s)
```

### Test suite
```
flutter test
> 00:05 +159: All tests passed!
```
- Önceki 154 test ✅ korundu
- + 5 yeni test (`dealer_uuid_handling_test.dart`)
- Toplam 159 test pass

### Secret scan
`sbp_*`, `service_role`, `eyJ*`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` arandı.

- **`lib/`** içinde sıfır eşleşme.
- **`.env / .env.local / .env.production`** dosyaları yok (dart-define üzerinden runtime).
- Markdown raporlardaki eşleşmeler meta-açıklama ("service_role kullanılmadı" tarzı) — secret değil.

---

## 6. Hard Constraint Tablosu

| Kısıtlama | Durum |
|---|---|
| Supabase schema/RLS/migration değiştirme | ✅ Hiç dokunulmadı |
| Panel/reçete/guest guard mimarisini bozma | ✅ Korundu |
| AuthEntry üçlü yapısı (Giriş / Üye ol / Kayıtsız) | ✅ Korundu, footer eklendi |
| Guest guard davranışını bozma | ✅ "Üye olmadan gez" escape hatch çalışıyor |
| service_role / PAT / DB password kullanma | ✅ Yok |
| Secret hardcode etme | ✅ Yok |
| Mevcut 154 test bozulmasın | ✅ 154 → 159 (yeni 5 test) |

---

## 7. Manuel Test Planı (Bir sonraki cihaz testi için)

### Senaryo A — Bayi ekleme (P0 fix)
1. Login → Panel → Bayi ekle.
2. Form doldur, kaydet → snackbar "Bayi eklendi" + listede görünmeli.
3. **Beklenen:** Eskiden "Exception: ...22P02..." idi, artık başarılı.

### Senaryo B — Login redirect
1. Logout → Login.
2. **Beklenen:** Splash sonrası `/feed` (Panel değil). Bottom nav 5. tab'dan Panel'e geçilebiliyor.

### Senaryo C — Şifremi unuttum
1. Login ekranı → "Şifremi unuttum" → /auth/forgot.
2. Email gir → "Reset Link Gönder" → yeşil onay state.
3. Mail kutusunu kontrol et — Supabase reset linki gelmeli.

### Senaryo D — Yasal footer + checkbox
1. Splash → AuthEntry: alt kısımda "Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul etmiş olursun." görünmeli, link'ler tıklanmalı (yeni route'lar açılmalı).
2. AuthEntry → "Hesabım yok, üye ol" → role select → CreateProfile.
3. Form'u doldur, **checkbox'ı işaretleme**, "Kaydet" bas → kırmızı border + uyarı yazısı + snackbar.
4. Checkbox işaretle → kaydet → başarılı signup.
5. AuthEntry'den "Kayıtsız devam et" → guest akışı normal şekilde feed'e gidebilmeli (checkbox guest'ı engellemiyor).

### Senaryo E — Smoke regression
- Reçete oluştur (signed-in) → kaydet, listede görün.
- Üretim/fire kaydı (signed-in) → kaydet.
- Logout → guest mod → "Reçete kaydet" → AuthRequired bottom sheet (guest write block).

---

## 8. Bilinen Sınırlamalar / Sonraki Faza

- **Şifre yenileme akışı:** V1 Supabase'in default web sayfasına bağımlı. Mobile in-app deep link + `UpdatePasswordScreen` (token parse + `auth.updateUser`) sonraki faza bırakıldı.
- **Yasal metinler:** V1 taslak. Hukuki kontrol sonrası revize edilmeli; revizyon olduğunda `app_strings.dart` üzerinden kolayca güncellenebilir.
- **Checkbox kayıt analitiği:** Şu an yalnız UI guard. Kabul timestamp/version backend'e yazılmıyor — KVKK ispat gereksinimi geldiğinde `profiles.legal_accepted_at` + `legal_version` kolonu eklenebilir.
- **CreateProfileScreen completion akışı:** Mevcut signed-in kullanıcı eksik profilini tamamlıyorsa checkbox gösterilmiyor (kabul signup anında alınmıştı). Eğer yasal metin sürümü değişirse re-accept akışı için ileride alan eklenebilir.

---

## 9. Etkilenen Dosyalar

### Modified
- `lib/app/router/app_router.dart` — 3 yeni route + import
- `lib/core/constants/app_strings.dart` — forgot + legal string'leri
- `lib/features/auth/repositories/auth_repository.dart` — `resetPasswordForEmail` abstract
- `lib/features/auth/repositories/supabase_auth_repository.dart` — implementation
- `lib/features/auth/screens/auth_entry_screen.dart` — `LegalFooter` bağlandı
- `lib/features/auth/screens/login_screen.dart` — Şifremi unuttum link + `LegalFooter`
- `lib/features/dealers/repositories/supabase_dealer_repository.dart` — uuid validator + INSERT branching
- `lib/features/dealers/screens/add_dealer_screen.dart` — try/catch + snackbar
- `lib/features/onboarding/screens/splash_screen.dart` — Senaryo 5 → /feed
- `lib/features/profile/screens/create_profile_screen.dart` — `_LegalAcceptCheckbox` + `_save()` guard
- `test/auth_provider_reactive_test.dart` — `_FakeAuthRepository.resetPasswordForEmail` no-op

### Yeni
- `lib/features/auth/screens/forgot_password_screen.dart`
- `lib/features/auth/widgets/legal_footer.dart`
- `lib/features/legal/screens/terms_screen.dart`
- `lib/features/legal/screens/privacy_screen.dart`
- `test/dealer_uuid_handling_test.dart` — 5 test
- `AUTH_ENTRY_LEGAL_AND_DEALER_AUDIT.md` — sprint öncesi audit raporu
- `AUTH_LEGAL_DEALER_FIX_REPORT.md` — bu rapor
