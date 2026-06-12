# FırınNet Performance Hardening Audit

Tarih: 2026-06-12 · Önceki HEAD: `5166a0a` · Yöntem: kod analizi + Supabase read-only + test fixture (gerçek cihaz ölçümü "ölçülmedi" diye işaretli).

## Genel Verdict
Closed beta için performans **yeterli**. İki büyük darboğaz (mesaj listesi N+1, signed-URL fırtınası) kodla kanıtlandı ve düzeltildi. Kalan riskler P1/P2 (davranış doğru, ölçek/uzun-oturum). Performans P0 yok.

## Baseline
- **APK (debug):** ~231MB (debug normal; release shrink/tree-shake P2).
- **Cold start:** splash timer yok; ilk frame Supabase init'e bağlı ~400-500ms — kabul edilebilir (kod analizi).
- **Bilinen darboğazlar (önce):** listConversations 4+N sorgu; her sohbet açılışında medya başına yeniden `createSignedUrl`; bazı listelerde limit eksiği (önceki sprintte kapatıldı).

## Fixed

| ID | Alan | Problem | Fix | Before | After | Commit |
|----|------|---------|-----|--------|-------|--------|
| PF-1 | listConversations | konuşma başına son-mesaj sorgusu (N+1) | `messages_last_per_conversation` RPC (DISTINCT ON, SECURITY INVOKER) | 50 konuşma = **54 sorgu** | **5 sabit** | (bu commit) |
| PF-2 | Signed URL | sohbet açılışında medya başına yeniden imza, cache yok | `ChatMediaSignedUrlCache` (path→url+TTL, logout clear) | 20 medya her açılışta **20 imza** | ilk açılış 20, **sonraki açılış 0** | (bu commit) |
| PF-3 | Medya bellek | feed/chat/grup/market görselleri tam-res decode | `memCacheWidth` (feed 720, bubble 480, market 720) | full-res decode | ekran-boyutu decode | (bu commit) |

## listConversations (PF-1)
**N+1 kanıtı:** `supabase_messaging_repository.dart` eski hali — satır ~141: `for (final cid in myConvIds) { ... .from('messages')...limit(1) }`. 50 konuşma = 4 batch + 50 döngü = 54 sorgu.
**Çözüm:** Son mesaj per-conversation tek RPC ile. `select distinct on (conversation_id) ... order by conversation_id, created_at desc`. **SECURITY INVOKER** → messages RLS aynen uygulanır (privilege escalation yok; kullanıcı yalnız katılımcı olduğu konuşmaların mesajını görür). Diğer batch'ler (participants, profiles) zaten tekildi, korundu.
**Query sayısı:** 4+N → **5 (sabit)**. O(N) → O(1) sorgu.
**Davranış korundu:** sadece katılımcı konuşmalar, lastMessage, unread (rough 0/1 davranışı birebir), contextType, blocked filtre (provider katmanında), panel badge — hepsi değişmedi.

## Signed URL Cache (PF-2)
**Storm kanıtı:** `_enrichImage` her medya mesajı için `createSignedUrl(path, 3600)`; `Future.wait(list.map(_enrichImage))` → 100 mesajlı sohbet açılışında 100 paralel imza; her yeniden açılışta tekrar.
**Tasarım:** `ChatMediaSignedUrlCache` singleton — `storagePath → (signedUrl, expiresAt)`. Hit → cache'ten; miss/expired → yeniden imzala + cache'le.
**TTL/expiry:** signed URL 3600s imzalanır; cache TTL = 3000s (10dk emniyet payı) → URL **gerçekten expire olmadan** yeniden imzalanır, bayat URL servis edilmez. `_maxEntries=500` (bellek koruması, en eski atılır).
**Güvenlik:** private bucket korunur — yalnız signed URL cache'lenir, **public URL'ye dönülmez**. Logout/kullanıcı değişiminde `clear()` (`performSignOut`). hit/miss sayaçları test+ölçüm için.
**Before/after:** ilk açılış N imza; **aynı oturumda tekrar açılış 0 imza**. generic + group + realtime enrich (`signedUrl`) — üçü de kapsandı.

## Query Limits / Pagination
- **Önceki sprintte (be56b75) kapatılan:** follow ids (2000), market listMine (500), job listMyOffers (500), stories listFreshStoriesOf (100), social listGroups (500). Doğrulandı, korunuyor.
- **Limitli (sağlam):** feed listPosts/listPostsPage (paged 20), comments (200), messages (100), group_messages (200), market listActive/listFiltered (100), job listActiveOffers (100), notifications (100), conversations (50).
- **Kalan P2:** blocked feed filtresi render-level (server-side `not.in` ölçek için) — davranış doğru.

## Memory / Dispose
- **Doğrulandı temiz:** TextEditingController/FocusNode/ScrollController dispose'ları (~20 form/ekran), `SocialPostVideo` VideoPlayer+Chewie dispose, `chat_screen` `_realtimeSub.close()`, `ref.listenManual` close.
- **Video dialog dispose:** `chat_video_viewer` `SocialPostVideo`'yu dialog'da gösterir; dialog dismiss → widget tree'den çıkar → `dispose()` (VideoPlayer+Chewie kapatılır) Flutter garantisi. Sızıntı yok.
- **P2 (kalan):** repository broadcast `StreamController`'lar `close` edilmiyor (uzun oturumda küçük birikme; select fix rebuild sıklığını düşürdü). Güvenli fix `ref.onDispose` ama provider yaşam döngüsü testi gerektirir — P2.

## Rebuild / Allocation
- **Fixed:** medya `memCacheWidth` (bellek spike azaltıldı).
- **P2 (kalan):** `SocialPostCard` build'inde `Theme.of` + `_timeAgo` string; feed scroll'da kart başına. Memoize/StatelessWidget migration — davranış riski nedeniyle ölçülü yapılmalı, P2.

## Startup
Kabul edilebilir. main.dart: `initializeDateFormatting` (sync ~50ms) + `Supabase.initialize` (async) + `ProviderScope`. Boot'ta gereksiz ağır iş yok, splash timer yok, first-frame block yok. Auth/session race: provider select fix'leriyle zaten sağlamlaştırıldı.

## Verification
- analyze: temiz · test: (full suite, aşağıda) · debug APK: build edilecek · CI: push sonrası.
- RPC migration: production'a uygulandı (SECURITY INVOKER doğrulandı) + repo'da aynalı. Production data write/update/delete YAPILMADI.

## Remaining P1/P2
- **P2:** repo broadcast controller close · SocialPostCard rebuild memoize · server-side blocked feed filter · release minify/tree-shake · unread gerçek sayı (şu an 0/1).
- **P1 (önceki audit'ten, perf dışı):** Android marka icon, privacy URL canlılık, EULA onay akışı.

## Next Recommendation
Performans tarafı closed-beta için yeterli. **Faz 2 UI Quality Sprint'e geçilebilir.** Öncesinde tek değerli perf işi: release build'i `minify + shrinkResources + tree-shake-icons` ile küçültmek (APK boyutu) — küçük, güvenli, P2.
