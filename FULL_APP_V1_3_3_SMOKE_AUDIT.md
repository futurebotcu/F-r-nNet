# FULL_APP_V1_3_3_SMOKE_AUDIT

**Tarih:** 2026-05-13
**Tür:** Read-only sistemik smoke audit — V1.3.3 merkezi guest guard mimarisi sonrası.
**Kod değişikliği:** Yok. Sadece bu rapor dosyası yazıldı.
**Audit yöntemi:** (a) build/test komut çıktısı, (b) kaynak kod statik tarama (grep + read), (c) Supabase MCP tabloları + migration listesi + örnek profil sorgusu, (d) router katmanının statik route haritası.

> Etkileşimli emülatör tıklama smoke senin tarafında (görsel erişim yok). Bu rapor kod yolunu ve veritabanı durumunu doğrular; ekrandaki UX teyidi son adımdır.

---

## 1. Build / test durumu

| Kontrol | Çıktı |
|---|---|
| `git log -1` | `e51c726 fix(firinnet): centralize guest write guards` |
| Branch | `main`, `origin/main` ile senkron |
| Son 3 commit | `e51c726` (V1.3.3), `770b96b` (V1.3.2), `ebe7f2e` (V1.3.1) |
| `flutter analyze` | **No issues found** (0.6s) |
| `flutter test` | **151/151 yeşil** |
| Build/install (emülatör) | ✅ APK build + install + Supabase init başarılı (önceki turdan log: `Supabase init completed`) |

---

## 2. Auth Entry smoke (kod doğrulaması)

`lib/features/auth/screens/auth_entry_screen.dart` 3 buton render eder; her biri net bir route'a gider:

| Buton | Hangi koşul | Hedef |
|---|---|---|
| **Giriş Yap** (AppPrimaryButton copper) | `supabaseOn` true ise aktif | `context.push(AppRoutes.login)` → `/login` |
| **Hesabım yok, üye ol** (OutlinedButton) | `supabaseOn` true ise aktif | `context.push(AppRoutes.roleSelect)` → `/auth/role-select` |
| **Kayıtsız devam et** (TextButton muted) | Daima aktif | `guestModeProvider.setGuest(true)` + `profileController.useGuest()` + `context.go(AppRoutes.feed)` |

**Splash karar mantığı** (`splash_screen.dart`):
```
supabaseEnabled=false + guest=false → /auth
supabaseEnabled=false + guest=true  → /feed
supabaseEnabled=true + user=null + guest=false → /auth
supabaseEnabled=true + user=null + guest=true  → /feed
supabaseEnabled=true + user var + profile.isComplete → /panel
supabaseEnabled=true + user var + profile null/incomplete → /profile/create
```

**Sonuç:** ✅ Kod tarafında akış net ve tutarlı.

---

## 3. Guest read-only smoke (kod doğrulaması)

Aşağıdaki ekranların hiçbirinde guard yok — read forwards inner'a:

| Ekran | Repo (Guarded read) | Guard durumu |
|---|---|---|
| FeedScreen — `listPosts` | `GuardedFeedRepository.listPosts` → inner | ✅ Forwards |
| FeedScreen — `listInsights` | `GuardedFeedRepository.listInsights` → inner | ✅ Forwards |
| GroupsListScreen — `listGroups`, `listPopular`, `listJoined` | `GuardedSocialGroupRepository` reads | ✅ Forwards |
| GroupDetailScreen — `getGroup`, `listMessages`, `isJoined` | `GuardedSocialGroupRepository` reads | ✅ Forwards |
| MarketplaceScreen | Static const array (repo yok) | ✅ Açık |
| JobsScreen | Static const array (repo yok) | ✅ Açık |
| RecipesListScreen — `list` | `GuardedRecipeRepository.list` → inner | ✅ Forwards |
| RecipeDetailScreen — `getById` | `GuardedRecipeRepository.getById` → inner | ✅ Forwards |
| CalculatorScreen — `RecipeCalculator.calculateFromQuantities` | Stateless service | ✅ Açık |
| Profile "Açık Reçeteler" — `listPublicByOwner` | Read forwards | ✅ Forwards |

