# FırınNet Faz 1 — Derin Bulgu Envanteri (DB-doğrulamalı)

Tarih: 2026-06-12 · Yöntem: kod + Supabase production read-only karşılaştırma. Her madde **doğrulama kanıtı** ile. Bu rapor SORUNLARI listeler; fix kararı ayrı.

---

## A. Bağlamsal Mantıksızlıklar (en kritik kategori)

### A-1 · Moderasyon kuyruğu sahipsiz — `content_reports` write-only [P1, doğrulandı]
DB policy'leri: yalnız `content_reports_insert_own` + `content_reports_select_own`. **Şikayet kuyruğa giriyor ama uygulamadan hiçbir moderatör/admin okuyamıyor** — yalnız raporu atan kendi raporunu görür. Admin rolü/UI yok. Apple Guideline 1.2 "mekanizma var" diye kabul eder, ama fonksiyonel olarak kuyruk işlenmiyor (yalnız Supabase dashboard/service-role ile okunabilir).
**Etki:** kötü içerik raporlanır, kimse görmez → güven sorunu. **Aksiyon:** moderator rolü + admin okuma policy'si veya periyodik service-role inceleme süreci.

### A-2 · ~~Engelleme V1 kapsamı dışı boşluklar~~ → **V1.1'de KAPATILDI** [çözüldü]
**Durum (2026-06-12):** Engelleme artık tam. Eklenenler: DM konuşma listesi + DM mesajları + realtime + bildirimler blocked filtresi (provider/chat katmanı); çift-yön engel `find_or_create_direct_conversation` RPC'sine taşındı (engellenen kullanıcı engelleyene mesaj başlatamaz; migration `20260612040000`). Client RPC hatasını `BlockedConversationException` ile 3 başlatma yolunda dostça gösterir. Aşağıdaki orijinal tespit, kayıt için bırakıldı:


**Düzeltme:** Engelleme bozuk değil — UGC Safety V1 kapsamında tasarlandığı gibi çalışıyor: feed gizleme (`social_feed_page`), yorum placeholder (`comments_page`), grup mesajı placeholder (`_ChatBubble`), engellenenler listesi + unblock, ve profilden **mesaj başlatma engeli** (`profile_page:363`). Aşağıdakiler V1'de HİÇ KAPSAM ALINMADI — bug değil, kapsam boşluğu:
- **Birebir DM (mevcut sohbet):** `chat_screen.dart`'ta blocked filtresi yok → zaten açık bir DM'de engellenenin mesajları görünür. (V1 feed/yorum/grup kapsadı, DM ekranını değil.)
- **Tek yönlü:** block "onu benden gizle"; engellenen kişi blocker'a hâlâ mesaj atabilir (karşı yön engeli yok — bilinçli V1 sadeliği).
- **Realtime grup:** engellenenin yeni mesajı stream'e gelir; bubble widget gizler (görsel doğru) ama veri akar.
- **Bildirimler:** engellenenin like/yorum/takip bildirimi filtrelenmiyor.
**Aksiyon (V2 tamamlama):** block'u repository read path'ine taşı (DM + bildirim seviyesi) + opsiyonel çift-yön engel.

### A-3 · Feed boundary tamamen client-side [P1, bilinen]
`addPost`/`postMessage` server'da hiçbir içerik kontrolü yapmaz. Değiştirilmiş client veya doğrudan REST API her postu geçirir. Composer guard yalnız UX. **Aksiyon:** Edge Function classifier (audit'te P1 olarak işaretli).

### A-4 · Blocked feed filtresi pagination'ı bozuyor [P2, doğrulandı]
`social_feed_page` blocked'ı **render seviyesinde** filtreler; offset/`hasMore` ham listeden hesaplanır. Çok engellenen kullanıcıda sayfa 20'den az görünür, "daha fazla" eşiği şaşar. **Aksiyon:** server-side `owner_id not.in (blocked)`.

### A-5 · Unread sayısı binary (0/1) [P2, doğrulandı]
`listConversations` satır 179: unread `0` veya `1` olarak set ediliyor; gerçek sayı değil. `conversation_unread_count` RPC mevcut ama liste bu değeri kullanmıyor. Badge "5 okunmamış"ı "1" gösterir. **Aksiyon:** RPC'yi listeye bağla (N+1 fix ile birlikte).

---

## B. Yavaşlık / Ölçek Riskleri

### B-1 · `listConversations` N+1 [P1, doğrulandı satır 142-152]
Konuşma başına ayrı "son mesaj" sorgusu. 50 konuşma = 1 (participants) + 1 (conversations) + 1 (other participants) + 1 (profiles) + **50 (son mesaj döngüsü)** = ~54 roundtrip. Mesaj listesi açılışı 4G'de gözle görülür gecikme. **Aksiyon:** tek RPC/view (son mesaj + unread + diğer katılımcı + isim).

