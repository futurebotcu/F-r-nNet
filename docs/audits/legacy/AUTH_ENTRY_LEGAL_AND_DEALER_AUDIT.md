# AUTH_ENTRY_LEGAL_AND_DEALER_AUDIT

**Tarih:** 2026-05-13
**Tür:** Read-only audit. Kod değiştirilmedi (kısa süreli dealer fix denemesi geri alındı).
**Kapsam:** Auth entry / login / signup / ilk açılış / yasal metinler / post-login landing / "bayi eklenmiyor" bug.

---

## 1. Kısa Özet

- **Giriş ekranı:** AuthEntryScreen 3 buton (Giriş Yap / Hesabım yok üye ol / Kayıtsız devam et). Login sade; Şifremi unuttum YOK; yasal metin linki YOK.
- **Login sonrası:** Splash → `/panel` (RoleDashboardScreen). Doğrudan Feed'e gitmiyor.
- **Guest sonrası:** Doğrudan `/feed`.
- **Signup sonrası:** Splash redirect → profil complete ise `/panel`, eksikse `/profile/create`.
- **Şifremi unuttum:** **YOK**. App string'i tanımlı (`authForgotPassword = 'Şifremi unuttum'`) ama hiçbir UI'a bağlanmamış.
- **Yasal metinler:** **HİÇBİRİ YOK**. Kullanım Şartları, Gizlilik, KVKK, üyelik kabul checkbox'ı — sıfır.
- **Bayi eklenmiyor bug:** **Root cause kesin** — `SupabaseDealerRepository.upsertDealer` client-side `'d_<microseconds>'` ID'sini Postgres `uuid` sütununda `eq` query'sine geçiriyor → 22P02 (`invalid input syntax for type uuid`).

---

## 2. Mevcut Auth Akış Haritası

| Senaryo | currentAuthUser | guest flag | Profile | Açılan ekran | Karar noktası |
|---|---|---|---|---|---|
| `pm clear` sonrası fresh boot | null | false | n/a | `/auth` (AuthEntryScreen) | `splash_screen.dart` l.43-50 |
| AuthEntry "Giriş Yap" tıkla | null | false | n/a | `/login` (push) | `auth_entry_screen.dart` l.108-114 |
| Login email/şifre başarılı | non-null (V1.3.4 fix sonrası reactive) | false (auto) | DB'den fetch | Splash → `/panel` veya `/profile/create` | `login_screen.dart` `_signIn` → `context.go('/')` |
| AuthEntry "Hesabım yok, üye ol" | null | false | n/a | `/auth/role-select` (push) | `auth_entry_screen.dart` l.116-130 |
| Role seç (commercial/individual/wholesaler) | null | false | n/a | `/profile/create?role=...` (push) | `role_select_screen.dart` `_pick` |
| Profile create kaydet (signUp + metadata) | non-null | false (auto) | yeni satır oluşur | Splash → `/panel` | `create_profile_screen.dart` `_save` → `context.go('/')` |
| Profile create "Üye olmadan gezmeye devam et" | (signed-in ise signOut yapılır) | true (persist) | guest | `/feed` | `create_profile_screen.dart` `_continueAsGuest` |
| AuthEntry "Kayıtsız devam et" | null | true (persist) | guest | `/feed` | `auth_entry_screen.dart` l.131-152 |
| Logout (Profile screen → "Profilden Çık") | null | false (auto) | clear | `/auth` | `profile_screen.dart` l.79-101 |
| App restart (cold) + guest=true | null | true | guest | `/feed` | Splash senaryo 2/4 |
| App restart + signed in + complete profile | non-null | false | complete | `/panel` | Splash senaryo 5 |
| App restart + signed in + incomplete profile | non-null | false | incomplete | `/profile/create` | Splash senaryo 6 |
| Supabase disabled (dart-define yok) + guest=false | null | false | n/a | `/auth` | Splash senaryo 1 |

> **`/onboarding` legacy route hâlâ erişilebilir** (route silinmedi) ama Splash hiç oraya gitmiyor. Backward compat.

---

## 3. Login Ekranı Mevcut Durum

`lib/features/auth/screens/login_screen.dart`:

