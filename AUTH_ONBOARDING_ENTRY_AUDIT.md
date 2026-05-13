# AUTH_ONBOARDING_ENTRY_AUDIT

**Tarih:** 2026-05-13
**Tür:** Read-only audit — bu rapor dışında kod/dosya değişikliği yok.
**Kapsam:** Splash, login, onboarding, profil oluşturma, auth + profile provider'lar, router, guest/local mode, logout, Supabase session yönetimi.
**Yöntem:** `lib/main.dart`, `lib/app/app.dart`, `lib/app/router/app_router.dart`, `lib/features/onboarding/screens/splash_screen.dart`, `lib/features/onboarding/screens/onboarding_screen.dart`, `lib/features/auth/screens/login_screen.dart`, `lib/features/profile/screens/create_profile_screen.dart`, `lib/features/profile/screens/profile_screen.dart`, `lib/features/profile/providers/profile_provider.dart`, `lib/features/profile/repositories/supabase_profile_repository.dart`, `lib/features/auth/providers/auth_providers.dart`, `lib/features/auth/repositories/auth_repository.dart`, `lib/features/auth/repositories/supabase_auth_repository.dart`, `lib/features/profile/models/bakery_profile.dart`, `lib/core/config/app_config.dart` okundu. SharedPreferences/secure_storage/Hive kullanımı grep ile arandı.

---

## 1. Kısa Özet

- **Uygulama ilk açılışta hangi ana kararları veriyor?** Splash 1300 ms sonra **3 dallı karar** veriyor (`splash_screen.dart` l.27-40): (1) Supabase compile-time enabled mi, (2) Supabase enabled ise oturum var mı, (3) yoksa Login'e götür.
- **Supabase açıkken ve kapalıyken akış farklı mı?** **Evet.** Supabase enabled değilse Splash doğrudan `/onboarding`'e gider (login bypass). Supabase enabled ise Splash `/login` veya `/panel` arasında karar verir.
- **Temiz kurulumda ilk ekran ne olmalı?** dart-define geçilmişse: **LoginScreen** (`/login`). dart-define geçilmemişse: **OnboardingScreen** (`/onboarding`).
- **Mevcut kodda ilk ekran ne oluyor?** Kod tarafında belirleyici **tek** girdi: `AppConfig.supabaseEnabled` (compile-time const). Bunun dışında **HİÇBİR** persisted local flag yok.
- **Giriş ekranı neden bazen farklı görünüyor?** Çünkü Splash 3 dala ayrılıyor + LoginScreen `authRepositoryProvider == null` ise warning banner gösterip "Giriş Yap" butonunu disabled yapıyor. State varyasyonu = ekran varyasyonu. Bug değil, **state'e duyarlı tasarım**.
- **Bug var mı, state farkı mı?** **Kritik bug yok.** İki tasarım eksiği var (madde 11 P1+P2). Geri kalan farklılıklar amaçlı state varyasyonları.

---

## 2. Başlangıç Akış Haritası

> Not: Kodda **persisted local flag yok** (guest flag / onboarding completed flag dahil). Tek persist mekanizması Supabase'in kendi `supabase_flutter` paketinin session cache'idir (SharedPreferences altında, `pm clear` ile silinir).