### B-2 · Signed-URL fırtınası + cache yokluğu [P1, doğrulandı]
`supabase_messaging_repository:290` ve `supabase_social_group_repository:409` → `Future.wait(list.map(_enrichImage))`. Sohbet açılışında medya mesajı başına paralel `createSignedUrl`. Aynı resim **her açılışta yeniden imzalanıyor** (TTL cache yok). 100 mesajlı sohbet = 100 paralel storage çağrısı. **Aksiyon:** signed URL'i DB'de cache (1h TTL) veya client LRU.

### B-3 · `CachedNetworkImage` memCacheWidth yok [P2]
Feed/market kartlarında full-res decode → bellek spike (20 kart × 4K resim = ~100MB). **Aksiyon:** `memCacheWidth: 480`.

### B-4 · Repository broadcast StreamController'ları close edilmiyor [P2]
~28 repo'da `StreamController.broadcast()` hiç kapatılmıyor. Provider rebuild'lerinde küçük birikme (select fix sıklığı azalttı). **Aksiyon:** `ref.onDispose(() => _changes.close())`.

### B-5 · Provider invalidation zincirleri [P2]
Post sil → 4 provider invalidate (`social_post_card:211`); grup ekranında tek aksiyon 4 provider tetikliyor. **Aksiyon:** granüler tick veya optimistic update.

### B-6 · `SocialPostCard` build maliyeti [P2]
Her build'de `Theme.of` + `_timeAgo` string allocation; feed scroll'da 20 kart × her frame. **Aksiyon:** memoize.

---

## C. Gelecekte Bug Potansiyeli

### C-1 · 7 repository provider obje-watch [FIXED bu sprint]
feed/messaging/market/jobs/worker/bakery/recipe/dealer → `.select((u)=>u?.id)`. Token refresh repo+cache resetini engelledi.

### C-2 · `local-user-me` fallback kalıntısı [P2, doğrulandı `chat_screen:328`]
Token refresh stale-null anında yanlış owner path. Defensive `invalidate` var ama fallback duruyor. **Aksiyon:** fallback'i kaldır, null'da gönderimi guard'la.

### C-3 · Grup oluşturmada isim dedup yok [P2, gerçek veri kanıtı]
Prod'da aynı isimli iki "Konya Fiirncilari" var (aynı owner). **Aksiyon:** owner+isim unique veya UI uyarısı.

### C-4 · `create_profile_screen:390` ham hata gösterimi [P2]
`e.toString().replaceFirst('Exception: ', '')` — `translateAuthError` çoğunu Türkçeleştiriyor ama tüm yollar değil. **Aksiyon:** humanize helper.

---

## D. Supabase Güvenlik (advisor + manuel)

### D-1 · Public bucket listing [P2, advisor WARN]
`avatars`, `feed-media`, `market-media`, `story-media` public + broad SELECT → authenticated kullanıcı **tüm dosyaları enumerate edebilir** (object URL erişimi için gerekmez). Privacy sızıntısı. **Aksiyon:** listing policy'sini daralt (object-key bazlı).

### D-2 · SECURITY DEFINER fn'ler anon/auth execute [P2, advisor WARN]
`rls_auto_enable`, `bump_conversation_updated_at` anon RPC ile çağrılabilir. Zararsız (destructive değil) ama temizlik gerekir → `revoke execute from anon`.

### D-3 · Leaked password protection kapalı [P2, advisor WARN]
HaveIBeenPwned kontrolü kapalı. **Aksiyon:** Supabase dashboard'dan aç (kod değil).

### D-4 · `firinnet_id_counters` RLS açık + policy yok [INFO]
Erişim tamamen kapalı = güvenli (kasıtlı). Advisor INFO; aksiyon gerekmez.

---

## Senkron Durumu (POZİTİF)
- Örneklenen 23 client SELECT kolonu (market/notifications/recipe/group_messages/content_reports) **hepsi DB'de mevcut** — şema drift YOK.
- `messages` insert → `conversations.updated_at` bump trigger'ı **aktif** (sıralama doğru).
- 39/39 tabloda RLS açık; anon write grant'i YOK; chat-media private.
- delete-account Edge Function ACTIVE + verify_jwt.

## Öncelik Sırası (öneri)
1. **A-2 engelleme veri katmanı** (güvenlik+UX, gerçek eksik) · 2. **B-1+A-5 listConversations RPC** (yavaşlık+unread tek seferde) · 3. **B-2 signed-URL cache** (yavaşlık) · 4. **A-1 moderasyon okuma** (store/güven) · 5. D-1 bucket listing.
