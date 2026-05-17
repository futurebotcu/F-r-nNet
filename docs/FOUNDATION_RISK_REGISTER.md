# FırınNet Foundation Risk Register

> Bu dosya 10/10 Risk Discovery (2026-05-17) ve U-1 Unknown Write Action Discovery sonuçlarının yaşayan kaydıdır. Her risk patch'i bu dosyayı güncellemelidir. Risk durumları yalnız kanıtla (commit/test/smoke) değiştirilir.

**Son güncelleme:** 2026-05-17
**Kanıt:** [10/10 Risk Discovery Report](#) (chat geçmişi) + [U-1 Discovery Report](#) (chat geçmişi)

---

## Status Summary

| Alan | Değer |
|---|---|
| Current foundation score | **8-9/10** |
| Code-side open P0 | **none** |
| Store/release P0 | hosted Privacy URL, hosted account deletion URL, store listing assets |
| Unknown write actions | **resolved** (U-1: 0 remaining) |
| Last verified remote main | `f1020f7 chore(firinnet): autoDispose stale-cache prone providers` |
| `flutter analyze` baseline | `No issues found` |
| `flutter test` baseline | `303/303 passed` |
| Supabase project_ref | `sjeqwiqgwzagengdukye` |
| Edge function `delete-account` | v1 ACTIVE, `verify_jwt: true` |
| Closed risks | P0.1 (b23956c), P1.1 (f1020f7) |

---

## Risk Status Legend

| Durum | Anlam |
|---|---|
| `OPEN` | Tespit edildi, patch yok |
| `IN_PROGRESS` | Patch yazılıyor |
| `FIXED` | Patch atıldı (commit var) |
| `VERIFIED` | Patch + test + smoke geçti |
| `DEFERRED` | Karar verildi, ileri sprint'e ertelendi |
| `NOT_IMPLEMENTED_IN_V1` | Repo katmanı hazır, UI surface V1'de yok (feature backlog) |

---

## Closed Risks

| ID | Title | Severity | Status | Commit | Test | Smoke | Notes |
|---|---|---|---|---|---|---|---|
| P0.1 | Feed composer `addPost` error handling | P0 | FIXED | `b23956c` | `test/feed_composer_error_test.dart` (2 yeni), 303/303 | offline composer smoke önerilir | try/catch/finally + Türkçe error snackbar + mounted guard + text korunur |
| P1.1 | Provider stale-cache autoDispose | P1 | FIXED | `f1020f7` | 303/303 (regresyon yok) | optional | `recipesListProvider`, `todaySummaryProvider`, `activeJobOffersProvider`, `myWorkerProfileProvider` |
| P1.23 | Dealer note add loading-stuck on error | P1-HIGH | FIXED | `73034df` | `test/dealer_note_add_error_test.dart`, 305/305 | dealer note offline smoke önerilir | try/catch/finally + Türkçe snackbar + saving reset; `NotesCard` library-public (test için 1-karakter görünürlük değişimi) |
| P1.18 | Feed like toggle no try/catch | P1 | FIXED | `55ea49b` | `test/feed_group_write_error_test.dart`, 309/309 | feed offline like smoke önerilir | try/catch + Türkçe snackbar + guest guard korunur |
| P1.19 | Feed save toggle no try/catch | P1 | FIXED | `55ea49b` | `test/feed_group_write_error_test.dart`, 309/309 | feed offline save smoke önerilir | try/catch + Türkçe snackbar + guest guard korunur |
| P1.20 | Group leave non-guest errors propagate | P1 | FIXED | `55ea49b` | `test/feed_group_write_error_test.dart`, 309/309 | group offline leave smoke önerilir | try/catch + Türkçe snackbar + runGuardedMutation guest contract korunur |
| P1.21 | Group message send no error UX | P1 | FIXED | `55ea49b` | `test/feed_group_write_error_test.dart`, 309/309 | group offline message smoke önerilir | try/catch + Türkçe snackbar + input korunur |

---

## Open Store/Release P0

Bu üçü **kod değil**, ürün kararı + hosting + asset üretimi gerektirir.

| ID | Title | Severity | Status | Notes |
|---|---|---|---|---|
| P0-A | Hosted Privacy Policy URL missing | P0 | OPEN | In-app `privacy_screen.dart` "V1 draft" banner var; Play Console external URL ister |
| P0-B | Hosted account deletion URL missing | P0 | OPEN | In-app `delete-account` Edge Function ACTIVE; Play Store 2024+ web mirror istiyor |
| P0-C | Store listing assets missing | P0 | OPEN | `store/`/`marketing/` klasörü yok; ≥2 screenshot 1080×1920 + 1024×500 feature graphic gerekli |

---

## Open Code/Quality P1

### Foundation Hardening Audit'ten gelen (prior)

| ID | Title | Severity | Status | Source | Notes |
|---|---|---|---|---|---|
| P1.2 | SplashScreen Timer cancel in `dispose()` | P1 | OPEN | `splash_screen.dart:39` | `_routed` flag double-route kapatıyor ama Timer kaynak |
| P1.3 | `performDeleteAccount` state cleanup ordering | P1 | OPEN | `auth_actions.dart:82-89` | await sıralaması + snackbar/go race |
| P1.4 | Guest + Supabase session mutual exclusion guard | P1 | OPEN | `splash_screen.dart` redirect logic | defensive: `if (user!=null && isGuest) setGuest(false)` |
| P1.5 | `CreateProfileScreen` hydrate-then-submit guard | P1 | OPEN | `create_profile_screen.dart:89-126` | `_profileHydrated` UI'yı kontrol ediyor ama submit'i değil |
| P1.6 | Recipe save missing catch | P1 | OPEN | `recipe_editor_screen.dart` | try var, catch yok; raw `Kaydedilemedi: $e` |
| P1.7 | Dealer form save try/catch gaps | P1 | OPEN | `dealer_delivery/payment/return/adjustment_form_screen.dart` × 4 | try/catch yok |
| P1.8 | Worker / job seek raw error mapping | P1 | OPEN | `worker_profile_screen.dart:132`, `job_seek_post_form_screen.dart:93` | `Kaydedilemedi: $e` raw EN |
| P1.9 | Email confirmation deep link state restore | P1 | OPEN | `app_router.dart` redirect callback yok | confirmation link app dışında açılırsa state kaybı |
| P1.10 | `translate_data_error` helper + 10 Supabase repo wire | P1 | OPEN | `lib/core/utils/` (yeni) | PostgrestException → Türkçe (P1.8 otomatik kapanır) |
| P1.11 | Additional provider `autoDispose` candidates | P1 | OPEN | 6 provider: `myJobOffersProvider`, `myMarketListingsProvider`, `myWorkerExperiencesProvider`, `myJobSeekPostsProvider`, `activeJobSeekPostsProvider`, `guestModeBootProvider` | P1.1 pattern repeat |
| P1.12 | Legal text final hukuki review | P1 | OPEN | `privacy_screen.dart:120-151`, `terms_screen.dart:120-151` | "V1 draft" banner kaldırılmadan release yok |
| P1.13 | Crashlytics / observability | P1 | OPEN | `pubspec.yaml` firebase yok, `main.dart` FlutterError.onError hook yok | Firebase Crashlytics veya Sentry |
| P1.14 | Repo hygiene `.gitignore` gaps | P1 | OPEN | root `*.png`, `MCP_*.txt`, audit `*.md` pattern eksik | pattern ekle veya `docs/audit-archive/` taşı |
| P1.15 | Supabase HIBP leaked password protection | P1 | OPEN | Auth dashboard ayarı (advisor WARN) | Dashboard → Auth → Password Security |
| P1.16 | `auth_required_guard` prior risks dokümantasyon/test | P1 | OPEN | `auth_required_guard.dart` 5 prior hidden risk | hâlâ kodda; doc/test kapsamı eksik |
| P1.17 | `USING true` policy yorum/test | P1 | OPEN | `feed_likes`, `worker_experiences`, `worker_profiles` SELECT policies | kasıtlı community visibility ama explicit comment yok |

### U-1 Unknown Write Action Discovery'den gelen (2026-05-17 yeni bulgular)

| ID | Title | Severity | Status | Source | Notes |
|---|---|---|---|---|---|
| P1.18 | Feed like toggle no try/catch | P1 | FIXED | `feed_screen.dart:351-367` | Fixed by commit `55ea49b`. try/catch + `AppStrings.feedLikeUpdateError`; `on GuestActionRequiredException` ile defense-in-depth sheet açma korunuyor; `_PostCardWired` → `PostCardWired` (test için 1-karakter görünürlük). Test: `test/feed_group_write_error_test.dart`. Full suite: 309/309 passed. |
| P1.19 | Feed save toggle no try/catch | P1 | FIXED | `feed_screen.dart:368-384` | Fixed by commit `55ea49b`. try/catch + `AppStrings.feedSaveUpdateError`; aynı `PostCardWired` ortak görünürlük değişimi P1.18 ile. Test: `test/feed_group_write_error_test.dart`. Full suite: 309/309 passed. |
| P1.20 | Group leave non-guest errors propagate | P1 | FIXED | `group_detail_screen.dart:432-453` | Fixed by commit `55ea49b`. Leave branch'i `runGuardedMutation` içinde try/catch; `on GuestActionRequiredException` rethrow ile guest sheet davranışı korunur; non-guest hatada `AppStrings.groupLeaveError` snackbar; `_PrimaryAction` → `PrimaryActionButton` (test için 1-karakter görünürlük). Test: `test/feed_group_write_error_test.dart`. Full suite: 309/309 passed. |
| P1.21 | Group message send no error UX | P1 | FIXED | `group_detail_screen.dart:681-703` | Fixed by commit `55ea49b`. `_send` try/catch + `AppStrings.groupMessageSendError`; mesaj metni hata durumunda input'ta korunur; `on GuestActionRequiredException` ile defense-in-depth sheet; `_Composer` → `GroupComposer` (test için 1-karakter görünürlük). Test: `test/feed_group_write_error_test.dart`. Full suite: 309/309 passed. |
| P1.22 | Dealer price update no try/catch | P1 | IN_PROGRESS | `dealer_detail_screen.dart:713-747` | Patch hazır: `_save` try/catch + `AppStrings.dealerPriceSaveError`; hata yolunda sheet AÇIK kalır (Navigator.pop çağrılmaz) ki kullanıcı tekrar deneyebilsin; `on GuestActionRequiredException` ile defense-in-depth sheet; `_PriceSheet` → `DealerPriceSheet` (test için 1-karakter görünürlük). Test: `test/dealer_job_seek_write_error_test.dart`. Commit/push bekliyor. |
| **P1.23** | **Dealer note add LOADING STUCK on error** | **P1-HIGH** | **FIXED** | `dealer_detail_screen.dart:1172-1208` | Fixed by commit `73034df`. try/catch/finally `repo.addNote` çağrısının etrafına eklendi; Türkçe error snackbar "Not eklenemedi. Lütfen tekrar dene."; `_saving` finally bloğunda `if (mounted)` guard ile reset; hata durumunda kullanıcı not metni input'ta korunuyor; `NotesCard` library-public (test için 1-karakter görünürlük değişimi). Test: `test/dealer_note_add_error_test.dart` (error path + success regression). Full suite: 305/305 passed. |
| P1.24 | Job seek post toggle silent | P1 | IN_PROGRESS | `job_seek_posts_screen.dart:167-178` | Patch hazır: `_toggleActive` action içinde try/catch + `AppStrings.jobSeekPostToggleError`; `on GuestActionRequiredException` rethrow ile `runGuardedMutation` guest contract korunur; `_PostCard` → `JobSeekPostCard` (test için 1-karakter görünürlük); `app_strings.dart` import eklendi. Test: `test/dealer_job_seek_write_error_test.dart`. Commit/push bekliyor. |
| P1.25 | Job seek post delete silent | P1 | IN_PROGRESS | `job_seek_posts_screen.dart:180-207` | Patch hazır: `_delete` action içinde try/catch + `AppStrings.jobSeekPostDeleteError`; confirm dialog davranışı korunur; `on GuestActionRequiredException` rethrow. Ortak `JobSeekPostCard` görünürlük değişimi P1.24 ile. Test: `test/dealer_job_seek_write_error_test.dart`. Commit/push bekliyor. |

---

## P2 / Feature Backlog / Infra Prep

### Infra / Test / DRY
| ID | Title |
|---|---|
| P2.1 | UUID validator helper (`lib/core/utils/uuid_helper.dart`) — Dealer/Recipe/Worker drift |
| P2.2 | Repository interface contract tests — Local ↔ Supabase parity (10 modül) |
| P2.3 | Shared `FakeRepositoryBase<T>` test helper |
| P2.4 | JobMessaging provider explicit guest branch (`'local_self'` fallback yerine) |
| P2.5 | `package_info` app-level FutureProvider cache |
| P2.6 | Feature module skeleton standardı + test template |
| P2.7 | Fragile-text test assertion cleanup (`AppStrings.foo` referansı) |
| P2.12 | GitHub Actions CI workflow |
| P2.13 | `is_group_member` SECURITY DEFINER execute revoke + comment |
| P2.14 | `rls_auto_enable` advisor noise (Supabase's own helper) |

### Ürün / Compliance
| ID | Title |
|---|---|
| P2.8 | Settings Phase 2 — destek e-posta/URL + hesap silme web mirror karar |

### Genişletme (yeni feature)
| ID | Title |
|---|---|
| P2.9 | Apple Sign-In tam aktivasyon (Apple Developer + Service ID + .p8 + Xcode + macOS smoke) |
| P2.10 | Storage buckets / media (`avatars`, `post-media`, `recipe-media`) |
| P2.11 | Push notifications (FCM/APNs) |

### V1 surface'inde yok ama repo katmanı hazır (NOT_IMPLEMENTED_IN_V1)
| ID | Title |
|---|---|
| P2.15 | Dealer edit UI surface (`AddDealerScreen` only-create; `dealer_detail_screen` edit button yok) |
| P2.16 | Job offer delete UI surface (`deleteOffer` repo'da var, UI caller yok) |
| P2.17 | Market listing delete UI surface (`deleteListing` repo'da var, UI caller yok) |

---

## Unknown / Manual Verification

| ID | Title | Nasıl doğrulanır |
|---|---|---|
| U-2 | iOS bundle ID | macOS'ta `xcodebuild -showBuildSettings` |
| U-3 | Keystore üretildi + son AAB build başarılı | Geliştiri tarafı; `key.properties` lokal-only |
| U-4 | Play Store listing/account state | Google Play Console manuel |
| U-5 | Real device 17-item smoke (Settings + Google completion + email signup + delete account) | emulator-5554'te APK kurulu; 17 maddelik checklist |
| U-6 | Account deletion live E2E | Test hesabı + canlı tetikleme + MCP `execute_sql` doğrulama |
| U-7 | Email signup live E2E (`email_identities=0` baseline) | Gerçek e-posta + confirmation link |

---

## Current Repair Order

> **Not:** P1.23 2026-05-17'de `73034df` + `c92d094` ile FIXED oldu; sıradan çıkarıldı.
> **Not:** P1.18-P1.21 2026-05-17'de `55ea49b` ile FIXED oldu; sıradan çıkarıldı.

Risk × payback sırası — her satır küçük testli atomic commit:

| # | İş | Risk | Boyut |
|---|---|---|---|
| 1 | **P1.22 + P1.24 + P1.25 batch** — Dealer price update + job seek toggle/delete | 🟡 3 × P1 | ~50 satır + 3 test (template aynı) |
| 2 | **P1.6** — Recipe save missing catch | P1 | ~15 satır + 1 test |
| 3 | **P1.7** — 4 dealer form try/catch (delivery/payment/return/adjustment) | P1 × 4 | ~60 satır + 4 test |
| 4 | **P1.2** — SplashScreen Timer dispose | P1 | ~5 satır |
| 5 | **P1.3** — performDeleteAccount cleanup ordering | P1 | ~10 satır |
| 6 | **P1.4** — Guest+session mutual exclusion guard | P1 | ~10 satır + 1 test |
| 7 | **P1.5** — CreateProfileScreen hydrate-then-submit lock | P1 | ~15 satır + 1 test |
| 8 | **P1.14** — `.gitignore` patternları (`MCP_*.txt`, root `*.png`, audit `*.md`) | P1 | ~10 satır gitignore |
| 9 | **Store/release P0-A/B/C** — Hosted Privacy + Account deletion URL + store assets (ürün kararı) | P0 (compliance) | — |

Phase C (sonra): **P1.10** (translate_data_error helper) + **P1.9** (deep link redirect) + **P1.11** (6 ek autoDispose) + **P1.13** (Crashlytics).
Phase D (genişletme): P2 infra/feature sırası.

---

## Update Protocol

Bu register'ı **her risk patch'inden sonra** şu şekilde güncelle:
1. İlgili satırda `Status` → `FIXED` (patch atılınca) veya `VERIFIED` (smoke geçince).
2. `Commit` sütununa kısa hash.
3. `Test` sütununa yeni test dosya adı + suite sayısı.
4. `Smoke` sütununa manuel smoke notu (varsa).
5. Yeni risk keşfedilirse sıradaki P-ID ile aşağı ekle (id'leri yeniden kullanma).
6. UNKNOWN kapanırsa Closed/Open kategorisine taşı.