**Dış paylaşım butonları** (`Share.share` / `Share.shareXFiles`): 8 noktada doğrulandı, hiçbirinde guard yok.
- `calculator_screen.dart:132` — Hesap sonucu sistem chooser
- `recipes_list_screen.dart:231` — Kart paylaşımı
- `recipe_detail_screen.dart:866` — Sistem paylaşım sheet seçeneği
- `report_screen.dart:85` — Gün sonu raporu
- `dealer_share_screen.dart:108` + `:200` — Bayi cari + PDF
- `job_seek_posts_screen.dart:138` — Kart paylaşım
- `job_seek_post_form_screen.dart:157` — Form preview

**Sonuç:** ✅ Tüm read + external share serbest.

---

## 4. Guest blocked-write smoke (kod doğrulaması)

V1.3.3 mimarisinde her write 2 katmanda korunuyor:

### Katman A — UI (önceden engelleme, hızlı UX)

`AuthRequiredGuard.canWriteWithRef(ref)` + `showAuthRequiredSheet` kullanımı: **17 dosya** doğrulandı (grep).

### Katman B — Repository (authoritative — yeni write metodu eklenirse otomatik korur)

`_requireWrite(action)` çağrısı: **22 kez** 7 wrapper'da (grep).

### Tam guard matrisi