| UI elemanı | Var mı? | Ne yapıyor? | Eksik / Not |
|---|---|---|---|
| Email TextFormField | ✅ | Validator: empty + içerik `@.` | OK |
| Şifre TextFormField (obscure) | ✅ | Validator: non-empty (min length **yok** signIn'de) | Min length yok — backend reddederse snackbar görür |
| **Giriş Yap** (AppPrimaryButton copper) | ✅ | `auth.signIn(email, pwd)` → `setGuest(false)` → `context.go('/')` | OK |
| **Hesabın yok mu? Üye ol** (TextButton, copper) | ✅ | `context.push('/auth/role-select')` | OK |
| **Şifremi unuttum** | ❌ | — | String var (`authForgotPassword`) ama UI'da hiç gösterilmiyor; reset password akışı yok |
| Kayıtsız devam et | ❌ | (yalnız AuthEntry'de) | Doğru — giriş ekranında olmamalı; AuthEntry'de var |
| Yasal metin linki | ❌ | — | Yok |
| Hata snackbar (Türkçe) | ✅ | `auth_error_translator.dart` üzerinden | OK |
| Sarı banner (Supabase off) | ✅ | `authBackendDisabled` mesajı + giriş alanları disable | OK |
| Loading state | ✅ | `_submitting` ile button "..." | OK |

**Eksikler özet:** Şifremi unuttum link yok; yasal metin linki yok.

---

## 4. İlk Açılış / Landing Kararı

### Mevcut davranış (kod doğrulamış)

| Olay | Hedef route | Kanıt |
|---|---|---|
| AuthEntry → Giriş Yap → başarılı signIn | Splash → **`/panel`** (Ticari) veya rol bazlı dashboard | `login_screen.dart` `context.go(AppRoutes.splash)` + `splash_screen.dart` `_route` senaryo 5 |
| AuthEntry → Hesabım yok üye ol → role seç → kaydet | Splash → **`/panel`** | `create_profile_screen.dart` `_save` `context.go(AppRoutes.splash)` + Splash senaryo 5 |
| AuthEntry → Kayıtsız devam et | **`/feed`** | `auth_entry_screen.dart` `setGuest(true)` + `context.go(AppRoutes.feed)` |
| Profile create → "Üye olmadan gezmeye devam et" | **`/feed`** | `create_profile_screen.dart` `_continueAsGuest` |

### Önerilen yeni davranış (kullanıcının söylediği)

> "Kullanıcı giriş yapınca ilk olarak 'Akış/Feed' sayfasının açılmasını istiyor olabilir; mevcutta panel açılıyor."

| Olay | Önerilen route |
|---|---|
| Login başarılı + complete profile | **`/feed`** (kart/AŞK ekranı) — Panel'e bottom nav'dan ulaşılır |
| Signup tamamlandı | **`/feed`** (yeni kullanıcıya sektör akışı önce) |
| Guest devam et | `/feed` (zaten doğru) |

### Hangi dosyalar değişmeli (kararlaştırılırsa)

| Dosya | Değişiklik |
|---|---|
| `splash_screen.dart` | Senaryo 5'te `context.go(AppRoutes.feed)` (panel yerine) |
| `login_screen.dart` | Hâlâ `context.go(AppRoutes.splash)` — splash redirect değişikliği yeterli |
| `create_profile_screen.dart` | Aynı — splash üzerinden gider |

> **Risk:** Bottom nav 5 tab'da Panel hâlâ var; kullanıcı oraya tek tap'le gidebilir. Yine de "rol bazlı kartlarımı nerede göreceğim?" sorusu Feed ilk açılışında görünmüyor. **Onboarding hint** (yeni kullanıcıya "Panel'i görmek için aşağıdaki kartına bas" tipi tooltip) eklemek isteyebilirsin — ayrı bir karar.

### "Profil tamamlandıktan sonra Feed mi Panel mi?"

İki seçenek:
- **Yeni signup → Feed:** Sektör akışını ilk önce gör; "İşin nerden başlasın?" sorusunu kullanıcıya bırak. Panel bottom nav'da hep erişilebilir.
- **Yeni signup → Panel:** Rol bazlı içerik hemen önünde; "Burası senin paneli" hissi.

Karar product tercihi. Brief kullanıcının "Feed öne" tercihi olduğunu söylüyor.

---

## 5. Yasal Metin Audit

| Metin | Var mı? | Route/dosya | Signup'ta gösteriliyor mu? | Eksik |
|---|---|---|---|---|
| Kullanım Şartları | ❌ | — | ❌ | Yok |
| Gizlilik Politikası | ❌ | — | ❌ | Yok |
| KVKK / Aydınlatma Metni | ❌ | — | ❌ | Yok |
| Çerez / Analytics | ❌ (uygulamada analytics yok) | — | n/a | n/a (V2'de eklenirse gerek) |
| Üyelik kabul checkbox | ❌ | — | ❌ | CreateProfileScreen'de kabul mekanizması yok |
| "Devam ederek şartları kabul etmiş olursun" metni | ❌ | — | ❌ | Yok |

**Sonuç:** Yasal sıfır. Türkiye'deki KVKK + Apple/Google App Store şartları için **Kullanım Şartları + Gizlilik Politikası en az gerekli**. KVKK Aydınlatma Metni Türkiye'de zorunlu (kişisel veri toplandığı için: email, isim, şehir, profession_badge).

### Minimum V1 yasal şablonu (öneri)

| İş | Detay |
|---|---|
| 2 yeni route | `/legal/terms`, `/legal/privacy` |
| 2 ekran (içerik markdown veya statik string) | `TermsScreen`, `PrivacyScreen` |
| KVKK aydınlatma metni | Privacy ekranının içine veya ayrı `/legal/kvkk` |
| Login + CreateProfile altına link satırı | "Devam ederek **Kullanım Şartları** ve **Gizlilik Politikası**'nı kabul etmiş olursun." (link tıklanabilir) |
| Profile screen'e "Yasal" bölümü | 2 link (Şartlar + Gizlilik) |

---

## 6. Şifremi Unuttum Audit

| Soru | Cevap |
|---|---|
| Mevcut altyapı? | **Yok.** `SupabaseAuthRepository` sadece `signUp/signIn/signOut/updateEmail` metodları. `resetPasswordForEmail` çağrısı eklenmemiş. |
| App string tanımlı mı? | ✅ `authForgotPassword = 'Şifremi unuttum'` (`app_strings.dart` l.50) — UI'a hiç bağlanmamış. |
| Supabase API kullanılabilir mi? | ✅ `supabase_flutter ^2.5.6` `client.auth.resetPasswordForEmail(email, redirectTo: ...)` mevcut |
| Redirect/deep link gerektiriyor mu? | ✅ Evet — Supabase email link'i tıklanınca redirectTo URL'sine atılır. **Mobile için `firinnet://reset-password` gibi custom URL scheme** veya **web çapı sayfa** gerekir |
| V1 minimum? | (a) "Email gir → 'Mailini kontrol et' ekranı", reset link Supabase varsayılan e-mail formatına göre web sayfasına atar (kullanıcı web'de yeni şifre belirler). Mobile deep link altyapısı V2'ye bırakılır. |
| Riskler | (1) Supabase dashboard'da email template "Reset Password" ayarlanmamış olabilir — kontrol edilmeli. (2) `redirectTo` deep link'i mobile için tanımlı değil — başlangıçta web fallback yeterli. |

**Minimum V1 fix planı:**
1. `LoginScreen`'e "Şifremi unuttum" link → `ForgotPasswordScreen` (`/auth/forgot`).
2. `ForgotPasswordScreen`: email input + "Reset link gönder" butonu → `auth.resetPasswordForEmail(email)`.
3. Başarılıysa "📧 E-posta adresine bir link gönderdik. Mailini kontrol et." snackbar/text.
4. Supabase dashboard'dan email template Türkçe yapılır (V1.x scope dışı, manuel ayar).

---

## 7. Bayi Eklenmiyor Bug Audit

### Hata kanıtı (8 ardışık log)
```
PostgrestException: invalid input syntax for type uuid: "d_1778669329154623"
code: 400
```

### Katman katman analiz

| Katman | Kontrol | Sonuç | Risk |
|---|---|---|---|
| **UI form** (`AddDealerScreen._save`) | Form validator → repo.upsertDealer çağırılıyor | ✅ form validation `_formKey.currentState!.validate()` geçiyor | Düşük |
| **UI guard** (V1.3.2 `canWriteWithRef`) | Auth Fatih'te `canWrite=true`, geçiyor | ✅ Engellemiyor | Yok |
| **Provider seçimi** (`dealerRepositoryProvider`) | V1.3.4 reactive fix sonrası signed-in user → SupabaseDealerRepository sarılı GuardedDealerRepository | ✅ Doğru repo | Yok |
| **Repository wrapper** (`GuardedDealerRepository.upsertDealer`) | `_requireWrite('bayi/müşteri eklemek')` → canWrite=true → forwards inner | ✅ Geçiyor | Yok |
| **Inner SupabaseDealerRepository.upsertDealer**: `_client.from('dealers').select('id').eq('id', dealer.id).maybeSingle()` | `dealer.id` = `'d_1778669329154623'` (client-side) | ❌ **22P02** — uuid validator fail | **P0 BUG** |
| **Supabase insert** | Lookup hata atıyor, insert hiç çalışmıyor | ❌ Bayi DB'ye düşmüyor | P0 |
| **RLS** | RLS owner-only doğru; ilgili değil çünkü hata uuid format'ında | ✅ | Yok |
| **Migration kolonları** | `dealers` tablosu correct, `id uuid PK default gen_random_uuid()` | ✅ Server uuid üretmesi BEKLİYOR | Yok |
| **owner_id geliyor mu?** | Payload'da `owner_id = auth.uid()` doğru | ✅ | Yok |
| **Hata gösterimi** | UI'da catch yok → unhandled exception → emülatörde flutter error log | ❌ Kullanıcı ne olduğunu görmüyor | P1 |

### Root cause (kesin)

**`SupabaseDealerRepository.upsertDealer` (`l.154-163`):**
```dart
final existing = await _client
    .from('dealers')
    .select('id')
    .eq('id', dealer.id)        // ← 'd_<ts>' uuid değil → 22P02
    .maybeSingle();
```

Client `AddDealerScreen._save` `Dealer(id: 'd_${now.microsecondsSinceEpoch}')` oluşturup `repo.upsertDealer(dealer)` çağırıyor. Supabase repo o ID ile lookup yapıyor; Postgres uuid sütun validator'ı 22P02 atıyor.

### Aynı pattern başka repolarda var mı?

| Repo metodu | Kontrol | Durum |
|---|---|---|
| `RecipeRepository.save` | `id.startsWith('r_')` → INSERT direkt path, lookup yok | ✅ Doğru |
| `WorkerRepository.upsertJobSeekPost` | `id == null \|\| id.startsWith('l_')` → INSERT | ✅ Doğru |
| `WorkerRepository.upsertMyProfile` | owner_id ile select sonra insert/update — owner_id uuid (auth.uid'den) | ✅ Doğru |
| `BakeryRepository.addProduction/Waste/Delivery` | Direkt INSERT, id payload'da yok (server uuid üretir) | ✅ Doğru |
| `DealerRepository.addPrice/addNote/addTransaction` | Direkt INSERT, id payload'da yok | ✅ Doğru |
| **`DealerRepository.upsertDealer`** | `.eq('id', dealer.id).maybeSingle()` lookup | ❌ **TEK KIRIK** |

### Olasılık sıralaması (P0/P1/P2)

**P0 (yüksek ihtimal — kanıtlandı):**
- `upsertDealer` lookup pattern'i client `'d_<ts>'` ID'sini uuid sütununa geçiriyor.

**P1 (olası — kanıtlanmadı ama yan etki):**
- UI'da bu exception catch edilmiyor; kullanıcı snackbar görmüyor, sadece flutter log'a yazılıyor. AddDealerScreen yine pop yapmaz, kullanıcı "ne oldu?" diye düşünür.

**P2 (UX/hata görünmüyor):**
- Aynı bug'ın tekrar kontrol/iyileştirilmesi için merkezi `_isUuid` helper veya repository pattern'inde "client id non-uuid → INSERT direkt" standartlaştırılması.

### Düzeltme stratejisi (uygulanmadı, audit talebi gereği — sadece öneri)

**A. Minimum fix:** `upsertDealer`'a uuid validator ekle, non-uuid ise lookup atla (RecipeRepository pattern'iyle uyumlu):
```dart
if (!_isUuid(dealer.id)) {
  await _client.from('dealers').insert(payload);
  _notify();
  return;
}
// ... mevcut update path
```

**B. Defansif fix:** `try/catch` ile PostgrestException yakalanıp UI'da Türkçe snackbar.

**C. Genelleştirilmiş fix:** Tüm Supabase repo'larına ortak `_isUuid` helper + "client id ise insert direkt" pattern'i.

**Karar:** Minimum **A** + **B** kombinasyonu — tek dosyada izole, ~10 satır. Test'e açık.

---

## 8. İdeal Yeni Auth/Login Sistemi Önerisi

> Kod yazmadan, ürün önerisi.

### İlk ekran (AuthEntryScreen)
- Mevcut hâli zaten temiz: 3 büyük buton + sıcak başlık.
- **Eklemeli:** Alt'ta küçük metin: *"Devam ederek **Kullanım Şartları** ve **Gizlilik Politikası**'nı kabul etmiş olursun."*

### Login ekranı
- Email + şifre + Giriş Yap (mevcut)
- **Eklemeli:**
  - **Şifremi unuttum** link (sağ alt veya şifre alanı altında)
  - "Hesabın yok mu? Üye ol" — mevcut
  - Yasal metin alt link (footer)

### Signup / Role Select / Profile Create
- Role Select (mevcut) doğru.
- Profile Create:
  - Email + şifre + name + city + profession + role (mevcut)
  - **Eklemeli:** Kabul checkbox: *"Kullanım Şartları ve Gizlilik Politikası'nı okudum, kabul ediyorum."* (zorunlu)
  - "Üye olmadan gezmeye devam et" (mevcut, V1.3.1)

### Forgot Password
- `/auth/forgot` route + ekran:
  - Email input
  - "Reset link gönder" → `auth.resetPasswordForEmail(email)`
  - "Mailini kontrol et" snackbar
- LoginScreen → "Şifremi unuttum" → push `/auth/forgot`

### Legal text route'lar
- `/legal/terms` → TermsScreen (statik markdown)
- `/legal/privacy` → PrivacyScreen (statik markdown — KVKK aydınlatması da burada)

### Post-login landing
**Karar bekliyor:** Brief'in tercihi `/feed`.
- Login success → Splash → `/feed`
- SignUp success → Splash → `/feed`
- Bottom nav Panel sekmesi rol kartlarına erişimi sağlar (mevcut akış)
- Yeni kullanıcı için Feed üstüne küçük bir hint kartı: "Reçete & bayi yönetimi için Panel sekmesine bak" (V1.4 onboarding tutorial)

### Guest sonrası
- Mevcut `/feed`'e gitme davranışı doğru, korunur.

---

## 9. Minimum Fix Planı

### A. Auth/Login cleanup
| İş | Dosyalar | Risk | Test |
|---|---|---|---|
| LoginScreen Şifremi unuttum link | `login_screen.dart` | Düşük | UI smoke |
| Auth error mesajları İngilizce'den Türkçe'ye geliştir | `auth_error_translator.dart` | Düşük | unit |

### B. Forgot password
| İş | Dosyalar | Risk | Test |
|---|---|---|---|
| `AuthRepository.resetPasswordForEmail(email)` interface metodu | `auth_repository.dart`, `supabase_auth_repository.dart` | Düşük | unit (FakeAuth) |
| `ForgotPasswordScreen` | yeni `forgot_password_screen.dart` | Düşük | UI smoke |
| Route `/auth/forgot` | `app_router.dart` | Düşük | route test |

### C. Legal text
| İş | Dosyalar | Risk | Test |
|---|---|---|---|
| `TermsScreen`, `PrivacyScreen` (statik içerik) | yeni dosyalar | Düşük | UI smoke |
| `/legal/terms`, `/legal/privacy` route | `app_router.dart` | Düşük | route test |
| CreateProfileScreen kabul checkbox | `create_profile_screen.dart` | **Orta — form akışını etkiler** | unit + UI smoke |
| LoginScreen + AuthEntry footer link | iki dosya | Düşük | — |
| ProfileScreen "Yasal" bölümü | `profile_screen.dart` | **Düşük (kullanıcı bilinçli olarak "Profil ekranına dokunma" demişti — geçilebilir, V2)** | — |

### D. Post-login landing /feed kararı
| İş | Dosyalar | Risk | Test |
|---|---|---|---|
| Splash senaryo 5 → `/feed` | `splash_screen.dart` (1 satır) | **Düşük** | smoke |
| `repository_provider_selection_test.dart` ve `panel_v1_2_test.dart` etkilenmiyor (route assertion yok) | — | — | mevcut testler bozulmaz |

### E. Bayi eklenmiyor bug
| İş | Dosyalar | Risk | Test |
|---|---|---|---|
| `_isUuid` helper + `upsertDealer` non-uuid → INSERT direkt | `supabase_dealer_repository.dart` (~10 satır) | Düşük | unit + manual |
| `try/catch` PostgrestException → Türkçe snackbar | `add_dealer_screen.dart` | Düşük | smoke |

### Ortak: yeni AppStrings
| Anahtar | Metin |
|---|---|
| `authForgotPasswordTitle` | "Şifreni mi unuttun?" |
| `authForgotPasswordHint` | "E-posta adresine reset link göndereceğiz." |
| `authForgotPasswordSubmit` | "Reset Link Gönder" |
| `authForgotPasswordSent` | "Mailini kontrol et — link gönderildi." |
| `legalTerms` | "Kullanım Şartları" |
| `legalPrivacy` | "Gizlilik Politikası" |
| `legalAcceptCheckbox` | "**Kullanım Şartları** ve **Gizlilik Politikası**'nı okudum, kabul ediyorum." |
| `legalFooterAccept` | "Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul etmiş olursun." |

---

## 10. Test Planı

### Önerilen yeni testler

| Test | Tip | Açıklama |
|---|---|---|
| `pm clear` → AuthEntry | smoke (manuel) | Boot → 3 buton |
| Login success → /feed (yeni karar uygulanırsa) | widget test | Splash redirect |
| Bottom nav Panel erişimi | smoke | Tab tıklanır |
| Signup role select 3 rol | unit (mevcut benzeri) | RolePanelCards test'iyle uyumlu |
| Legal checkbox olmadan signup engellenir | widget test | CreateProfileScreen form validator |
| Forgot password email gönderir | unit (FakeAuth) | resetPasswordForEmail çağrısı |
| Dealer add signed-in → Supabase row düşer | smoke (manuel + MCP query) | İnsert sonrası `SELECT * FROM dealers WHERE owner_id = ...` |
| Guest dealer add → AuthRequired sheet | mevcut wrap | regression |
| Dealer client `'d_<ts>'` non-uuid → insert direkt | unit | uuid validator + mock client |

---

## 11. Sonuç (7 satır)

1. **Mevcut login sonrası açılan ekran:** `/panel` (Splash redirect kararı, profile complete olduğu için).
2. **Önerilen login sonrası ekran:** `/feed` (kullanıcı tercihi). Splash senaryo 5 tek satır değişikliği yeterli.
3. **Şifremi unuttum durumu:** Hiç yok. App string `authForgotPassword` tanımlı ama UI'a bağlanmamış. Min V1: `ForgotPasswordScreen` + `resetPasswordForEmail` çağrısı + LoginScreen link.
4. **Yasal metin durumu:** Sıfır — Kullanım Şartları, Gizlilik, KVKK, signup kabul checkbox hepsi yok. Türkiye'de KVKK aydınlatma zorunlu (kişisel veri toplanıyor).
5. **Bayi ekleme bug için en güçlü şüphe:** **P0 kanıtlandı** — `SupabaseDealerRepository.upsertDealer` client `'d_<ts>'` ID'sini Postgres `uuid` sütununa `eq` query'sinde geçiriyor → 22P02. Aynı pattern Recipe/JobSeek repo'larında doğru (prefix kontrol), sadece dealer kırık.
6. **Minimum düzeltme sırası:** (E) Bayi bug (P0, en kritik — kullanıcı bayi ekleyemiyor) → (B) Forgot password (P2) → (D) Post-login landing /feed (P3 product tercihi) → (C) Legal text (P1 yasal zorunluluk, lansman öncesi şart) → (A) Auth cleanup polish.
7. **Kod yazmaya geçilebilir mi, önce karar gerekir mi?** **Karar gerekiyor:** (i) Login sonrası gerçekten `/feed` mi `/panel` mi? (ii) Legal text'i bu fazda mı V1.4'e mi? (iii) Forgot password V1.4'e mi şimdi mi? Bayi bug'ı bağımsız — diğer kararlar bekleyebilirken hemen düzeltilebilir.

---

**Bu rapor sonrası karar bekleyen 4 nokta:**
- Bayi eklenmiyor bug'ı **şimdi mi** düzeltilsin? (kanıtlandı, izole, ~10 satır)
- Login sonrası landing **`/feed`'e mi** alınsın? (1 satır karar)
- Forgot password **şimdi mi** eklensin? (~3 dosya)
- Legal text **şimdi mi** eklensin? (~3 dosya + signup checkbox)

Sıralama ve kapsam için onayını bekliyorum.
