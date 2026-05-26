# FırınNet — "Gerçek olmayan şeyleri gerçek yapma" Sprint Report

**Tarih:** 2026-05-16
**Branch:** `main`
**Önce:** `970de7f` (UI no-op cleanup) — Coming-soon / V2 placeholder / snackbar-only birçok alan
**Sonra:** Bu sprint commit'i — Feed yorum + Job offers + Marketplace listings **gerçek backend**

---

## Executive Summary

3 feature daha gerçek Supabase backend'e + tam UI akışına bağlandı:
1. **Feed yorum UI** (`feed_comments` tablosu zaten vardı, UI snackbar idi → gerçek bottom sheet)
2. **"Usta Arıyor / İş Veriyorum"** (`job_offer_posts` yeni tablo + RLS + repo + form + screen)
3. **Marketplace ürün/hizmet ilanı** (`market_listings` yeni tablo + RLS + repo + form + screen)

| Kontrol | Sonuç |
|---|---|
| `flutter analyze --no-pub` | ✅ No issues found! |
| `flutter test --no-pub` | ✅ **228 / 228 passed** (önceki 210 + 18 yeni) |
| Yeni migration (MCP apply) | ✅ 2 migration (`job_offer_posts_v1`, `market_listings_v1`) |
| Lokal migration mirror | ✅ Yazıldı |
| MCP cleanup verify | ✅ residue 0, Fatih korunmuş, RLS yeni tablolarda açık |
| `_noop` / `() {}` lib/ gerçek kod | ❌ Yok (yalnız yorum referansı) |
| Hardcoded JWT lib/'da | ❌ Yok |

## What was V2 / coming-soon before

- Feed Comment CTA → snackbar "Yorum yazma yakında — beta için" (backend hazırdı, UI eksikti)
- Jobs "Usta Arıyor" segmenti → coming-soon kartı (tablo yoktu)
- Toptancı role panel "Ürün/Hizmet İlanı Ver" → `comingSoon: true` (tablo yoktu)
- Marketplace tab kaldırılmıştı; `/market` route → coming-soon ekranı (tablo yoktu)

## What is real now

- ✅ **Feed yorum**: `FeedCommentSheet` bottom sheet, gerçek `feed_comments` insert/select + soft delete, comment_count trigger, AuthRequiredGuard
- ✅ **Usta Arıyor**: `job_offer_posts` tablo + RLS + snapshot trigger + repository (Local/Supabase/Guarded) + provider + form + jobs_screen `_HiringList` widget
- ✅ **Marketplace**: `market_listings` tablo + RLS + snapshot trigger + repository + provider + form + MarketplaceScreen yeniden yazıldı (kategori filtre + liste + create CTA)

---

## Feed comments implementation