| # | İşlem | UI guard | Repo wrapper | UI sitesi |
|---|---|---|---|---|
| 1 | Feed post oluştur | ✅ canWriteWithRef | ✅ `_requireWrite('feed gönderisi paylaşmak')` | feed_composer.dart `_submit` |
| 2 | Feed beğen | ✅ canWriteWithRef | ✅ `_requireWrite('gönderiyi beğenmek')` | feed_screen.dart `onLike` |
| 3 | Feed kaydet | ✅ canWriteWithRef | ✅ `_requireWrite('gönderiyi kaydetmek')` | feed_screen.dart `onSave` |
| 4 | Gruba katıl (Feed) | ✅ runGuardedMutation | ✅ `_requireWrite('gruba katılmak')` | feed_screen.dart `onPrimary` |
| 5 | Gruba katıl (Groups list) | ✅ runGuardedMutation | ✅ (aynı) | groups_list_screen.dart `onPrimary` |
| 6 | Gruba katıl (Group detail) | ✅ runGuardedMutation | ✅ (aynı) | group_detail_screen.dart join |
| 7 | Gruptan ayrıl | ✅ runGuardedMutation | ✅ `_requireWrite('gruptan ayrılmak')` | group_detail_screen.dart leave |
| 8 | Grup oluştur | ✅ runGuardedMutation | ✅ `_requireWrite('grup oluşturmak')` | group_create_screen.dart `_save` |
| 9 | Grup mesajı gönder | ✅ canWriteWithRef | ✅ `_requireWrite('grup mesajı göndermek')` | group_detail_screen.dart `_Composer._send` |
| 10 | Reçete kaydet | ✅ canWriteWithRef | ✅ `_requireWrite('reçete kaydetmek')` | recipe_editor_screen.dart `_save` |
| 11 | Reçete sil | ✅ canWriteWithRef | ✅ `_requireWrite('reçete silmek')` | recipe_detail_screen.dart `_confirmDelete` |
| 12 | Reçete "Feed'de paylaş" | ✅ canWriteWithRef | ✅ (`addPost` via Feed) | recipe_detail_screen.dart `_shareToFeed` |
| 13 | Üretim kaydet | ✅ runOrPrompt | ✅ `_requireWrite('üretim kaydı girmek')` | production_entry_screen.dart `_save` |
| 14 | Fire kaydet | ✅ runOrPrompt | ✅ `_requireWrite('fire kaydı girmek')` | waste_entry_screen.dart `_save` |
| 15 | Bayi/Müşteri ekle | ✅ canWriteWithRef | ✅ `_requireWrite('bayi/müşteri eklemek')` | add_dealer_screen.dart `_save` |
| 16 | Bayiye ürün ver (delivery) | ✅ canWriteWithRef | ✅ `_requireWrite('teslimat kaydetmek')` | dealer_delivery_form_screen.dart `_save` |
| 17 | Tahsilat al | ✅ canWriteWithRef | ✅ `_requireWrite('tahsilat kaydetmek')` | dealer_payment_form_screen.dart `_save` |
| 18 | İade al | ✅ canWriteWithRef | ✅ `_requireWrite('iade kaydetmek')` | dealer_return_form_screen.dart `_save` |
| 19 | Düzeltme | ✅ canWriteWithRef | ✅ `_requireWrite('bakiye düzeltmesi yapmak')` | dealer_adjustment_form_screen.dart `_save` |
| 20 | Bayi fiyat ekle | ✅ canWriteWithRef | ✅ `_requireWrite('bayi fiyatı eklemek')` | dealer_detail_screen.dart `_PriceSheet._save` |
| 21 | Bayi not ekle | ✅ canWriteWithRef | ✅ `_requireWrite('bayi notu eklemek')` | dealer_detail_screen.dart `_NotesCard._add` |
| 22 | İş arıyorum ilanı oluştur/güncelle | ✅ canWriteWithRef | ✅ `_requireWrite('iş arıyorum ilanı kaydetmek')` | job_seek_post_form_screen.dart `_save` |
| 23 | İş ilanı yayında/pasif toggle | ✅ runGuardedMutation | ✅ (aynı upsert path) | job_seek_posts_screen.dart `_toggleActive` |
| 24 | İş ilanı sil | ✅ runGuardedMutation | ✅ `_requireWrite('iş arıyorum ilanı silmek')` | job_seek_posts_screen.dart `_delete` |
| 25 | Ustalık profili kaydet | ✅ canWriteWithRef | ✅ `_requireWrite('ustalık profili kaydetmek')` | worker_profile_screen.dart `_save` |
| 26 | Tecrübe ekle | ✅ canWriteWithRef | ✅ `_requireWrite('tecrübe eklemek')` | worker_experiences_screen.dart `_AddExperienceSheet._save` |
| 27 | Tecrübe sil | ✅ runGuardedMutation | ✅ `_requireWrite('tecrübe silmek')` | worker_experiences_screen.dart `_ExperienceCard._confirmDelete` |
| 28 | Profil güncelle | ✅ CreateProfileScreen `_save` UI guard | ✅ `_requireWrite('profili güncellemek')` | profile_provider.dart `ProfileController.save` |
| L1 | Latent — Dealer setActive | (UI yok) | ✅ `_requireWrite('bayi durumunu güncellemek')` | API açık, gelecek UI'ya otomatik koruma |
| L2 | Latent — Bakery addDelivery | (route silindi) | ✅ `_requireWrite('bayiye teslimat girmek')` | `/panel/dealer` redirect ile kapatıldı |

**Çift katman doğrulandı.** UI sayısı (17 dosya) + repo wrapper (22 metod) + 7 runGuardedMutation kullanım = defense-in-depth aktif.

> Etkileşimli teyit: emülatörde her butonu tek tek tıklayıp sheet açılışını gözlemlemek senin tarafında. Kod tarafı kanıtlandı.

---

## 5. Auth kullanıcı smoke (kod doğrulaması + Supabase)

### Supabase'deki test kullanıcısı

```sql
SELECT id, email, account_type, display_name, profession_badge, city FROM profiles LIMIT 5;
```

Çıktı:
```
id:               abf96b42-0d17-40b1-9b0f-cbf910f9e2a4
email:            fatihkartal75@gmail.com
account_type:     commercial
display_name:     Fatih
profession_badge: Usta Fırıncı
city:             Manisa
```

✅ Profil **complete** (`displayName` + `accountType` + `city` + `roleBadge` hepsi dolu). `BakeryProfile.isComplete` true dönmeli.

### Beklenen akış (kod ile doğrulandı)

