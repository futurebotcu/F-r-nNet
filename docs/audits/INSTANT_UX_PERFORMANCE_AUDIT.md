# FırınNet Whole-App Instant UX & Runtime Performance Report

Tarih: 2026-06-12 · Önceki HEAD: `a784ef7` · Yöntem: 4 paralel modül denetimi (mutation→invalidation grafiği) + kaynak-sözleşme/davranış testleri + emülatör runtime smoke (Choreographer frame-skip).

## Genel Verdict

Uygulama genelinde **mutation sonrası full-screen spinner flash** kalıbı bulundu ve kapatıldı. Kök sebep, grup modülünde önceden düzeltilen kalıbın diğer modüllerde tekrarıydı: her modülün tek `_notify()` → `xChangesProvider` tick'ini tüm provider'ları izliyor **ve** liste/detay ekranlarının `.when()` çağrılarında `skipLoadingOnReload` yoktu → her kayıt/hareket/ilan işleminde ekran spinner'a düşüyordu. Generic + grup messaging zaten optimistik (önceki sprintler). Closed beta için runtime performans **yeterli**; tıkla-anında-tepki hedefi ana mutation yüzeylerinde karşılandı.

## Reproduced Issues (denetim kanıtı)

| Alan | Akış | Sorun | Kanıt |
|------|------|-------|-------|
| Bayi | hareket/ödeme/düzeltme ekle | tek `dealerChangesProvider` tick'ini 11 provider izliyor; detayın 5 `.when` bloğu skipLoadingOnReload'suz → bakiye/işlem/not aynı anda spinner flash | dealer_providers.dart:45-285; dealer_detail_screen.dart |
| Bayi | finansal form çift-tık | delivery/payment/adjustment/add formlarında `_saving` guard yok → hızlı çift tık = **mükerrer finansal hareket** | *_form_screen.dart save butonları |
| Reçete | reçete kaydet | `recipesListProvider` full re-fetch, liste spinner flash | recipes_list_screen.dart:42 |
| Market | ilan oluştur / kaydet-toggle | `filtered/my/saved` provider'ları full reload, liste spinner flash | marketplace_screen.dart:166 |
| Jobs | ilan oluştur/güncelle | `activeJobOffersProvider` full reload spinner | jobs_screen.dart:126,344 |
| Feed | post oluştur / like / block tick | paged notifier `_FeedLoading()` full spinner flash | social_feed_page.dart:127 |
| Yorum | yorum gönder | yorum listesi spinner flash | comments_page.dart:98 |
| Medya | avatar/story/market galeri | memCacheWidth yok → full-res decode + bellek spike | profile_header/profile_edit_sheet/story_viewer/marketplace_image_gallery |

## Fixed

| ID | Alan | Problem | Root Cause | Fix | Before | After |
|----|------|---------|-----------|-----|--------|-------|
| IX-1 | Bayi detay (5 bölüm) | hareket sonrası bakiye/işlem/not/fiyat/dealer spinner flash | `.when` skipLoadingOnReload yok | 5 `.when`'e `skipLoadingOnReload: true` | her harekette bölümler boşalır | eski veri korunur, akıcı |
| IX-2 | Bayi liste/panel/eod/rapor/aktivite/toptancı | mutation sonrası liste spinner flash | aynı | skipLoadingOnReload (8 ekran) | full spinner | görünür kalır |
| IX-3 | Bayi finansal formlar (4) | çift-tık mükerrer hareket/kayıt | `_saving` guard yok | `_saving` re-entry guard + buton disable + finally reset | mükerrer tx riski | tek gönderim garantili |
| IX-4 | Reçete liste/detay | kaydet sonrası spinner flash | skipLoadingOnReload yok | eklendi (3 ekran: list/detail/panel) | full spinner | akıcı |
| IX-5 | Market liste/detay | ilan/toggle sonrası spinner flash | aynı | eklendi (2 ekran) | full spinner | akıcı |
| IX-6 | Jobs liste (looking+hiring) | ilan sonrası spinner flash | aynı | eklendi (2 `.when`) | full spinner | akıcı |
| IX-7 | Feed | post/like/block tick'inde full feed spinner | paged `.when` skipLoadingOnReload yok | eklendi | feed boşalır | eski liste görünür, yeni post sessiz eklenir |
| IX-8 | Yorum | gönderimde liste spinner flash | aynı | eklendi | spinner flash | eski yorumlar korunur |
| IX-9 | Medya (avatar×2, story, market galeri) | full-res decode + bellek spike | memCacheWidth yok | avatar 2×display, story 1080, galeri 720 | full-res | ekran boyutu decode |

**Toplam:** 16 ekran skipLoadingOnReload, 4 form çift-submit guard, 5 medya yüzeyi memCacheWidth.

## Feed Performance
- Post create / like / block tick'i artık feed'i boşaltmadan tazeliyor (skipLoadingOnReload). Like/save zaten optimistik (`_likedOverride`) — değişmedi. Block render-level `.where` filtresi — storm yok. Scroll: emülatörde gerçek feed'de **8 scroll gesture = 0 frame-skip** (SocialPostCard + feed image memCacheWidth zaten 720).

