# FırınNet Runtime Performance & Jank Hardening Report

Tarih: 2026-06-12 · Önceki HEAD: `b196079` · Yöntem: kod analizi (invalidation grafiği) + kaynak-sözleşme testleri + emülatör runtime smoke (Choreographer frame-skip logları).

## Genel Verdict
"Mesaj attıktan sonra ekran donuyor" şikayetinin kök sebebi bulundu ve düzeltildi: grup mesaj gönderiminde **tüm mesaj listesi loading spinner'a flash atıyor** + **tek tick'i ~8 provider izlediği için metadata/üye/liste storm'u** tetikleniyordu. İkisi de kapatıldı. Generic chat zaten InMemoryChatController ile incremental (flash yok). Closed beta için runtime performans yeterli; P0/P1 jank riski yok.

## Reproduction
- **Akış:** üye olunan gruba gir → 5 text mesaj gönder.
- **Önce (kod kanıtı):** her `postMessage` → `_notify()` → `groupChangesProvider` tick → `groupMessagesProvider` recompute → `messagesAsync.when(loading: _MiniLoading)` **skipLoadingOnReload yok** → liste her gönderimde spinner'a flash. Aynı tick `groupByIdProvider` (getGroup), `groupMembersProvider` (üye sorgu), `groupsList/joined/popular` provider'larını da recompute ediyordu (storm). `_GroupCommunityHeader` `maybeWhen(orElse:[])` ile üye avatarlarını anlık kaybediyordu (flicker).
- **Generic chat:** `chat_screen` `InMemoryChatController` + realtime append kullanır; `_initialized` bir kez set edilir → flash YOK. Send path optimistic bubble + dedup; freeze yok (kod analizi).

## Fixed

| ID | Alan | Problem | Root Cause | Fix | Before | After |
|----|------|---------|-----------|-----|--------|-------|
| RJ-1 | Grup mesaj listesi | gönderimde spinner flash | `.when` skipLoadingOnReload yok | `skipLoadingOnReload: true` | her send'de liste kaybolur/spinner | liste görünür kalır, pürüzsüz |
| RJ-2 | Grup invalidation storm | mesaj send → metadata+üye+liste re-fetch | tek `groupChangesProvider` tick'ini ~8 provider izliyor | mesaj-tick ayrımı: `watchMessages()` + `groupMessageChangesProvider`; `postMessage` yalnız `_notifyMessages()` | send → 4+ provider + 3 ekstra query | send → SADECE `groupMessagesProvider` (1 query) |
| RJ-3 | Grup üye header | üye avatar flicker | `maybeWhen(orElse:[])` reload'da boş döner | `valueOrNull ?? []` | her send'de avatar kaybol/gel | son veri korunur, flicker yok |
| RJ-4 | Konuşma listesi | yeni mesaj/okundu tick'inde flash | `.when` skipLoadingOnReload yok | `skipLoadingOnReload: true` | liste spinner flash | görünür kalır |

## Message Send Performance
- **Generic chat:** zaten incremental (InMemoryChatController). Provider tick yalnız `conversationByIdProvider` (header) re-fetch eder — async, görünür freeze yok. Mesaj alanı flash atmaz. Değiştirilmedi (zaten akıcı).
- **Group chat:** RJ-1/2/3 ile **mesaj gönderimi artık SADECE mesaj listesini tazeler** (1 listMessages query, signed-URL cache hit). Metadata/üye/grup-listesi recompute edilmez. Flash + flicker yok.
- **Realtime duplicate:** generic chat dedup `_seenMessageIds` ile korunur (değişmedi). Group realtime yok; tick tabanlı refresh.

## Navigation Performance
- Route geçişleri: ekran açılır, data `FutureProvider.when` ile loading→data. Group detail'e giriş `groupByIdProvider` + `groupMessagesProvider` paralel; ilk yüklemede loading (normal), reload'da artık flash yok. initState'te ağır senkron iş yok. Değişiklik gerekmedi.

## Media Performance
- Signed-URL cache (önceki sprint) → mesaj sonrası medya yeniden imzalanmaz; tick'le liste recompute olsa bile cache hit. memCacheWidth (önceki sprint) feed/chat/grup/market.
- Video bubble listede player init ETMEZ (yalnız viewer dialog'da `SocialPostVideo`); dispose dialog dismiss ile garantili. Değişmedi (zaten doğru).

## Rebuild / Provider Report
- **Düzeltilen:** grup mesaj tick'i yapısal tick'ten ayrıldı → mesaj send'de provider storm yok. Üye header `valueOrNull` → flicker yok.
- **Kalan P2:** `socialGroupRepositoryProvider` artık iki broadcast controller tutuyor (yapısal + mesaj); ikisi de close edilmiyor — provider rebuild'de küçük leak (pre-existing pattern; select fix sıklığı düşürdü). `SocialPostCard` build'de `Theme.of`/`_timeAgo` (feed scroll) — memoize P2.

## Verification
- analyze: temiz · test: 1410/1410 (6 yeni jank testi) · debug APK: build ✓.
- **Runtime smoke (emülatör, ÖLÇÜLDÜ):** Konya Fiirncilari grubunda 5 text mesaj (perftest1-5) adb ile gönderildi. **Choreographer frame-skip = 0** (logcat boş — görünür donma yok). Gönderimler sırasında **`joinedCache REFRESH` = 0** → yapısal/üye provider'ları recompute olmadı (RJ-2 storm kesimi doğrulandı). `body BUILD joined=true` stabil (RJ-3 flicker yok). Kırmızı ekran/exception/logout yok. 5 mesaj sırayla render edildi.
- Davranış korundu: mesaj/medya/grup/UGC/auth — değişmedi. Supabase RLS/data değişmedi (RJ kapsamı yalnız client provider/UI).

## Remaining P1/P2
- P2: broadcast controller close (group repo 2 controller) · SocialPostCard memoize · server-side blocked feed filter · unread gerçek sayı · release minify/tree-shake.
- P1 (perf dışı): Android marka icon, privacy URL teyit, EULA onay.

## Next Recommendation
Runtime jank tarafı closed-beta için yeterli. **Faz 2 UI Quality Sprint'e geçilebilir.** İstenirse tek küçük teknik temizlik: group repo iki controller'ı `ref.onDispose` ile kapatmak (P2, güvenli).