1. LoginScreen email/şifre → `auth.signIn(...)` (`SupabaseAuthRepository.signIn`).
2. signIn başarılı → `guestModeProvider.setGuest(false)` + `context.go(AppRoutes.splash)`.
3. Splash → user var + profile complete → `/panel`.
4. RoleDashboardScreen → `account = commercial` → `RolePanelCards.forAccount(commercial)` 6 kart döner:
   - Fırın Paneli → `/panel/bakery`
   - Bayi Paneli → `/dealers`
   - Hesaplama Makinesi → `/calculator`
   - Reçetelerim → `/recipes`
   - İlanlarım → `/jobs`
   - Mesajlar (comingSoon)

**Etkileşimli teyit gereken:** Login formundan başarılı giriş + panel render. Kod tarafı doğru, runtime ağ/auth bağlantısı senin emülatörde teyit edilecek.

---

## 6. Ticari panel smoke (kod doğrulaması)

`BakeryPanelScreen` (`/panel/bakery`) içerik:
- Hero card (`todaySummaryProvider`)
- Üretim Yönetimi: Featured tile **Reçeteler → /recipes** + 4 mini (Üretim Gir → `/panel/production`, Fire Gir → `/panel/waste`, Gün Sonu → `/panel/end-of-day`, Rapor Al → `/panel/report`)
- Bayi Yönetimi özet kartı → `/dealers`
- Son hareketler liste
- 3 statik topluluk ipucu

### Bayi Detay aksiyon zinciri

| Aksiyon | Form | Kayıt | Supabase tablosu |
|---|---|---|---|
| Ürün Ver | DealerDeliveryFormScreen | `dealer_deliveries` + `dealer_delivery_items` (trigger toplam hesap) | ✅ |
| İade Al | DealerReturnFormScreen | `dealer_transactions` (type=return) | ✅ V1.2 |
| Ödeme Al | DealerPaymentFormScreen | `dealer_transactions` (type=payment) | ✅ V1.2 |
| Düzeltme | DealerAdjustmentFormScreen | `dealer_transactions` (type=adjustment) | ✅ V1.2 |
| Fiyat ekle | _PriceSheet (bottom sheet) | `dealer_prices` | ✅ V1.2 |
| Not ekle | _NotesCard | `dealer_notes` | ✅ V1.2 |
| Hesap Paylaş | DealerShareScreen | `Share.share` + `Share.shareXFiles` (PDF) | ✅ Dış paylaşım |

**Cari/kalan hesap:** `DealerBalanceService.summarize(transactions)` — V1.2'den beri tüm transaction kanallarını okur (delivery via `_fetchDeliveriesAsTransactions`, geri kalan via `_fetchExtrasAsTransactions`). Hibrit local-only kısıtı V1.2'de kapatılmıştı.

**Etkileşimli teyit gereken:** Auth Fatih ile bayi ekle/teslimat/tahsilat → Supabase'e gerçek satır düşmesini doğrula. Kod tarafı doğru.

---

## 7. Bireysel panel smoke (kod doğrulaması)

`RolePanelCards.forAccount(individual)` 8 kart döner:
1. İş Arıyorum İlanı Ver → `/worker/job-seek`
2. Ustalık Bilgilerim → `/worker/profile`
3. Çalışma Geçmişim → `/worker/experiences`
4. Hesaplama Makinesi → `/calculator`
5. Reçetelerim → `/recipes`
6. İş İlanları → `/jobs`
7. Mesajlar (comingSoon)
8. Profilim → `/profile`

### Worker akışı doğrulaması

| Ekran | İşlem | Repository | Guard |
|---|---|---|---|
| WorkerProfileScreen | upsertMyProfile | `GuardedWorkerRepository` | ✅ |
| WorkerExperiencesScreen + AddSheet | addExperience | `GuardedWorkerRepository` | ✅ |
| WorkerExperiencesScreen card delete | deleteExperience | `GuardedWorkerRepository` | ✅ |
| JobSeekPostFormScreen | upsertJobSeekPost | `GuardedWorkerRepository` | ✅ |
| JobSeekPostsScreen toggle/delete | upsert/delete | `GuardedWorkerRepository` | ✅ |
| `Share.share` per ilan | external | (repo yok) | ✅ Açık |

