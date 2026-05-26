# GUEST_WRITE_OPERATION_MATRIX

**Tarih:** 2026-05-13
**Tür:** Read-only audit matrisi — V1.3.3 merkezi guard mimarisinin tasarım girdisi.
**Kapsam:** Tüm Flutter `Repository` interface'leri + UI'dan tetiklenen mutate çağrıları. Supabase migration/RLS değişikliği yok.

## Karar kategorileri

| Kategori | Anlam |
|---|---|
| **READ_ONLY_ALLOWED** | Salt okuma; guest serbest. |
| **EXTERNAL_SHARE_ALLOWED** | `Share.share` / `Share.shareXFiles` — dış sistem paylaşımı; DB'ye yazmaz; guest serbest. |
| **STATELESS_TOOL_ALLOWED** | UI içinde anlık hesap (örn. RecipeCalculator); herhangi bir kayıt oluşturmaz. |
| **AUTH_REQUIRED_WRITE** | Veritabanına owner_id-bound kayıt veya user-bound state değişikliği; guest engellenmeli. |
| **LEGACY_RISK** | Kullanım dışı UI'dan tetiklenen yazma çağrısı; deeplink ile guest açabilir. |

---

## 1. Feed (`FeedRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `listPosts` | local_feed_repository.dart | read | READ_ONLY_ALLOWED | n/a | mock seed |
| `listInsights` | local_feed_repository.dart | read | READ_ONLY_ALLOWED | n/a | |
| `addPost` (composer) | feed_composer.dart:`_submit` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addPost` (Reçete → Feed) | recipe_detail_screen.dart:`_shareToFeed` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `toggleLike` | feed_screen.dart `onLike` | user-bound | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `toggleSave` | feed_screen.dart `onSave` | user-bound | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |

## 2. Social Groups (`SocialGroupRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `listGroups` / `listPopular` / `listJoined` / `getGroup` / `listMessages` / `isJoined` | repo read | READ_ONLY_ALLOWED | n/a | |
| `createGroup` | group_create_screen.dart:82 | write | AUTH_REQUIRED_WRITE | ❌ **GAP** | Major: guest grup oluşturuyor |
| `joinGroup` (Feed) | feed_screen.dart:346 | user-bound | AUTH_REQUIRED_WRITE | ❌ **GAP** | Canlı bug — kullanıcı yakaladı |
| `joinGroup` (Groups list) | groups_list_screen.dart:269 | user-bound | AUTH_REQUIRED_WRITE | ❌ **GAP** | |
| `joinGroup` (Group detail) | group_detail_screen.dart:421 | user-bound | AUTH_REQUIRED_WRITE | ❌ **GAP** | |
| `leaveGroup` | group_detail_screen.dart:413 | user-bound | AUTH_REQUIRED_WRITE | ❌ **GAP** | |
| `postMessage` | group_detail_screen.dart:664 | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |

## 3. Recipes (`RecipeRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `list` / `listPublicByOwner` / `getById` / `watch` | repo read | READ_ONLY_ALLOWED | n/a | RLS owner-only + public select |
| `save` | recipe_editor_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `delete` | recipe_detail_screen.dart:`_confirmDelete` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| Reçeteyi WhatsApp/sistem paylaş | recipe_detail_screen.dart:`_shareSystem`, recipes_list_screen.dart | external | EXTERNAL_SHARE_ALLOWED | n/a | `Share.share` |
| Reçete public toggle | save'in parçası (metadata) | write | AUTH_REQUIRED_WRITE | save guard'ı kapsar | — |

## 4. Calculator (stateless)

| Aksiyon | Dosya | Kategori | Notlar |
|---|---|---|---|
| `calculate` / `calculateFromQuantities` | RecipeCalculator service | STATELESS_TOOL_ALLOWED | Hiçbir repo write yapmaz |
| Sonucu WhatsApp/sistem paylaş | calculator_screen.dart `_share` | EXTERNAL_SHARE_ALLOWED | `Share.share` |
| "Reçete olarak kaydet" → `/recipes/new` | calculator_screen.dart | navigation | RecipeEditorScreen `_save` guard'ı uygular |

## 5. Bakery (`BakeryRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `listProduction` / `listDeliveries` / `listWastes` / `dailySummary` / `watch` | repo read | READ_ONLY_ALLOWED | n/a | RLS owner-only |
| `addProduction` | production_entry_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addWaste` | waste_entry_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addDelivery` | dealer_delivery_screen.dart:72 (legacy `/panel/dealer`) | write | LEGACY_RISK | ❌ UI guard yok | SupabaseBakeryRepo `StateError` atıyor; UX bozuk |

## 6. Dealer (`DealerRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `listDealers` / `getDealer` / `listPrices` / `currentPriceFor` / `listTransactions` / `listAllTransactions` / `listNotes` / `watch` | repo read | READ_ONLY_ALLOWED | n/a | RLS + indeksli |
| `upsertDealer` (Bayi/Müşteri ekle) | add_dealer_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `setActive` (pasif/aktif toggle) | API açık, UI'da callsite YOK | latent | LEGACY_RISK | ❌ Henüz UI yok; eklenirse guardsız olur | Latent gap |
| `addTransaction` delivery | dealer_delivery_form_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addTransaction` payment | dealer_payment_form_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addTransaction` return | dealer_return_form_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addTransaction` adjustment | dealer_adjustment_form_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addPrice` (price sheet) | dealer_detail_screen.dart:`_PriceSheet._save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addNote` (notes card) | dealer_detail_screen.dart:`_NotesCard._add` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| Dış paylaşım (hesap özeti + PDF) | dealer_share_screen.dart | external | EXTERNAL_SHARE_ALLOWED | n/a | `Share.share` + `Share.shareXFiles` |

