# FırınNet UGC Safety Audit

Tarih: 2026-06-11 · Sprint: UGC Safety V1 · Commit: `feat(safety): add report and block controls for user content`

## Genel Verdict

**UGC Safety V1 TAMAM.** Şikayet (report) + kullanıcı engelleme (block) altyapısı tüm ana UGC yüzeylerinde canlı: feed postu, yorum, grup mesajı, market ilanı, iş ilanı, profil. Moderasyon kuyruğu veri modeli production'da (`content_reports`, status=pending); içerik otomatik silinmiyor. Apple Guideline 1.2'nin "report + block + moderation mekanizması" P0 gereksinimi karşılandı; admin review UI P2.

## Reportable Content Categories

8 kategori, DB CHECK + Dart enum (`ReportReason`) birebir:

| persistKey | Etiket | Kapsam |
|---|---|---|
| spam | Spam / reklam | tekrar eden içerik, link spam, sahte kampanya, bot |
| harassment | Hakaret / taciz / tehdit | küfürlü saldırı, kişisel hakaret, ısrarlı rahatsız etme, hedef gösterme |
| hate | Nefret / ayrımcılık | ırk/din/milliyet/cinsiyet/yönelim/engellilik temelli |
| scam | Dolandırıcılık / sahte ilan | sahte ürün, kapora tuzağı, yanıltıcı fiyat, sahte işletme |
| inappropriate_media | Uygunsuz medya | cinsel içerik, şiddet/gore, sektör dışı medya |
| illegal_or_dangerous | Yasaklı / tehlikeli ürün | silah/uyuşturucu/kaçak, gıda güvenliği tehlikesi |
| privacy | Kişisel bilgi ihlali | izinsiz telefon/adres/kimlik/görsel |
| other | Diğer | + opsiyonel açıklama alanı |

## Blocked Actions in Feed and Comments

- **Guest:** post/yorum/medya/grup mesajı/ilan oluşturamaz (mevcut guard korunur); **şikayet ve engelleme de auth gerektirir** (V1 kararı — anonim report kötüye kullanım riski nedeniyle kapsam dışı). Guest tüm bu aksiyonlarda AuthRequiredSheet görür.
- **Kendi içeriği:** şikayet/engel menüsü kendi içeriğinde hiç gösterilmez (`isOwner` kontrolü); repo katmanı da `SelfTargetException` ile reddeder; DB'de `check (blocker_id <> blocked_user_id)`.
- **Duplicate:** aynı hedefe ikinci şikayet `unique(reporter_id, target_type, target_id)` ile DB'de engelli → kullanıcıya "Bu içeriği zaten şikayet ettin." banner'ı (hata değil). Duplicate block → `alreadyBlocked` + bilgi banner'ı.
- **Silinmiş içerik:** soft-delete edilen içerik listelerden zaten düşer → şikayet menüsüne erişilemez.

## Report Flow

Üç nokta / uzun basma → "Şikayet et" → `showReportSheet` (premium bottom sheet: 8 kategori radio + opsiyonel açıklama ≤500 + Gönder) → `content_reports` INSERT (status=pending) → "Şikayetin alındı. Ekibimiz inceleyecek." İçerik SİLİNMEZ. Hata → danger banner, sheet açık kalır. Entity tipleri: feed_post, comment, group_message, market_listing, job_listing, profile. **direct_message P2** (DM gizlilik tasarımı ayrı; gönderen profile üzerinden şikayet edilebilir/engellenebilir).

## Block User Flow

"Kullanıcıyı engelle" → confirm dialog ("Bu kişinin içeriklerini daha az görürsün ve seninle etkileşimi sınırlanır.") → `user_blocks` INSERT → success banner. **Unblock V1'de var:** profil menüsünde "Engeli kaldır" (engelliyse toggle). Engel sonrası: feed postları gizlenir, yorum/grup mesajı placeholder olur, profilden mesaj başlatma engellenir ("Engellediğin bir kullanıcıya mesaj başlatamazsın.").

## Feed / Comment / Group Filtering

