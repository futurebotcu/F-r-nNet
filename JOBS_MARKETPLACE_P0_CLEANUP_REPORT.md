# FırınNet — Jobs/Marketplace P0 Cleanup Report

**Tarih:** 2026-05-16
**Branch:** `main`
**PR scope:** V1 mağaza öncesi mock görünürlüğünü kaldır; gerçek backend'i bağla.

---

## Executive Summary

- ✅ **Marketplace** bottom nav'dan kaldırıldı; ekran tamamen mock'tan arındırıldı, dürüst coming-soon ekranı kaldı.
- ✅ **Jobs** gerçek `job_seek_posts` Supabase tablosuna bağlandı (`activeJobSeekPostsProvider`); hardcoded 7 mock ilan silindi; "Usta Arıyor" segmenti V2 placeholder.
- ✅ Mevcut RLS (`is_active = true OR owner_id = auth.uid()`) ve V1.2 worker repository altyapısı korundu.
- ✅ Bottom nav 5 tab → 4 tab (Feed / Gruplar / İlanlar / Panel); index mapping otomatik düzeldi.
- ✅ Guest read açık; "+" butonu `AuthRequiredGuard.canWriteWithRef` üzerinden geçer, guest için AuthRequiredSheet açar.
- ✅ `flutter analyze` → No issues · `flutter test` → **197/197 passed** (184 mevcut + 13 yeni P0 cleanup testi).
- ✅ Yeni backend yazılmadı; mevcut Supabase + worker stack kullanıldı. Migration yok.

---

## Marketplace decision

**Karar:** Bottom nav'dan kaldır + `MarketplaceScreen` artık coming-soon ekranı.

**Gerekçe:**
- Backend yok (`market_products` veya benzeri tablo yok).
- Ekran tamamen hardcoded'di: 1 featured + 6 ürün + 6 filtre çipi + sahte satıcılar (Konya Değirmen, Egem Ekipman, Mehmet Usta…) + sahte fiyatlar (₺ 54.000, ₺ 850.000…).
- Mağazada bu içerik kullanıcıya yanıltıcı.

**Davranış:**
- `AppShell._tabs`: Market satırı silindi → 4 tab kaldı.
- `/market` route'u deeplink uyumu için **korundu** (ShellRoute içinde, AppShell wrap'i devam eder).
- `MarketplaceScreen` artık tek bir coming-soon kartı gösterir:
  - Title: "Market yakında açılır"
  - Body: doğrulanmış satıcı + mesajlaşma + V2 açıklaması
  - Ticari rol için hint: Fırın Paneli / Bayi Paneli yönlendirmesi
- Hardcoded `_filters`, `_featured`, `_items` tamamen silindi.
- `MarketProductCard` widget'ı kullanılmaz oldu (dosya kaldırılmadı — başka yerde referans olabilir).

**Toptancı "Ürün/Hizmet İlanı Ver" kartı:** Role panel'de coming-soon olarak kalır — Market ekranıyla bağı yok.

---

## Jobs decision

**Karar:** Tab kalır. JobsScreen gerçek `job_seek_posts` Supabase verisine bağlanır. "Usta Arıyor" V2 placeholder.

**Gerekçe:**
- `job_seek_posts` tablosu V1.2'de mevcut (`20260513210000_firinnet_worker_and_jobseek.sql`).
- RLS: `for select to authenticated using (true)` → authenticated user tüm aktif ilanları görebilir. Mevcut.
- `SupabaseWorkerRepository` mevcut, sadece `listMyJobSeekPosts()` vardı; global aktif liste metodu eksikti.
- Bireysel "iş arıyor" ilanlarının yayın altyapısı zaten kurulu — bağlamak yeterli.
- "İş Veriyor" (fırınların usta araması) için ayrı tablo yok → V2.

**Yeni / değişen API:**
- `WorkerRepository.listActiveJobSeekPosts({int limit = 100})` — abstract metod
- `SupabaseWorkerRepository.listActiveJobSeekPosts`: `select * where is_active=true order by created_at desc limit 100`
- `LocalWorkerRepository.listActiveJobSeekPosts`: in-memory filter (Supabase off + fallback için)
- `GuardedWorkerRepository.listActiveJobSeekPosts`: read pass-through
- `activeJobSeekPostsProvider` FutureProvider (worker_providers.dart)