## 7. Worker (`WorkerRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `getMyProfile` / `listMyExperiences` / `listMyJobSeekPosts` / `getJobSeekPost` / `watch` | repo read | READ_ONLY_ALLOWED | n/a | RLS + auth read |
| `upsertMyProfile` | worker_profile_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `addExperience` | worker_experiences_screen.dart:`_AddExperienceSheet._save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `deleteExperience` | worker_experiences_screen.dart:`_ExperienceCard._confirmDelete` | write | AUTH_REQUIRED_WRITE | ❌ **GAP** | UI guard yok |
| `upsertJobSeekPost` (yeni/güncelle form) | job_seek_post_form_screen.dart:`_save` | write | AUTH_REQUIRED_WRITE | ✅ UI guard | repo wrap eksik |
| `upsertJobSeekPost` (toggle isActive) | job_seek_posts_screen.dart:`_toggleActive` | user-bound | AUTH_REQUIRED_WRITE | ❌ **GAP** | UI guard yok |
| `deleteJobSeekPost` | job_seek_posts_screen.dart:`_delete` | write | AUTH_REQUIRED_WRITE | ❌ **GAP** | UI guard yok |
| Dış paylaşım (job post share) | job_seek_posts_screen.dart, form `_previewShare` | external | EXTERNAL_SHARE_ALLOWED | n/a | `Share.share` |

## 8. Profile (`ProfileRepository`)

| Aksiyon | Dosya | Metod | Kategori | V1.3.2 guard | Notlar |
|---|---|---|---|---|---|
| `fetchProfile` | splash, profile_provider | read | READ_ONLY_ALLOWED | n/a | RLS owner-only |
| `updateProfile` | profile_provider.dart:`ProfileController.save` (CreateProfileScreen save) | write | AUTH_REQUIRED_WRITE | ✅ UI guard (CreateProfileScreen `_save`) | repo wrap eksik; ileride "Profili Düzenle" UI eklenirse latent gap |

## 9. Reports / Share screens

| Aksiyon | Dosya | Kategori | Notlar |
|---|---|---|---|
| Gün sonu rapor metni → dış paylaşım | report_screen.dart `Share.share` | EXTERNAL_SHARE_ALLOWED | DB write yok |
| Bayi cari özeti → dış paylaşım | dealer_share_screen.dart | EXTERNAL_SHARE_ALLOWED | `Share.share` |
| Bayi PDF → dış paylaşım | dealer_share_screen.dart | EXTERNAL_SHARE_ALLOWED | `Share.shareXFiles` |
| Reçete WhatsApp paylaş | recipes_list_screen.dart, recipe_detail_screen `_shareSystem` | EXTERNAL_SHARE_ALLOWED | `Share.share` |
| İş ilanı WhatsApp paylaş | job_seek_posts_screen.dart card, form `_previewShare` | EXTERNAL_SHARE_ALLOWED | `Share.share` |
| Calculator sonucu paylaş | calculator_screen.dart `_share` | EXTERNAL_SHARE_ALLOWED | `Share.share` |

## 10. Auth (`AuthRepository`)

| Aksiyon | Kategori | Notlar |
|---|---|---|
| `signIn` / `signUp` / `signOut` / `updateEmail` | (auth-flow özel) | Guard'a tabi değil — bu metodlar zaten auth'un kendisi. |

---

## Özet — GAP listesi (V1.3.2 sonrası)

| # | Kayıp guard | Konum | Etki |
|---|---|---|---|
| 1 | `joinGroup` (3 UI noktası) | Feed/Groups list/Group detail | Guest gruba katılabiliyor (canlı bug) |
| 2 | `leaveGroup` | Group detail | Guest üyelikten çıkabilir |
| 3 | `createGroup` | Group create | Guest grup yaratabilir ⚠ Major |
| 4 | `deleteExperience` | Worker experiences | Guest tecrübe silebilir |
| 5 | `upsertJobSeekPost` toggle | Job seek posts | Guest yayını aç/kapa yapabilir |
| 6 | `deleteJobSeekPost` | Job seek posts | Guest ilan silebilir |
| 7 | Legacy `addDelivery` | dealer_delivery_screen | Deeplink riski; `StateError` UX |
| 8 | Latent `setActive` | API açık, UI yok | İleride eklenince guardsız olur |

## Yapısal problem

Tüm guard kontrolü **UI çağrı sitesinde manuel** ekleniyor. Bu pattern:
- Hatalı yere yerleştirme kolay (joinGroup 3 UI noktasında, biri unutulmuş).
- Yeni eklenecek butonlarda kolayca atlanır (`setActive` latent).
- Yalnızca pure `canWrite` matrix test ediliyor — gerçek mutation çağrıları test edilmiyor.

## Mimari karar (V1.3.3'te uygulanacak)

**Repository decorator (Guarded*) pattern**:
- Her write-capable repository için `Guarded<X>Repository` wrapper.
- Read metodları doğrudan inner'a delege.
- Write metodları önce `requireAuth` → guest ise `GuestActionRequiredException` atar.
- Provider'lar inner repo'yu Guarded* ile sarar.
- UI `runGuardedMutation(...)` ile çağırır; exception yakalanırsa `AuthRequiredSheet` açılır.

Bu pattern:
- Yeni write metodu eklenince guard otomatik aktive olur (wrapper'a tanımı eklendiği anda).
- UI hatalı/eksik check yapsa bile repository katmanı engelleme yapar — defense-in-depth.
- Test edilebilir: wrapper'a guest-mode + write call → exception fırlatılması kontrol edilir.