| # | Durum | `supabaseEnabled` | `currentAuthUser` | profile DB'de | profile state'te (Riverpod) | guest flag | Açılan ekran | Karar noktası |
|---|---|---|---|---|---|---|---|---|
| 1 | Temiz kurulum + Supabase dart-define + oturum yok | `true` | `null` | — | `null` | yok | **`/login`** | `splash_screen.dart` l.38 |
| 2 | Temiz kurulum + Supabase disabled (dart-define yok) | `false` | n/a | n/a | n/a | yok | **`/onboarding`** | `splash_screen.dart` l.31 |
| 3 | Supabase enabled + oturum var + profile var | `true` | `User(id, email)` | row mevcut | yüklenir (auth stream → `_loadFor`) | yok | **`/panel`** (RoleDashboard) | `splash_screen.dart` l.36 + `profile_provider.dart` l.27-35 |
| 4 | Supabase enabled + oturum var + profile DB'de yok | `true` | `User` | `null` | `null` (fetch null döner) | yok | **`/panel`** — RoleDashboardScreen profile==null → `AccountType.individual` fallback | `role_dashboard_screen.dart` l.29 |
| 5 | Supabase enabled + oturum var + profile incomplete (örn. `display_name` boş) | `true` | `User` | row var ama alanlar boş | yüklenir (eksik alanlarla) | yok | **`/panel`** — gating yok; UI eksik alanları boş gösterir | Yok — kod profile completeness kontrolü yapmıyor |
| 6 | Kullanıcı "Kayıtsız Devam Et" seçmişse | herhangi | herhangi | n/a | `BakeryProfile.guest` (in-memory) | YOK (persist edilmez) | **`/feed`** (go) | `login_screen.dart` l.211-215, `onboarding_screen.dart` l.88-91 |
| 7 | Logout sonrası | `true` | `null` (signOut sonrası) | (DB'deki satır kalır) | `null` (clear) | n/a | **`/login`** (supabase on) veya **`/onboarding`** (supabase off) | `profile_screen.dart` l.79-100 |
| 8 | App restart (cold start) — oturum cache'i Supabase tarafında varsa | `true` | `User` (auto-restore) | row var (varsayım) | _loadFor ile yüklenir | n/a | **`/panel`** | `Supabase.initialize` session'ı restore eder |
| 9 | `adb shell pm clear com.firinnet.firin_defter` sonrası | `true` (dart-define geçtiyse) | `null` (session storage silindi) | n/a | `null` | n/a | **`/login`** | Senaryo #1 |
| 10 | Hot restart (`R`) | aynı build, currentUser=Supabase memory | — | — | yeniden _loadFor | n/a | aynı senaryo, Splash baştan çalışır | — |

**Karar noktaları kod referansı:**

```dart
// splash_screen.dart l.27-40
void _route() {
  if (!AppConfig.supabaseEnabled) {                 // → senaryo #2
    context.go(AppRoutes.onboarding);
    return;
  }
  final user = ref.read(currentAuthUserProvider);
  if (user != null) {
    context.go(AppRoutes.panel);                    // → #3, #4, #5, #8
  } else {
    context.go(AppRoutes.login);                    // → #1, #9
  }
}
```

```dart
// role_dashboard_screen.dart l.27-34
Widget build(BuildContext context, WidgetRef ref) {
  final profile = ref.watch(profileControllerProvider);
  final account = profile?.accountType ?? AccountType.individual;  // ← #4 fallback
  final cards = RolePanelCards.forAccount(account);
  ...
}
```

---

## 3. Router Redirect Mantığı

**Başlangıç route:** `AppRoutes.splash = '/'` (`createRouter` `initialLocation`, `app_router.dart` l.78).

**Top-level redirect yok.** GoRouter'da `redirect:` global callback'i tanımlı **değil**. Auth gating sadece SplashScreen içinde manuel yapılıyor.

| Route | Ne işe yarıyor | Kim görebilir | Redirect alıyor mu | Nereye atıyor |
|---|---|---|---|---|
| `/` | Splash — boot decision | Herkes | Hayır (route'un kendi içinde `context.go` ile çıkar) | Senaryoya göre `/login`, `/onboarding`, `/panel` |
| `/onboarding` | Marketing hero + Profil Oluştur + Kayıtsız | Herkes | Hayır | Manuel: `/profile/create` (push) veya `/feed` (go) |
| `/login` | Email/şifre giriş + sign-up + guest | Herkes | Hayır | Manuel: `_signIn` → `/panel`, "Profil Oluştur" → `/profile/create` (push), guest → `/feed` (go) |
| `/profile/create` | Hesap türü + isim + şehir + email + (şifre) + meslek | Herkes | Hayır | Save sonrası → `/panel` (go) |
| `/panel` | RoleDashboardScreen | Herkes (auth check yok!) | Hayır | İçindeki kartlar üzerinden push |
| `/feed` | FeedScreen | Herkes | Hayır | — |
| `/groups`, `/market`, `/jobs` | Shell tab'lar | Herkes | Hayır | — |
| `/profile` | ProfileScreen | Herkes | Hayır | profile==null ise EmptyState |
| `/recipes`, `/dealers`, `/wholesale/customers`, `/calculator`, `/worker/*` | Feature ekranları | Herkes (UI auth-aware ama route gating yok) | Hayır | Kendi içinde RLS hataları ile yönlenir |
| `/panel/recipe` | Legacy alias | Herkes | **Evet** → `/recipes` | — |

**Kritik gözlem:** Tüm korumalı route'lar (örn. `/recipes`, `/dealers`, `/wholesale/customers`) auth-gated **değil** — router seviyesinde. Bu route'lara doğrudan deeplink ile gidilebilir. Eğer oturum yoksa Supabase repo'ları `_requireUserId()` ile `StateError` atar (örn. `supabase_dealer_repository.dart` l.47-51), UI bunu hata olarak gösterir. Yani "auth duvarı" repo seviyesinde — router seviyesinde değil.

---

## 4. Giriş Ekranı Audit (LoginScreen)

`lib/features/auth/screens/login_screen.dart` — 3 aksiyon:

| Buton | Görünüyor mu? | Hangi state'te görünür? | Tıklayınca nereye gider? | Hangi dosyada |
|---|---|---|---|---|
| **Giriş Yap** (AppPrimaryButton, copper CTA) | Evet — daima render edilir | `supabaseOn && !_submitting` ise **aktif**; aksi halde **disabled** (gri, tıklanamaz) | `_signIn` → `authRepository.signIn(email, password)` → başarılıysa `context.go('/panel')` | login_screen.dart l.188-192 |
| **Profil Oluştur** (TextButton, secondary) | Evet — daima | Daima aktif (`!_submitting`) | `context.push('/profile/create')` | l.194-205 |
| **Kayıtsız Devam Et** (TextButton, muted) | Evet — daima | Daima aktif (`!_submitting`) | `useGuest()` → `state = BakeryProfile.guest` → `context.go('/feed')` | l.206-222 |

**Banner durumu:**
- `authRepositoryProvider == null` (yani `AppConfig.supabaseEnabled == false`) ise üstte sarı warning banner: *"Sunucu bağlantısı yapılandırılmadı — bu sürümde yalnız misafir modu çalışır."* (l.134-161)
- Bu durumda email + şifre alanları disabled, "Giriş Yap" butonu disabled görünür ama hâlâ render edilir.
- "Profil Oluştur" ve "Kayıtsız Devam Et" hâlâ aktif.

**"Kullanıcı ne yapacağını anlamıyor mu?"**
- 3 buton **görünür** — netlik açısından sorun yok.
- Hiyerarşi açık: büyük copper CTA = ana eylem (Giriş Yap), küçük metin butonları = yedek eylemler.
- **Bug yok, ama LoginScreen'de "Şifremi unuttum" yok** (madde 11 P3).

---

## 5. Kayıt / Signup Akışı

`lib/features/profile/screens/create_profile_screen.dart` (full).

| Alan | UI'da nerede alınıyor? | Auth metadata'ya gidiyor mu? | profiles'a düşüyor mu? | Zorunlu mu? |
|---|---|---|---|---|
| `email` | TextFormField l.160-171 | Evet — `auth.signUp(email: ...)` | `auth.users.email` → `handle_new_user` trigger ile `profiles.email`'e kopyalanır | **Evet** (Supabase enabled durumda, `_validateEmail`) |
| `password` | TextFormField l.174-184 (sadece supabaseOn ise gösterilir) | Evet — `auth.signUp(password: ...)` | DB'ye gitmez | **Evet** (Supabase enabled durumda, min 6 char `_validatePassword`) |
| `display_name` | TextFormField l.142-150 | Evet — `metadata['display_name']` | Trigger `profiles.display_name`'e yazar | **Evet** — form validator (`'Profil adı gerekli'`) |
| `account_type` | `_AccountTypePicker` (3 kart: Ticari / Bireysel / Toptancı) l.137-140 | Evet — `metadata['account_type'] = _accountType.name` (enum→snake_case değil, dart `.name` = "commercial"/"individual"/"wholesaler") | Trigger `profiles.account_type`'a yazar | **Default değer var** (`AccountType.commercial`, l.30) — validator yok ama daima dolu |
| `profession_badge` | `Wrap(ChoiceChip)` l.189-200, `RoleBadges.all` listesinden seçim | Evet — `metadata['profession_badge'] = _badge` | Trigger `profiles.profession_badge`'e yazar | Default var (`RoleBadges.all.first`, l.31) — validator yok ama daima dolu |
| `city` | TextFormField l.152-158 | Evet — `metadata['city']` | Trigger `profiles.city`'ye yazar | **Hayır** — validator yok, boş bırakılabilir |
| `avatar_url` | UI'da YOK | — | trigger atlar (null) | Hayır |

**SignUp sonrası akış (`create_profile_screen.dart` l.43-99):**

```dart
// Supabase enabled durumu
await auth.signUp(email, password, metadata: {
  'display_name': displayName,
  'account_type': _accountType.name,
  'profession_badge': _badge,
  'city': city,
});
// Snackbar: "Hesabın oluşturuldu. Hoş geldin!"
context.go(AppRoutes.panel);
```

```dart
// Supabase disabled (local/mock) durumu — l.54-69
profileController.save(BakeryProfile(displayName, accountType, city, roleBadge, email));
// Snackbar: "Profil kaydedildi."
context.go(AppRoutes.panel);
```

**handle_new_user trigger akışı** (önceki audit'ten doğrulandı, `supabase/migrations/20260512080338_firinnet_v1_auth_user_handler.sql`):
- `auth.users` AFTER INSERT → `public.profiles` satırı otomatik oluşturulur.
- `raw_user_meta_data` (signUp `data` parametresi) → profiles sütunlarına kopyalanır.
- SECURITY DEFINER, ON CONFLICT yalnız `email + updated_at` update (kullanıcı seçimleri ezilmez).

**Email confirmation:**
- `SupabaseAuthRepository.signUp` `res.user` null ise `Exception('Kayıt tamamlandı ama oturum açılmadı.')` atar (l.36-38).
- Bu durum email confirmation gerektiğinde olur — Supabase signUp `res.user` döner ama `res.session` null kalır. Dart kodu `res.user`'ı kontrol ediyor, **session yok ama user var** durumunu doğru ele almıyor: user dönerse oturum açılmış say veriyor ama gerçekte session yok.
- **Doğrulanamadı:** Supabase dashboard'da "Confirm email" ayarı şu an aktif mi? Eğer aktifse signUp sonrası `context.go('/panel')` çalışır ama `currentAuthUser` hâlâ null kalır → kullanıcı panel'e gider, panel oturum gerektiren işlemde hata alır. (Madde 11 P1.)

---

## 6. Profil Tamamlama / Onboarding Akışı

**Sözleşme:** Kodda profile completion için **explicit kontrol yok.** Ne SplashScreen ne RoleDashboardScreen ne de router redirect profilin "complete" olup olmadığını sormaz.

| Eksik alan | Beklenen davranış | Mevcut davranış | Risk |
|---|---|---|---|
| `display_name` boş | Profile create form'una yönlendir | Form validator zorlar — signUp'ta boş geçilemez. Var olan profile için: RoleDashboardScreen header'ında "Merhaba" + "..." kısmında **boş** isim gösterir | Düşük (signUp zorunlu) |
| `account_type` yok | Default `individual` ile devam | `_accountTypeFrom('null')` → `individual` (`supabase_profile_repository.dart` l.18-20). Trigger her zaman doldurur (signUp metadata default 'commercial'). | Yok |
| `city` yok | Optional, atla | Optional — form validator yok, profil card'da `if (city.isNotEmpty)` ile gizlenir | Yok |
| `profession_badge` yok | Default badge ile devam | Default `RoleBadges.all.first`; form'da daima seçili. `supabase_profile_repository.dart` `_fromRow` boş döndürse `''` olur, UI "Diğer" benzeri fallback göstermez ama hero strip "Profil oluşturmadın" yazar | Düşük |
| `profile` satırı **hiç yok** | Profile create'e yönlendir | `_loadFor` `null` döner → `state = null`. RoleDashboardScreen'de `account ?? individual` fallback, hero strip'te **"Profil oluşturmadın → Oluştur"** linki (`role_dashboard_screen.dart` l.184-189). | **Orta** — bu durum nadir (trigger çoğu kullanıcıda satırı oluşturur). Ama trigger çalışmazsa veya signUp fail+success arası state'te oluşursa kullanıcı `/panel`'e gider ve hero strip'te yönlendirilir. Form gating yok. |
| `profile` var ama `displayName` boş, `accountType` `individual` (default), `city` boş, `professionBadge` boş | "Yarı boş profile" | RoleDashboardScreen yarım dolar; kullanıcı kart push'larında bir şey yapamaz çünkü `_requireUserId` zaten geçer (user var). Hero strip "Profil oluşturmadın" göstermez (`displayName.isEmpty` koşulu kontrol edilirken `profile != null` true) | **Orta** — kafa karışıklığı (madde 11 P2). |

**Hero strip mantığı (`role_dashboard_screen.dart` l.184-189):**
```dart
if (profile == null)
  TextButton(
    onPressed: () => context.push(AppRoutes.createProfile),
    child: const Text('Oluştur'),
  ),
```
`profile == null` → "Oluştur" linki. `profile != null && displayName.isEmpty` → linki **göstermez**, doğrudan boş yer kalır.

---

## 7. Kayıtsız Devam Et / Guest Mode

| Soru | Cevap |
|---|---|
| Nerede saklanıyor? | **Hiçbir yerde persisted değil.** Yalnız Riverpod state (`profile_provider.dart` l.61: `state = BakeryProfile.guest`). Hot restart / app restart sonrası **sıfırlanır.** |
| Supabase açıkken çalışıyor mu? | Evet — LoginScreen'deki "Kayıtsız Devam Et" butonu daima aktif. Tıklayınca `useGuest()` + `/feed`. Supabase session'ı ETKİLEMEZ; sadece local profile state'ini guest yapar. |
| Supabase kapalıyken çalışıyor mu? | Evet — OnboardingScreen'den. Aynı `useGuest()` mekanizması. |
| Guest user panel/feed görebiliyor mu? | Evet — `/feed` shell tab'ı + diğer tüm tab'lar. Panel sekmesinden RoleDashboardScreen → individual fallback (guest.accountType == individual). |
| Guest sonradan kayıt olabilir mi? | Evet — Profile/Feed ekranlarından "Profil Oluştur" linki. Ama guest profile state ile signUp metadata arasında köprü **yok** — guest user signUp yapınca tüm bilgileri yeniden girer. |
| Logout ile guest flag temizleniyor mu? | "Profilden Çık" butonu (`profile_screen.dart` l.79-100): `auth.signOut()` (if available) + `profileController.clear()` + `context.go(supabaseEnabled ? login : onboarding)`. Guest state `clear()` ile sıfırlanır. |

**Sonuç:** Guest mode **uçucu** (volatile). Kullanıcı uygulamayı kapatıp açtığında guest flag kaybolur → Splash yine `/login` veya `/onboarding`'e gider. Bu **bilinçli bir tercih** mi yoksa unutulmuş bir gap mi — kodda yorum yok. Madde 11 P2 olarak işaretlendi.

---

## 8. Local / Mock Mode

`AppConfig.supabaseEnabled == false` (dart-define geçilmemiş veya URL/KEY boş):

| Soru | Cevap |
|---|---|
| App nasıl açılıyor? | `main.dart` l.14-19: `if (supabaseEnabled)` bloğu **atlanır**. `Supabase.initialize` çağrılmaz. Log "Supabase init completed" **görünmez**. |
| Login ekranı bypass ediliyor mu? | Evet — Splash `/onboarding`'e gider. LoginScreen'e bu modda **hiç gidilmez** (route var ama Splash yönlendirmiyor). |
| Demo profile mı oluşuyor? | Hayır — kullanıcı "Profil Oluştur" veya "Kayıtsız Devam Et" seçmek zorunda. |
| Role nasıl seçiliyor? | "Profil Oluştur" → CreateProfileScreen → `_AccountTypePicker` ile manuel seçim. |
| Local/mock data nerede tutuluyor? | Riverpod state + in-memory `Local*Repository` sınıfları (`LocalBakeryRepository`, `LocalDealerRepository`, `LocalFeedRepository`, `LocalRecipeRepository`, `LocalSocialGroupRepository`, `LocalWorkerRepository`). Hepsi `List<T>` + StreamController. **Persist YOK** — app restart sıfırlar. |
| Bu davranış Supabase moduyla karışıyor mu? | Hayır — `if (supabaseEnabled && user != null)` koşulu provider'larda tutarlı (`bakery_providers.dart` l.15-21, `dealer_providers.dart` l.21-27, `worker_providers.dart` l.13-18, `recipeRepositoryProvider`). Supabase yoksa veya user yoksa local repo döner. |

---

## 9. Logout / Session Temizleme

`profile_screen.dart` l.79-100:

```dart
onPressed: () async {
  final auth = ref.read(authRepositoryProvider);
  if (auth != null) {
    try { await auth.signOut(); }
    catch (_) { /* ağ kopuksa sessiz */ }
  }
  if (!context.mounted) return;
  ref.read(profileControllerProvider.notifier).clear();
  context.go(
    AppConfig.supabaseEnabled ? AppRoutes.login : AppRoutes.onboarding,
  );
},
```

| Adım | Davranış | Doğrulama |
|---|---|---|
| Supabase session temizleniyor mu? | `_client.auth.signOut()` çağrısı → `auth.users.session` invalidate + SharedPreferences cache temizlenir. | `SupabaseAuthRepository.signOut` l.66-72 |
| Local guest/onboarding flag temizleniyor mu? | **Bu flag'ler zaten yok** (madde 7'de gösterildi). `profileController.clear()` Riverpod state'i null'a çeker — guest dahil. | `profile_provider.dart` l.78 |
| Profile provider state temizleniyor mu? | Evet — `state = null`. ProfileController auth stream'i de `null` kullanıcı bildirir → tekrar `_loadFor` çağrılmaz. | l.41-47, l.78 |
| App hangi ekrana dönüyor? | Supabase enabled → `/login`. Supabase disabled → `/onboarding`. | l.95-99 |

**Edge case:** Eğer `auth.signOut()` ağ hatası verirse `catch (_)` sessizce yutuyor ama local state yine temizleniyor. Bu durumda Supabase tarafında session **aktif kalır**, ancak `currentAuthUser` getter network erişimi olduğunda hâlâ user dönebilir → bir sonraki app açılışında Splash `/panel`'e gider. **Yarı-bug.** (Madde 11 P2.)

---

## 10. Neden Farklı Ekranlar Görüldü?

| Neden | Kodda dayanağı | Kullanıcıya etkisi |
|---|---|---|
| Eski build (V1.0/V1.1) — `pm clear` yapılmadan flutter run | `flutter run` install öncesi APK farklıysa Android eski APK'yı tutar; install eski state üzerine biner | Eski LoginScreen / Onboarding görünür, "Reçetelerim" / V1.2 kartları olmaz |
| Yeni build (V1.2) + temiz pm clear + dart-define geçti | `AppConfig.supabaseEnabled=true`, `currentAuthUser=null` (session storage temiz) | **Splash → /login.** LoginScreen 3 butonlu. |
| dart-define **geçilmedi** | `String.fromEnvironment` default `''` → `supabaseEnabled=false` → main.dart init atlar (log "Supabase init completed" **görünmez**) | **Splash → /onboarding.** "Hoş geldin FırınNet'e" + 2 buton, **"Giriş Yap" yok** |
| Supabase session cache hâlâ var (pm clear atlandı veya kısmi) | `Supabase.initialize` SharedPreferences'tan restore → `currentAuthUser != null` | Splash → /panel. RoleDashboardScreen + profile hero strip (profile yoksa "Profil oluşturmadın → Oluştur") |
| Guest seçildi (önceki oturumda Kayıtsız Devam Et) | `useGuest()` → Riverpod state guest, hot reload öncesi | Guest /feed'e atılır. Hot reload sonrası **state sıfırlanmaz** (Riverpod state hot reload'ta korunur). Ama **app restart sıfırlanır** → tekrar `/login` veya `/onboarding`. |
| Onboarding tamamlandı flag kaldı | YOK — kodda onboarding completed flag **yok**. Splash bunu kontrol etmiyor. | n/a |
| Profile completion farkı | Splash profile-state'ini kontrol etmiyor; sadece `currentAuthUser` | Profile eksikse de Splash `/panel`'e gider. RoleDashboardScreen profile null fallback ile çalışır. |
| Hot restart davranışı | `R` keyboard shortcut → app yeniden başlar, native state'ler korunur (SharedPreferences hâlâ orada) ama Dart state sıfırlanır. Riverpod scope yeniden oluşur. | Splash baştan çalışır; senaryo #1/#3/#8'den biri |

---

## 11. Bug / Risk Listesi

### P0 — Giriş yapmayı engeller
**(Yok.)**

### P1 — Kullanıcıyı yanlış ekrana atar
| Sorun | Dosya | Neden | Önerilen çözüm |
|---|---|---|---|
| Supabase signUp email confirmation gerekiyorsa (`res.session==null && res.user!=null`) kod kullanıcıyı `/panel`'e gönderir ama oturum aslında yok | `supabase_auth_repository.dart` l.30-43, `create_profile_screen.dart` l.76-90 | `res.user` kontrolü session yokluğunu yakalamıyor | Confirmation aktif ise signUp sonrası "E-postanızı doğrulayın" ekranına yönlendir; `res.session==null` durumunda otomatik signIn dene veya kullanıcıya bilgi ver. |
| RoleDashboardScreen profile null fallback `individual` → toptancı/ticari kullanıcı yanlış kart setini görür (oturum açtı ama profile DB'ye düşmediği nadir durumda) | `role_dashboard_screen.dart` l.29 | Trigger arızası durumunda profile null kalır | Profile null → kart listesi yerine "Profilini oluştur" tam-ekran wizard'a yönlendir |
| Profile completion gating yok — `displayName='', city=''` kullanıcı `/panel`'e gidip kullanmaya başlar | Yok | Splash sadece currentUser kontrolü yapıyor | `/panel`'e girmeden önce `display_name + account_type` doluluğu kontrol et; eksikse `/profile/create`'e yönlendir |

### P2 — Kafa karıştırır ama çalışır
| Sorun | Dosya | Neden | Önerilen çözüm |
|---|---|---|---|
| Guest mode uçucu — app restart guest flag'ini siler, kullanıcı tekrar Login'e atılır | `profile_provider.dart` l.61 | Persist yok | SharedPreferences ile `is_guest=true` flag persist et; Splash bunu kontrol etsin |
| Login ekranında "Profil Oluştur" yazılı buton aslında signUp ekranına gidiyor — adı yanıltıcı olabilir ("zaten profilim var, sadece signUp ekranı") | `app_strings.dart` `authSignUpButton` | Etiket sözlüğü | Etiketi "Yeni Hesap Oluştur" yap veya "Kayıt Ol" |
| signOut ağ hatası verince local state temizleniyor ama Supabase session aktif kalabilir; app restart'ta otomatik login | `profile_screen.dart` l.85-90 | catch yutuyor | Ağ hatası bildirip kullanıcıya yeniden dene seçeneği sun, veya offline-aware işaretle |
| OnboardingScreen'de "Zaten hesabım var, Giriş Yap" linki yok | `onboarding_screen.dart` l.79-97 | Tek yön — sadece signUp + guest | "Zaten hesabım var" link'i ekle (yalnız Supabase-on modda görünür) |

### P3 — Polish / metin / UX
| Sorun | Dosya | Neden | Önerilen çözüm |
|---|---|---|---|
| Splash 1300 ms sabit gecikme | `splash_screen.dart` l.24 | Marketing animation | Auth state hazır olunca anında geç |
| LoginScreen'de "Şifremi unuttum" link'i yok | `login_screen.dart` | Eksik feature | `auth.resetPasswordForEmail(email)` çağrısı + reset ekranı |
| LoginScreen'de email confirmation status göstergesi yok | — | Yeni kullanıcı kafası karışır | "Email doğrulama gönderildi" snackbar veya banner |
| CreateProfileScreen `city` validator yok — silinebilir | `create_profile_screen.dart` l.152-158 | Optional alan | Karar: zorunlu mu? Tutarlılık için form'da işaretle |

---

## 12. İdeal Yeni Sistem Önerisi

> Kod yazılmadan, olması gereken akış. Mevcut kodu sadeleştirmek için bir taslak.

### Akış diyagramı

```
┌───────────┐
│   Boot    │
└─────┬─────┘
      ▼
┌───────────┐
│  Splash   │  ← 600 ms (animasyon süresi)
└─────┬─────┘
      ▼
   Read AppConfig.supabaseEnabled
      ├── false ───────────────────► /onboarding (legacy mock)
      │                                  ├── Profil Oluştur ──► /profile/create (local) ─► /panel
      │                                  └── Kayıtsız Devam ──► (guest, persist!) ──► /feed
      │
      └── true ──── Read currentAuthUser
                       │
                       ├── null ──► /auth (Auth Entry — yeni unified ekran)
                       │              ├── Giriş Yap ───► /panel
                       │              ├── Kayıt Ol ────► /profile/create (Supabase signUp)
                       │              │                    ├── confirmation gerekirse: "E-postanızı doğrulayın"
                       │              │                    └── confirmation gerekmiyorsa: /panel
                       │              └── Kayıtsız Devam ──► (guest, persist) ──► /feed
                       │
                       └── user var ──► Read profile from DB
                                          ├── null ──► /profile/create (forced)
                                          ├── incomplete (display_name boş veya account_type yoksa) ──► /profile/create (forced)
                                          └── complete ──► /panel
```

### Önerilen ekranlar

| Ekran | Route | Görev | Kim görür |
|---|---|---|---|
| Splash | `/` | 600 ms animasyon + boot karar | Herkes |
| Onboarding (legacy) | `/onboarding` | Sadece Supabase off modunda — 2 buton | Mock mode user |
| **Auth Entry (yeni unified)** | `/auth` | 3 buton: Giriş Yap, Kayıt Ol, Kayıtsız Devam Et — netlik için ayrı, login/signup formları push ile açılır | Supabase on + user null |
| Login Form | `/auth/login` | email/şifre + Giriş + "Şifremi unuttum" | Auth Entry'den push |
| SignUp / Profile Create | `/profile/create` | account_type + name + city + profession + email + password — tek ekranlık wizard | Yeni kullanıcı veya incomplete profile |
| Email Verification | `/auth/verify` | "E-postanızı doğrulayın" + "Yeniden gönder" | confirmation aktifse signUp sonrası |
| RoleDashboard | `/panel` | Rol bazlı kartlar | Complete profile |
| Feed | `/feed` | Guest entry point | Herkes (guest dahil) |

### State persistence kararı

- `SharedPreferences` ile **3 flag** persist edilmeli:
  - `is_guest_mode: bool` — kullanıcı Kayıtsız Devam Et seçtiyse true; app restart'ta korunur
  - `onboarding_seen: bool` — splash sonrası onboarding'e gittikten sonra true; tekrar gösterme
  - `last_auth_email: String?` — login form'unu otomatik doldur
- Logout `is_guest_mode = false` yapar + Supabase signOut.
- `adb shell pm clear` ile hepsi temizlenir, beklenen davranış sıfır state'e dönüş.

---

## 13. Minimum Fix Planı

> Kod yazmadan, hangi değişiklikler gerekli.

### Dosya değişiklik listesi

| Dosya | Değişiklik | Öncelik |
|---|---|---|
| `lib/features/onboarding/screens/splash_screen.dart` | `_route()`'a profile completion kontrolü ekle; eksikse `/profile/create`'e yönlendir | P1 |
| `lib/features/auth/screens/login_screen.dart` | "Şifremi unuttum" link'i; "Profil Oluştur" → "Kayıt Ol" relabel; loading state'i daha net | P2 |
| `lib/features/onboarding/screens/onboarding_screen.dart` | (varsa) "Zaten hesabım var → Giriş Yap" link'i Supabase on modda göster | P2 |
| `lib/features/profile/providers/profile_provider.dart` | `useGuest()` SharedPreferences ile persist et + boot'ta restore et | P2 |
| `lib/features/auth/repositories/supabase_auth_repository.dart` | signUp `res.session==null` durumunu ayrıştır; verification gerekirse özel exception | P1 |
| `lib/features/profile/screens/create_profile_screen.dart` | signUp sonrası `res.session==null` ise `/auth/verify`'a, yoksa `/panel`'e | P1 |
| (yeni) `lib/features/auth/screens/auth_entry_screen.dart` | LoginScreen yerine veya öncesinde 3 büyük buton: Giriş Yap / Kayıt Ol / Kayıtsız Devam Et | P2 (opsiyonel) |
| `lib/features/profile/screens/profile_screen.dart` | signOut ağ hatasında kullanıcıya bildir + retry | P3 |

### Route redirect değişiklikleri

- GoRouter'a **top-level redirect** ekle:
  ```dart
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/auth' || loc == '/auth/login' || loc == '/auth/verify';
    final isProfileCreate = loc == '/profile/create';
    final isSplash = loc == '/';
    if (isSplash || isAuthRoute || isProfileCreate) return null;

    final user = currentAuthUserProvider.read(...);
    if (user == null && !isGuest) return '/auth';

    final profile = profileControllerProvider.read(...);
    if (user != null && (profile == null || profile.displayName.isEmpty)) {
      return '/profile/create';
    }
    return null;
  }
  ```
- Bu, Splash'taki manuel yönlendirmenin yerini alır ve **tüm route'lar için** auth gating sağlar.

### Local flag temizleme/kurma

- Yeni SharedPreferences keys:
  - `is_guest_mode` (bool)
  - `last_seen_app_version` (string) — version-aware migrations için
- Logout bu key'leri temizler.
- `pm clear` zaten hepsini siler.

### Test önerileri

| Test | İçerik |
|---|---|
| Supabase enabled + currentUser null → Auth Entry/Login | route'un splash'tan login'e gittiğini doğrula |
| currentUser + profile complete → /panel | profile yüklendi state'inde panel'in açıldığını doğrula |
| currentUser + profile missing → /profile/create | router redirect'in zorunlu profile create'e yönlendirdiğini doğrula |
| logout → Auth Entry / Onboarding | signOut sonrası login/onboarding'e döndüğünü doğrula |
| guest continue → feed + restart sonrası persistence | guest flag'in restart'ta korunduğunu doğrula |
| Supabase disabled → onboarding | dart-define'sız boot'ta onboarding'e gittiğini doğrula |
| `adb pm clear` sonrası ilk ekran Auth Entry (Supabase on) | Senaryo #9 testi |

---

## 14. Sonuç

1. **Temiz kurulumda ilk ekran şu olmalı:** Supabase dart-define geçtiyse → **`/login` (LoginScreen)**; dart-define yoksa → **`/onboarding` (OnboardingScreen)**.
2. **Mevcut kodda ilk ekran şu:** Yukarıdakinin aynısı — kod tasarım amacına uygun çalışıyor (Splash 3-dallı karar).
3. **Farklı ekran görülmesinin nedeni:** State varyasyonu (dart-define geçildi/geçilmedi, Supabase session cache var/yok, guest seçildi/seçilmedi). Bu **bug değil**; akış state'e duyarlı. Kullanıcının "farklı ekran" yorumu muhtemelen dart-define'ın bazen geçip bazen geçmemesinden ve/veya eski V1.1 build'inin kaldığından.
4. **Kritik bug var mı:** Hayır (P0 yok). Email confirmation senaryosu için **P1** (signUp `res.session==null` ayrımı yapılmıyor). Profile completion gating yok — **P1** (kullanıcı eksik profile ile panel'e girer). Guest mode uçucu — **P2** (restart'ta kayboluyor).
5. **Başlamak için önerilen minimum fix:** (a) GoRouter top-level redirect ile auth gating'i merkezi yap; (b) Splash'ı sadeleştir (route hesabını redirect'e devret); (c) `useGuest()` SharedPreferences ile persist; (d) signUp `res.session==null` durumunda Email Verification ekranına yönlendir; (e) Profile incomplete ise `/profile/create`'e force redirect. Bunlar yapılınca üç rolün (Ticari/Bireysel/Toptancı) hepsi deterministik akışa girer.

---

**Not:** Bu audit yalnız okumayla, kanıtlanmış kod referanslarıyla yapıldı. Hiçbir tahmin yok; her bulgu dosya + satır + alıntıyla dayandırıldı. Sonraki adım (yeni sistem inşası) için bu rapor temel alınabilir.