**JobsScreen davranışı:**
- `ConsumerStatefulWidget` (eski `StatefulWidget`'tan dönüştü).
- "Usta Arıyor" segmenti: `_HiringComingSoon` placeholder kart.
- "İş Arıyor" segmenti: `activeJobSeekPostsProvider` watch + Loading / Error / Empty / Data state'leri.
  - Loading: `CircularProgressIndicator`
  - Error: `_JobsMessage(cloud_off, jobsErrorGeneric)`
  - Empty (guest): `jobsLookingEmptyGuest` — "Üye olunca kendin de ilan verebilirsin"
  - Empty (auth): `jobsLookingEmpty` — "İlk ilanı sen ver veya daha sonra bak"
  - Data: `JobOpportunityCard` listesi (`_JobSeekCard` wrapper alanları map eder)
- "+" butonu: `AuthRequiredGuard.canWriteWithRef` → izin varsa `/worker/job-seek/new`'e push; yoksa `showAuthRequiredSheet`.
- Hardcoded `_bakeriesHiring` (4 mock fırın) ve `_bakersLooking` (3 mock usta) tamamen silindi.

**Alan eşleme** (`_JobSeekCard`):
| `JobOpportunityCard` slot | `JobSeekPost` kaynak |
|---|---|
| `position` | `post.title` |
| `business` | `post.professionBadge` veya `'FırınNet üyesi'` |
| `city` | `post.city` veya `'Şehir belirtilmemiş'` |
| `salary` | `post.salaryExpectation` → `'Beklenti ₺ X'`; yoksa `'Ücret belirtilmemiş'` |
| `experience` | `post.experienceYears` → `'X yıl'` / `'Deneyimsiz olabilir'` |
| `badge` | sabit `'Aktif'` (filter `is_active = true`) |
| `shift` | `null` (V1'de model alanı yok) |

---

## Files changed

| Dosya | Tür | Açıklama |
|---|---|---|
| `lib/core/constants/app_strings.dart` | M | 10 yeni Türkçe copy: `jobsLookingEmpty*`, `jobsHiringComingSoonTitle/Body`, `jobsErrorGeneric`, `jobsCard*`, `marketComingSoon*` |
| `lib/features/worker/repositories/worker_repository.dart` | M | `listActiveJobSeekPosts` abstract metodu |
| `lib/features/worker/repositories/local_worker_repository.dart` | M | Local impl (filter + limit) |
| `lib/features/worker/repositories/supabase_worker_repository.dart` | M | Supabase impl (`eq is_active = true`) |
| `lib/features/worker/repositories/guarded_worker_repository.dart` | M | Read pass-through |
| `lib/features/worker/providers/worker_providers.dart` | M | `activeJobSeekPostsProvider` FutureProvider |
| `lib/features/jobs/screens/jobs_screen.dart` | M | Komple rewrite — ConsumerStatefulWidget + provider + 3 state widget |
| `lib/features/marketplace/screens/marketplace_screen.dart` | M | Komple rewrite — coming-soon ekranı |
| `lib/features/dashboard/screens/app_shell.dart` | M | `_tabs`'ten Market satırı silindi |
| `test/jobs_marketplace_p0_test.dart` | A | 13 yeni test (source-string assertion + LocalWorkerRepository.listActiveJobSeekPosts unit) |
| `JOBS_MARKETPLACE_P0_CLEANUP_REPORT.md` | A | Bu rapor |

Migration veya Supabase schema değişikliği YOK.

---

## Routes / nav changed

| Değişiklik | Etki |
|---|---|
| Bottom nav 5 → 4 tab | Feed=0, Gruplar=1, İlanlar=2, Panel=3 (Market kalktı). `_indexFor` doğru çalışır, default 0. |
| `/market` route | ShellRoute içinde KORUNDU; deeplink uyumu. Ekran coming-soon. |
| `/jobs` route | Değişmedi; ekran içeriği provider'a bağlı. |
| `/worker/job-seek/new` | Değişmedi; JobsScreen "+" butonu buraya push'lar. |
| Diğer route'lar | Etkilenmedi. |

---

## Supabase impact

| Madde | Durum |
|---|---|
| Yeni migration | YOK |
| Yeni tablo | YOK |
| Yeni RLS policy | YOK |
| Yeni grant | YOK |
| `job_seek_posts` mevcut RLS | Korundu (`is_active=true OR owner_id=auth.uid()` authenticated select) |
| `worker_profiles` / `worker_experiences` | Etkilenmedi |

---

## Guest / auth behavior

- **Guest browse:** Feed/Gruplar/İlanlar/Panel hepsi açılır.
  - JobsScreen "İş Arıyor" → eğer Supabase enabled + user yoksa repository LocalWorkerRepository döner → boş liste → `jobsLookingEmptyGuest` empty state.
  - Eğer ileride aktif local seed eklenirse görünür; şu an seed yok.
- **Guest "+" butonu:** `AuthRequiredGuard.canWriteWithRef` → false → `showAuthRequiredSheet`.
- **Authenticated:** SupabaseWorkerRepository → `eq is_active = true` → public sektör listesi.
- **Authenticated "+" butonu:** Direkt `/worker/job-seek/new` push.

Defense-in-depth: Repository-level guard hâlâ var (`GuardedWorkerRepository.upsertJobSeekPost`); UI guard atlanırsa repo yine `GuestActionRequiredException` atar.

---

## Tests

Yeni dosya `test/jobs_marketplace_p0_test.dart` — 13 test:

1. **Marketplace mock cleanup (3 test):**
   - "Spiral mikser" / "Konya Değirmen" / "₺ 850.000" / "Devren Fırın" gibi unique hardcoded string'ler dosyada YOK
   - `MarketProductCard` artık render edilmiyor
   - `marketComingSoonTitle/Body` kullanılıyor

2. **Jobs mock cleanup (4 test):**
   - `_bakeriesHiring` / `_bakersLooking` listeleri YOK
   - "Konak Fırını" / "Selin Pastane" / "Ekmek Sepeti" / "Antep Pide Evi" YOK
   - "Hasan Kara" / "Selin Ateş" / "Burak D." YOK
   - `activeJobSeekPostsProvider` + `ConsumerStatefulWidget` referansı VAR
   - `jobsHiringComingSoonTitle` VAR

3. **AppShell bottom nav (2 test):**
   - `AppRoutes.market` referansı `_tabs` listesinde YOK
   - 4 tab korundu: Feed / Gruplar / İlanlar / Panel

4. **LocalWorkerRepository.listActiveJobSeekPosts (3 test):**
   - `is_active=true` filter doğru
   - `limit` parametresine saygı duyar
   - Boş listede empty döner

---

## analyze / test result

```
flutter pub get   → OK
flutter analyze   → No issues found! (0.8s)
flutter test      → 197 / 197 passed
```

Mock/hardcoded grep son durum:
- `lib/features/jobs/`: yalnız 2 eşleşme, ikisi de açıklayıcı yorum / `JobOpportunityCard` widget class adı
- `lib/features/marketplace/`: yalnız doc yorumu (geçmiş davranışı anlatıyor)
- `lib/features/dashboard/`: yalnız doc yorumu

Secret tarama (`debugPrint|print(|service_role|SUPABASE_SERVICE`): `lib/` altında No files found ✅

---

## Remaining limitations

| ID | Konu | Çözüm |
|---|---|---|
| V2-M1 | Marketplace backend (`market_products` tablosu, RLS, repository) | Ayrı PR |
| V2-J1 | "İş Veriyor" — fırınların usta araması için ayrı tablo (`job_post_offers` benzeri) | Ayrı PR |
| V2-J2 | Job seek post filter (şehir/meslek) UI'da yok | UI iyileştirme PR'ı |
| V2-J3 | Realtime — yeni ilan eklenince anlık güncelleme | Supabase Realtime |
| V2-J4 | "Başvur" CTA: şu an `onApply` callback boş — mesajlaşma backend'i gerek | Mesajlaşma PR'ı |
| P3 | LocalWorkerRepository seed yok → guest İş Arıyor tabı her zaman boş görünür | Seed eklenebilir (P3) |

`MarketProductCard` widget'ı (`lib/core/widgets/premium/market_product_card.dart`) artık kullanılmıyor ama dosya silinmedi — `_router_test` veya başka yerde referans olma ihtimaline karşı duruyor. Cleanup ayrı PR ile yapılabilir.

---

## Store readiness impact

| Madde | Önce | Sonra |
|---|---|---|
| Bottom nav'da gerçek pazar yeri vaadeden Market tab | ❌ Var (5 tab) | ✅ Yok (4 tab) |
| Marketplace ekranında sahte ürünler/fiyatlar/satıcılar | ❌ 7 sahte kart | ✅ Coming-soon ekran |
| Jobs ekranında sahte fırın ilanları | ❌ 4 sahte fırın | ✅ Coming-soon (V2 modülü) |
| Jobs ekranında sahte iş arayan ustalar | ❌ 3 sahte usta | ✅ Gerçek `job_seek_posts` (guest empty) |
| Mağaza reviewer'ı için yanıltıcı içerik | ❌ Çoklu | ✅ Yok |

**Sonuç:** Store'a çıkacak uygulamada sahte ilan / sahte ürün / hardcoded kullanıcı listesi **GÖRÜNMEZ**. Mağaza review'da "asıl uygulama placeholder içeriklerle dolu" yorumu riski kapatıldı.

---

## Açık P0'lar (bu PR scope dışı)

- **P0-3** Hesap silme akışı — ayrı PR
- **P0-4** Android release signing config — ayrı PR
- **P0-5** Privacy/Terms taslak banner — legal onay sonrası ayrı PR
- **Manuel açık iş:** UI smoke (env runner ile)