## Messaging Performance
- Generic chat: optimistik bubble + `_seenMessageIds` dedup + skipLoadingOnReload (önceki sprintlerde). Grup: mesaj tick ayrımı (önceki sprint). Bu sprintte messaging davranışı **değiştirilmedi** (zaten akıcı). Konuşma listesi memCacheWidth bubble 480 — yeterli.

## Bayi / Dealer Performance
- 13 ekran/bölümde skipLoadingOnReload → hareket eklenince bakiye **AnimatedNumber** ile yumuşak güncellenir, bölümler spinner'a düşmez. 4 finansal formda çift-submit guard → mükerrer hareket imkânsız.
- **Hesaplama korundu:** `DealerBalanceService.summarize`/`aggregateRange`/`summarizeRange` ve `allDealersRangeMetricsProvider` mantığına **dokunulmadı**; yalnız UI reload davranışı değişti. Tüm dealer balance/calc testleri yeşil.

## Recipe / Bakery Performance
- recipes_list / recipe_detail / bakery_panel skipLoadingOnReload → kaydet sonrası liste/detay/panel KPI eski içeriği korur. Calculator (heavy-sync recompute) bu sprintte değişmedi — P2 (debounce adayı).

## Market / Jobs Performance
- marketplace_screen + marketplace_detail + jobs_screen (2 liste) skipLoadingOnReload → ilan oluştur/güncelle/toggle sonrası full reload yok. marketplace_image_gallery carousel memCacheWidth 720 eklendi. Liste cursor-pagination reset (toggle'da) P2.

## Provider / Invalidation Report
- **Düzeltilen:** mutation-visible tüm `.when` yüzeyleri artık reload'da eski veriyi tutuyor → görünür spinner flash yok.
- **Bilinçli sınır (P2):** tick **split** (content vs structural) bu sprintte yapılMADI — `_notify()` hâlâ modül başına tek tick (dealer'da 11 provider, recipe/market/jobs benzer). Bu, mutation'da gereksiz query storm'u (görünür değil; skipLoadingOnReload flash'ı gizliyor) bırakıyor. Split, finansal modülde risk taşıdığı + "büyük rewrite yapma" kuralı nedeniyle **P2 önerisi** olarak raporlandı. Grup modülündeki split kalıbı referans.

## Media Performance
- Eklenen memCacheWidth: profile_header avatar (2×size), profile_edit_sheet avatar (2×size), story_viewer (1080), marketplace_image_gallery carousel (720). Zaten doğru: feed/chat/grup/market kart görselleri (480/720), video yalnız viewer'da init + dispose garantili, ChatMediaSignedUrlCache. Runtime: profil açılışında avatar render OK, 0 skip.

## Runtime Smoke (emülatör emulator-5554, ÖLÇÜLDÜ)
Supabase-config debug APK kuruldu, gerçek oturum (trultruva / Usta Fırıncı).
- Cold launch: OK (yalnız normal cold-start frame-skip; debug build).
- **5 bottom-tab navigasyonu (Feed/Gruplar/Market/İlanlar/Panel): frame-skip = 0.**
- Panel açılış: 0 skip. Profil açılış (avatar memCacheWidth canlı): 0 skip, render OK.
- Profil gönderi listesi 7 scroll gesture: **0 skip.**
- Gerçek feed 8 scroll gesture (medya kartları): **0 skip.**
- Tüm oturumda FATAL/exception/RenderFlex/kırmızı ekran/logout: **0.**

**Dürüstlük notu:** Bayi finansal-WRITE akışı (hareket ekle) runtime otomasyonu **bilinçli yapılmadı**: (1) "production data write yapma" kuralı finansal kayıtta daha hassas; (2) Flutter tek-surface render'da adb kör-koordinat tıklaması güvenilmez (Düzenle/Sil menüsünü yanlışlıkla bir kez açtım — gerçek veride yanlışlıkla silme riski). Bu akışın davranışı şununla kapatıldı: skipLoadingOnReload kaynak-sözleşme testi + çift-submit guard testi + mevcut bakiye/agregat hesap testleri (hepsi yeşil) + grup sprintinde aynı kalıbın cihazda kanıtlanmış olması. Storm-flash görünür yüzeyi navigasyon/scroll smoke'ta sıfır jank gösterdi.

## Verification
- analyze: temiz · test: **1435/1435** (25 yeni instant-UX sözleşme/davranış testi) · debug APK: build ✓ (Supabase defines).
- Davranış korundu: feed/yorum/bayi/reçete/market/jobs/medya/messaging davranışı + finansal hesap mantığı değişmedi. Supabase RLS/data **değişmedi** (kapsam yalnız client provider/UI).

## Remaining P1/P2
- **P2 (perf):** modül-başı tick **split** (content vs structural) — dealer/recipe/market/jobs query storm'unu (görünmez) azaltır. Optimistik insert (post/comment/dealer-list local prepend). Recipe calculator debounce. Market cursor-pagination koru. Feed post comment-count dar güncelleme. Group repo 2 controller dispose.
- **P1 (perf dışı, App Store):** onaylı iOS/Android marka icon, macOS signing/IPA/TestFlight.

## Final Recommendation
Mutation sonrası spinner-flash / full-reload görünür problemi kapandı; runtime smoke jank göstermedi. **Faz 2 UI Quality sprintine geçilebilir.** İstenirse ayrı bir teknik-borç sprintinde tick-split + optimistik insert (P2) ele alınabilir.