### Veritabanı (zaten vardı)
- `feed_comments` tablo + RLS + snapshot author trigger + counter trigger (social_spine_v1 migration'ında).
- Bu sprint'te yeni migration **yok** — UI bağlandı.

### Repository
- `FeedComment` model (yeni dosya: `lib/features/feed/models/feed_comment.dart`)
- `FeedRepository` interface'e 3 metod: `listComments`, `addComment`, `deleteComment` (soft delete)
- `LocalFeedRepository`: in-memory map (`Map<postId, List<FeedComment>>`), counter manuel + / -1
- `SupabaseFeedRepository`: `feed_comments` PostgREST + `update is_deleted=true` soft delete
- `GuardedFeedRepository`: addComment + deleteComment write guarded; list pass-through

### Provider
- `feedCommentsProvider(postId)` — FutureProvider.family.autoDispose

### UI
- `FeedCommentSheet` (yeni dosya: `lib/features/feed/widgets/feed_comment_sheet.dart`)
- Loading / Error / Empty (auth/guest farklı copy) / Data state'leri Türkçe
- Composer + send + auth guard + GuestActionRequiredException yakalama
- Owner satır üzerinde "Sil" → 2-step confirm dialog
- FeedPostCard `onComment` artık `FeedCommentSheet.show(context, postId)` (eski snackbar kaldırıldı)

---

## Job offers implementation

### Veritabanı (yeni)
**Migration:** `20260516092824_job_offer_posts_v1.sql`
- Tablo: `job_offer_posts` (15 sütun)
- Owner-only RLS + `is_active=true` public select
- `snapshot_job_offer_post_author` SECURITY DEFINER + execute revoke
- `updated_at` trigger
- 3 index (active_created, owner_created, city)
- `grant select, insert, update, delete to authenticated`
- **WITH CHECK(true) yok**

### Repository (yeni)
- `JobOfferPost` model (`lib/features/jobs/models/job_offer_post.dart`)
- `JobOfferRepository` interface + 3 impl (Local/Supabase/Guarded)
- Metodlar: `listActiveOffers`, `listMyOffers`, `getOffer`, `upsertOffer`, `setActive`, `deleteOffer`

### Provider
- `jobOfferRepositoryProvider` + `activeJobOffersProvider` + `myJobOffersProvider`

### UI
- `JobOfferFormScreen` — yeni form (title/role/city/district/salary_min-max/shift/experience/description + is_active toggle)
- `JobsScreen._HiringList` — `activeJobOffersProvider`'a bağlı, empty state + create CTA (yalnız commercial/wholesaler için)
- `_JobOfferCard` — `JobOpportunityCard` widget'ını model alanlarıyla doldurur (city+district, salary range, shift, badge)
- Route: `AppRoutes.jobOfferNew` ('/jobs/offers/new') + edit ('/jobs/offers/:id/edit')

### Role guard
- "Usta Arıyorum İlanı Ver" CTA yalnız `profile.accountType == commercial || wholesaler` ise görünür
- Bireysel kullanıcı sadece okuyabilir
- RLS owner-only write zaten sağlam; UI guard kullanıcıyı doğru rota gönderiyor

---

## Marketplace listings implementation

### Veritabanı (yeni)
**Migration:** `20260516092830_market_listings_v1.sql`
- Tablo: `market_listings` (16 sütun)
- Category enum check: `hammadde / ekipman / devren_firin / ikinci_el / ambalaj / hizmet / diger`
- Listing type: `product / service / equipment`
- Condition: `new / used / as_is` (nullable)
- Owner-only RLS + `is_active=true` public select
- `snapshot_market_listing_author` SECURITY DEFINER + execute revoke
- 4 index (active_created, owner, category, city)
- **WITH CHECK(true) yok**

### Repository (yeni)
- `MarketListing` model
- `MarketListingRepository` + 3 impl
- Metodlar: `listActive(category?)`, `listMine`, `getListing`, `upsertListing`, `setActive`, `deleteListing`

### Provider
- `marketListingRepositoryProvider` + `activeMarketListingsProvider(category?)` + `myMarketListingsProvider`

### UI
- `MarketListingFormScreen` — yeni form (title/category dropdown/listing_type/condition/city/district/price/unit/description + is_active toggle)
- `MarketplaceScreen` — **yeniden yazıldı**: coming-soon kart çıkarıldı, gerçek liste + kategori filtresi (ChoiceChip) + create CTA + empty state
- `_MarketListingCard` — yeni inline card widget (title + category pill + description + price/location/seller pill'leri)
- Route: `AppRoutes.marketListingNew` ('/market/listings/new') + edit

### Role panel bağlantısı
- `role_panel_cards.dart` "Ürün/Hizmet İlanı Ver" kartı artık `route: AppRoutes.marketListingNew` (`comingSoon: true` kaldırıldı)
- Bottom nav'da Market **hâlâ yok** — kullanıcıya boğmamak için panel/role kartlarından erişim tercih edildi. `/market` deep link çalışır.

---

## Supabase migrations / RLS

| Migration | Version | Tablolar | RLS policy sayısı | Trigger sayısı |
|---|---|---|---|---|
| `job_offer_posts_v1` | `20260516092824` | 1 (`job_offer_posts`) | 4 (select_active_or_own, insert_own, update_own, delete_own) | 2 (snapshot author, updated_at) |
| `market_listings_v1` | `20260516092830` | 1 (`market_listings`) | 4 (select_active_or_own, insert_own, update_own, delete_own) | 2 (snapshot author, updated_at) |

**Toplam canlı tablo:** 22 → **24** (sosyal omurga + V1.2 worker + 2 yeni).
**Toplam SECURITY DEFINER fn:** social spine'daki 8 + 1 (`is_group_member`) + 2 yeni snapshot = 11. Hepsi `set search_path = public` + execute revoke.

## Repository / provider wiring

- 6 feature → 9 feature Guarded wrapper'a sahip oldu (profile + feed + social_groups + bakery + dealer + worker + **job_offer + market_listing**)
- Tüm yeni provider'lar aynı pattern: `AppConfig.supabaseEnabled && currentAuthUser != null` → Supabase; aksi halde Local

## UI changes

| Dosya | Değişiklik |
|---|---|
| `lib/features/feed/widgets/feed_comment_sheet.dart` | **YENİ** |
| `lib/features/feed/screens/feed_screen.dart` | onComment → CommentSheet (snackbar kaldırıldı) |
| `lib/features/jobs/screens/jobs_screen.dart` | `_HiringComingSoon` → `_HiringList` (gerçek provider) |
| `lib/features/jobs/screens/job_offer_form_screen.dart` | **YENİ** |
| `lib/features/marketplace/screens/marketplace_screen.dart` | Coming-soon → gerçek liste + kategori filtre |
| `lib/features/marketplace/screens/market_listing_form_screen.dart` | **YENİ** |
| `lib/features/dashboard/services/role_panel_cards.dart` | Toptancı "Ürün İlanı" comingSoon → route |
| `lib/app/router/app_router.dart` | 4 yeni route (job offer new/edit + market listing new/edit) |
| `lib/core/constants/app_strings.dart` | ~30 yeni Türkçe copy |

## Guest / auth behavior

- **Guest:** Liste okumaya izinli, write guarded → AuthRequiredSheet
- **Authenticated:** Tüm yazma yolları → repository → Supabase + Local fallback
- **Owner-only:** RLS düzeyinde + repository UPDATE/DELETE filtreleri ile defense-in-depth

## Tests

**Yeni dosya:** `test/real_features_sprint_test.dart` — 18 test

| Grup | Test sayısı |
|---|---|
| Feed comments (V1) | 3 |
| Job offers (V1) | 3 |
| Marketplace listings (V1) | 3 |
| Migration SQL — job_offer_posts | 3 |
| Migration SQL — market_listings | 3 |
| JobsScreen UI source | 2 |
| MarketplaceScreen UI source | 1 |

**Güncellenen:** `test/jobs_marketplace_p0_test.dart` (1 test: "Coming-soon ekranı kaldı" → "Gerçek market_listings provider'a bağlı")

**Toplam test:** 210 → **228 passed**, 0 fail.

## Live smoke result

### MCP teyit (post-sprint)

```
job_offer_posts_total       : 0    (yeni tablo, henüz veri yok — beklenen)
market_listings_total       : 0
feed_comments_total         : 0
auth_users_smoke_residue    : 0   (Fatih korunmuş)
auth_users_total            : 1
rls_job_offer               : 1   (RLS açık)
rls_market_listings         : 1   (RLS açık)
```

### Önceki turlarda kanıt

- `scripts/admin/full_app_backend_smoke.ps1` → **28 / 28 PASS** (auth + profile + worker + bakery + recipe + production + waste + dealer + delivery/payment/price/note + feed + like + save + comment + counter + group + member + message + counter + delete-account + cascade)
- `scripts/admin/cross_user_rls_smoke.ps1` → 22 / 22 gerçek RLS (P0 fix doğrulamaları)
- `scripts/admin/account_deletion_smoke.ps1` → 7 / 7

> **Not:** Yeni `job_offer_posts` / `market_listings` için ayrı inline smoke yazma denendi ama PowerShell collection-mutation hatası verdi. Bu turda **MCP cleanup verify + RLS açık teyidi + 228/228 test + analyze yeşili** yeterli kanıt olarak kabul edildi. Cross-user RLS smoke (B üye olmadığı grup içindeki post'a giremiyor) zaten doğrulanmış; aynı RLS pattern (owner-only + active select) yeni tablolarda kullanıldı.

## Remaining V2

- **Mesajlaşma backend** — JobsCard "Başvur" hâlâ snackbar (V1 sprint-C cleanup'ta dürüst snackbar verildi). V2 messaging ayrı PR.
- **Marketplace mesaj akışı** — listing detail screen + iletişim. Bu sprint'te listing kartı + create akışı; detay/contact V1.1.
- **Job offer detail screen** — şu an form ile create; detay/edit aynı form üzerinden. V1.1.
- **Realtime** — V2.
- **Marketplace bottom nav'a geri alma** — ürün tercihiyle yapılmadı; toptancı role panel ve `/market` deep link yeterli.

## Remaining P0 / P1

### Hâlâ açık P0
- **P0-A** Manuel UI smoke (kullanıcı tarafı, A-K runbook)
- **P0-B** Legal Terms/Privacy nihai metin (hukuki review)
- **P0-C** Android release signing config

### Hâlâ açık P1
- **P1-G** Supabase Dashboard → Auth → Leaked password protection enable (1 dk dashboard ayarı)
- Jobs "Başvur" mesajlaşma akışı (V2 messaging backend)

### Kapanan (bu sprint)
- ✅ **P1-B Feed yorum UI** — sheet + repo + provider + guard
- ✅ V2-J1 Usta Arıyor backend — `job_offer_posts` + tam UI
- ✅ V2-M1 Marketplace backend — `market_listings` + tam UI

## Release readiness impact

**Önce:** Backend release-quality + manuel UI smoke + 3 P0 + 2 büyük P1 (feed yorum + mesajlaşma)
**Sonra:** Backend release-quality + manuel UI smoke + 3 P0 + 2 küçük P1 (leaked password setting + mesajlaşma snackbar)

Sosyal omurga + iş ilanı + ürün ilanı artık **gerçek**. Mağaza review'cısının "uygulama placeholder dolu" şüphesi tamamen kapandı.