**Supabase tabloları:** `worker_profiles`, `worker_experiences`, `job_seek_posts` — hepsi RLS owner CRUD + authenticated read (V1.2 migration).

**Etkileşimli teyit gereken:** Bireysel role'lü test kullanıcı oluşturup full akış (profil + tecrübe + ilan) Supabase'e düşmesini doğrula.

---

## 8. Toptancı panel smoke (kod doğrulaması)

`RolePanelCards.forAccount(wholesaler)` 5 kart:
1. Müşteriler / Bayiler → `/wholesale/customers` ✅
2. Ürün/Hizmet İlanı Ver (comingSoon — Marketplace yayın akışı V1.3+ scope dışı)
3. Firma Profilim → `/profile` (genel profil, ayrı UI yok)
4. Gelen Mesajlar (comingSoon)
5. Duyuru / Fiyat Listesi (comingSoon)

### Wholesale flow

- `WholesaleCustomersScreen` `dealers` tablosu filter `customer_type='wholesale_customer'` ile.
- "Müşteri Ekle" → `AddDealerScreen(customerType: wholesaleCustomer)` → aynı `upsertDealer` (guarded).
- Detay/teslimat/tahsilat → mevcut DealerDetailScreen reuse (ticari ile aynı altyapı).

**comingSoon kartlar:** Brief'le uyumlu — V1.3'te ürün ilan yayın akışı + mesajlaşma + duyuru/fiyat listesi yapılmadı. Kart `route: null` + `comingSoon: true` → RoleDashboard'da snackbar "yakında".

---

## 9. Supabase kayıt doğrulamaları

### Migration listesi (MCP `list_migrations`)
9 migration uygulanmış, hepsi V1+V1.1+V1.2 schema:
1. `20260512075056_firinnet_v1_core_schema`
2. `20260512075421_firinnet_v1_grants_authenticated`
3. `20260512075525_firinnet_v1_revoke_trigger_fn_execute`
4. `20260512080338_firinnet_v1_auth_user_handler`
5. `20260512080804_firinnet_v1_auth_email_sync`
6. `20260513071839_firinnet_recipe_metadata_jsonb`
7. `20260513073915_firinnet_recipe_visibility`
8. `20260513083818_firinnet_dealer_v1_2_extensions`
9. `20260513083857_firinnet_worker_and_jobseek`

> **V1.3.x'te yeni migration yok.** Guest guard sistemi tamamen Flutter katmanında; Supabase RLS owner-only zaten authoritative.

### Tablolar (MCP `list_tables`) — 15 tablo, hepsi `rls_enabled: true`

| Tablo | RLS | Rows | Sahibi |
|---|---|---|---|
| profiles | ✅ | 1 | Fatih |
| bakeries | ✅ | 0 | — |
| bakery_products | ✅ | 0 | — |
| recipe_calculations | ✅ | 0 | — |
| production_entries | ✅ | 0 | — |
| dealers | ✅ | 0 | — |
| dealer_deliveries | ✅ | 0 | — |
| dealer_delivery_items | ✅ | 0 | — |
| dealer_transactions | ✅ | 0 | — V1.2 |
| dealer_prices | ✅ | 0 | — V1.2 |
| dealer_notes | ✅ | 0 | — V1.2 |
| waste_entries | ✅ | 0 | — |
| worker_profiles | ✅ | 0 | — V1.2 |
| worker_experiences | ✅ | 0 | — V1.2 |
| job_seek_posts | ✅ | 0 | — V1.2 |

**Etkileşimli teyit:** Fatih ile login → bayi/üretim/reçete vs kayıt → tablolardaki rows artmalı.

---

## 10. Route / deeplink audit

`AppRoutes` 27 sabit + 5 path-param route:

### Ana route'lar
| Route | Hedef | Durum |
|---|---|---|
| `/` (splash) | SplashScreen | ✅ 6-yollu karar |
| `/auth` | AuthEntryScreen | ✅ |
| `/auth/role-select` | RoleSelectScreen | ✅ |
| `/login` | LoginScreen | ✅ |
| `/profile/create` | CreateProfileScreen (`?role=`) | ✅ |
| `/profile` | ProfileScreen | ✅ |
| `/feed`, `/groups`, `/market`, `/jobs`, `/panel` | Shell tab'lar | ✅ |
| `/panel/bakery` | BakeryPanelScreen | ✅ |
| `/panel/production` | ProductionEntryScreen | ✅ |
| `/panel/waste` | WasteEntryScreen | ✅ |
| `/panel/end-of-day` | EndOfDayScreen | ✅ |
| `/panel/report` | ReportScreen | ✅ |
| `/calculator` | CalculatorScreen | ✅ |
| `/recipes`, `/recipes/new`, `/recipes/:id`, `/recipes/:id/edit` | RecipesListScreen + Editor + Detail | ✅ |
| `/dealers`, `/dealers/new` | DealerListScreen + AddDealerScreen | ✅ |
| `/dealers/:id{,/delivery,/return,/payment,/share,/adjustment}` | DealerDetail + form'lar | ✅ |
| `/wholesale/customers`, `/wholesale/customers/new` | WholesaleCustomersScreen | ✅ |
| `/worker/profile`, `/worker/experiences`, `/worker/job-seek`, `/worker/job-seek/new`, `/worker/job-seek/:id/edit` | Worker ekranları | ✅ |
| `/groups/create`, `/groups/:id` | GroupCreate + Detail | ✅ |