- **Feed:** render-level client filter (`social_feed_page`, `blockedUserIdsSyncProvider`). Bilinçli trade-off: sayfalama offset'i RAW listeden hesaplanmaya devam eder (duplicate/atlama riski sıfır). **Performans notu:** çok sayıda engellenen kullanıcıda sayfa görünür içeriği kısalabilir; server-side `not.in` filtresi P1.
- **Yorumlar:** `_BlockedCommentPlaceholder` — akış kopmaz, içerik+yazar gizli.
- **Grup mesajları:** `_BlockedMessagePlaceholder` — grup konuşması kopmasın diye placeholder tercih edildi.
- Blocked set `blockedUserIdsProvider` (DB kaynaklı, block/unblock tick'iyle taze; atomik swap — joined-cache P0 dersi uygulanmış).

## RLS / Schema

Migration `20260611013000_ugc_safety_v1.sql` (production'a uygulandı, repo'da aynalı):
- `content_reports`: INSERT yalnız `reporter_id=auth.uid()` + status=pending + review alanları null; SELECT yalnız kendi reportları; **UPDATE/DELETE policy YOK** (kuyruk manipüle edilemez, moderasyon service-role). Index `(status, created_at desc)`.
- `user_blocks`: INSERT/SELECT/DELETE yalnız `blocker_id=auth.uid()`; başkasının block listesi görünmez. Index `(blocker_id)`.
- Her iki tabloda RLS açık; policy'ler yalnız `authenticated` (anon erişim yok). Mevcut tablolara/policy'lere dokunulmadı.
- `group_messages.owner_id` zaten vardı; Dart `GroupMessage.ownerId` artık parse ediyor (schema değişikliği YOK).

## Moderation Queue

`content_reports` status akışı: `pending → reviewed | dismissed | action_taken` (+ reviewed_at, reviewer_id, metadata). Kuyruk DB'de hazır ve indexli; **admin review UI P2** — V1'de inceleme Supabase dashboard/service-role ile yapılır. Kullanıcı kendi reportlarını görebilir (SELECT-own) — "şikayetlerim" ekranı P2.

## P0 Requirements (karşılandı)

- [x] Feed post / yorum / grup mesajı / market / iş ilanı / profil şikayet edilebilir
- [x] Kullanıcı engellenebilir + engeli kaldırılabilir
- [x] Engellenen içerik feed'de gizli, yorum/grupta placeholder
- [x] Mesaj başlatma engeli
- [x] Guest write/report guard
- [x] Self-report/self-block + duplicate engelleri (UI + repo + DB üç katman)
- [x] Moderasyon kuyruğu veri modeli + RLS

## P1 Improvements

- Server-side feed filtresi (`owner_id not.in (blocked)`) — performans
- "Engellediğim kullanıcılar" listesi (Settings) — şu an unblock yalnız profil menüsünde
- Grup mesajı + DM'de engellenen kullanıcıdan gelen YENİ mesaj bildirimlerinin bastırılması
- Report sonrası içeriği lokal gizleme opsiyonu ("şikayet ettin, gizlemek ister misin?")

## P2

- Admin/moderator review UI + rol modeli
- direct_message report entity
- "Şikayetlerim" ekranı
- Otomatik eşik (N report → içerik geçici gizleme)

## Manual Smoke Checklist

- [ ] Feed postu şikayet et → success banner; tekrar → "zaten şikayet ettin"
- [ ] Yorum şikayet et
- [ ] Grup mesajına uzun bas → şikayet et
- [ ] Market ilanı (⋮) şikayet et; iş ilanına uzun bas → şikayet et
- [ ] Profilden kullanıcı engelle → feed'de postları kaybolur, yorumları placeholder olur, grup mesajları placeholder olur
- [ ] Engellenen profile "Mesaj" → engel banner'ı
- [ ] Profil menüsünden engeli kaldır → içerik geri gelir
- [ ] Guest ile şikayet dene → AuthRequiredSheet
- [ ] Kendi postunda menüde şikayet/engel YOK
- [ ] Report/block sonrası app crash yok; text/image/video akışları bozulmadı