### Legacy redirect (V1.3.3 hardening)
| Route | Davranış |
|---|---|
| `/onboarding` | OnboardingScreen olarak hâlâ erişilebilir (legacy). Splash buraya gitmiyor. |
| `/panel/recipe` | Redirect → `/recipes` |
| **`/panel/dealer`** | **Redirect → `/dealers`** (V1.3.3'te eklendi, DealerDeliveryScreen silindi) |

**Bozuk/silinmiş route:** Yok. Tüm route'lar yaşıyor.

---

## 11. Bulunan buglar (kod statik audit)

### P0 — Bloker
**(Yok.)**

### P1 — Kullanıcı akışını yanlış yönlendiren
**(Yok — V1.3.2 P1 sorunları V1.3.3 ile kapatıldı: joinGroup 3 nokta, leaveGroup, createGroup, jobseek toggle/delete, experience delete.)**

### P2 — Kafa karıştırıcı veya yarım kalmış
| # | Sorun | Konum | Detay |
|---|---|---|---|
| P2-1 | `Recipe public toggle` UI'da ayrı buton yok, sadece editor save'in içinde | recipe_editor_screen.dart | Brief'te "Reçeteyi profilde açık yap" ayrı eylem olabilir; şu an save'in parçası. Tasarım kararı, bug değil ama "ayrı kontrol istiyorum" diyebilirsin. |
| P2-2 | `dealer_delivery_form_screen.dart:_save` validate yapıyor ama validation hatası snackbar formatı eski (`_err` callback). Mevcut, çalışıyor. | Bayi delivery | Polish. |
| P2-3 | `LoginScreen` "Şifremi unuttum" link'i yok | login_screen.dart | Şifre reset akışı yok; Supabase `auth.resetPasswordForEmail` API'si kullanılmıyor. |
| P2-4 | `CreateProfileScreen` SignUp `res.session==null` durumu (email confirmation aktif olursa) `/panel`'e atar ama session yok → panel'de StateError | create_profile_screen.dart | Audit'te tespit edildi. Supabase confirm-email ayarı şu an dashboard'dan kapalı varsayılıyor; aktif edilirse P1'e çıkar. |
| P2-5 | "Mesajlar" 3 rolde de comingSoon | role_panel_cards.dart | DM altyapısı yok; V2. |

### Polish (P3)
| # | Sorun | Konum |
|---|---|---|
| P3-1 | OnboardingScreen erişilemez ama silinmedi | `lib/features/onboarding/screens/onboarding_screen.dart` |
| P3-2 | `GuestActionRequiredException.toString()` İngilizce | `auth_required_guard.dart` |
| P3-3 | Splash 700 ms sabit gecikme | `splash_screen.dart` |
| P3-4 | "İlanlarım" ticari kartı `/jobs` tabına atıyor ama owner filtresi yok | RolePanelCards |
| P3-5 | Static topluluk ipuçları bakery panel altında durağan | `bakery_panel_screen.dart._CommunityTips` |
| P3-6 | Comment akışı (FeedActionCommentSnack) comingSoon | feed |
| P3-7 | Wholesale "Firma Profilim" generic profile screen kullanıyor | role_panel_cards.dart |
| P3-8 | Reçete medya upload (foto/video) placeholder | recipe editor + detail |
| P3-9 | Group invite/favorite/notification toggle yok (V2 alanı) | groups |

### Latent (kapalı, kod ekleyince açılır)
| # | Konum | Açıklama |
|---|---|---|
| L-1 | DealerRepository `setActive` UI'da çağrılmıyor; UI eklenirse Guarded wrapper otomatik koruma yapıyor. | dealer_detail/list ekranlarına aktif/pasif toggle eklenirse extra guard adımı gerekmez |
| L-2 | ProfileRepository `updateProfile` yalnız `CreateProfileScreen` `_save` üzerinden çağrılıyor; ayrı "Profili Düzenle" UI eklenirse aynı Guarded wrapper koruyor | profile |

---

## 12. Düzeltme önceliği (sıralı)

### Hemen ele alınmaması durumunda kullanıcıya etkisi olmayanlar (P3 / Polish)
- OnboardingScreen siliminin yapılması (~5 dakika temizlik)
- GuestActionRequiredException toString Türkçeleştirme
- Splash gecikmesi event-driven yapılması

### Konfor (P2)
- LoginScreen "Şifremi unuttum"
- Reçete public toggle ayrı eylem
- Mesajlaşma altyapısı (3 rol comingSoon)

### Email confirmation handling (P2→P1 olabilir)
- Dashboard'da "Confirm email" açıldığı an P1'e çıkar. Şu an kapalı varsayımı geçerli mi? Dashboard'a bakman lazım. Audit kod yolunda sadece `res.session != null` varsayımı var.

### V1.3.4+ scope kalan büyük işler (V2)
- Mesajlaşma (DM + grup gerçek backend)
- Toptancı ürün/hizmet ilan yayın akışı (Marketplace gerçek backend)
- Reçete medya upload (Supabase Storage)
- JobsScreen / MarketplaceScreen gerçek backend
- "Profili Düzenle" ayrı akış

---

## 13. Sonuç ve son adım

**V1.3.3 sonrası kod katmanı temiz oturdu.**

- ✅ Build/test sağlıklı (151/151)
- ✅ Auth Entry 3 buton + Splash 6-yollu karar
- ✅ Guest read + external share serbest (verified)
- ✅ 28 write noktasının tümü 2 katmanda guarded (UI + repo)
- ✅ Supabase 15 tablo, hepsinde RLS, Fatih test kullanıcısı complete profile
- ✅ Route haritası 27+ route, legacy redirectler yerinde
- ✅ P0/P1 bug yok

**Son adım — etkileşimli emülatör smoke senin tarafında:**

1. Fatih ile login → /panel kartlarını gör
2. Üretim/fire/bayi kayıtları → Supabase tablolarına satır düştüğünü gör
3. Logout → guest mode geç → her yazma noktasında AuthRequired sheet açıldığını gör
4. Hesaplama Makinesi + dış paylaşım serbest çalıştığını gör

Bulduğun her UX/davranış anomalisini buraya **"P0 emülatör smoke buldu"** olarak ekle; sonraki turda P0/P1 sırasıyla kapatırız.
