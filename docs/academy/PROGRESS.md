# FırınNet Akademi + Mizah — Uygulama İlerleme Kaydı

> Bu dosya uygulama boyunca güncellenir: tamamlanan işler, varsayımlar,
> test sonuçları ve sıradaki adım. Rapor değil, çalışma defteridir.

## Mevcut durum tablosu (keşif — 2026-09-28, main 6c878c1)

| Bileşen | Durum | Kaynak |
|---|---|---|
| Bot kimlik modeli | ✅ CANLI: `profiles.is_bot` + `academy_bot_profiles` (metadata+RLS; Path B: bot = giriş-kapalı auth.users+profiles satırı, post `owner_id=bot id`) | `20260713090000_academy_bot_profiles_v1.sql` (PR #100 MERGED) |
| Bot seed | ❌ YOK (bilinçli; plan `docs/academy/bot_seed_plan.md`) | prod'da 0 bot satırı |
| PR #102 (feed/profil UI) | AÇIK ve BAYAT (Temmuz; social_post_card/profile_page o günden çok değişti; içine alakasız hesap-silme/docs işleri karışmış) | okuma katmanı deseni yeniden kullanılacak, PR muhtemelen kapatılıp yerine yenisi |
| Feed | `feed_posts` (owner_id→profiles, type CHECK 8 değer, author snapshot trigger) + `feed_media` (`feed-media` bucket) | social_spine_v1 + s3_feed_media |
| Bot post yazımı | YALNIZ service_role (feed_posts_insert_self: owner_id=auth.uid(); service_role RLS bypass) — korunacak sözleşme | social_spine_v1:558 |
| Yorum/DM | feed_comments insert_self; `find_or_create_direct_conversation` çift-yön block'lu, **is_bot kontrolü YOK** (boşluk: bota DM açılabilir) | ugc_safety_v1_1 |
| Bildirim/push | notifications + pg_net→push-dispatch; bot postuna yorum bota tüketilmeyen bildirim yazar (bilinen küçük yan etki) | in_app_notification_events, push_dispatch |
| Zamanlayıcı | pg_cron mevcut (tek job: supplier-launch-reminders); Akademi cron/worker YOK | supplier_launch_campaign_v1:481 |
| İş kuyruğu | YOK (kurulacak) | — |
| LLM istemcisi | YOK (DeepSeek kurulacak; repoda hiçbir LLM çağrısı yok) | grep 0 eşleşme |
| UI bot rozeti/route | YOK (client `is_bot` okumuyor; router'da academy yok) | grep 0 eşleşme |
| Engelleme/şikayet | content_reports target_type feed_post/profile bot içeriğini kapsar; user_blocks çalışır | ugc_safety_v1 |
| AGENTS.md | YOK | — |

## Kilit varsayımlar (teslim raporunda tekrarlanacak)

1. **Kaynak sayısı**: bot başına ~10 eşleştirme, ortak havuz 80–100 ADAY hedefi;
   aktif sayısı erişim testlerine bağlı, doğrulanmamış aday "aktif" sayılmaz.
   Toplam-10 istenirse `academy_max_active_sources` config'i ile sınırlanabilir.
2. **Konu taksonomisi**: canlı `academy_topic_chk` 11 eski anahtar içeriyor ama
   prod'da satır YOK → CHECK, prompt'taki 10 Akademi konusu + `mizah` ile
   ADDITIVE genişletilir (eski anahtarlar geçerli kalır, migration düzenlenmez).
3. **Yayın sıklığı**: config'te; "her bot her gün 2" ZORUNLU DEĞİL
   (günlük toplam hedef 6, bot başı üst sınır 2, mizah 1, kalite eşiği önce).
4. **JS-render/OCR/video-transkript**: v1 kapsam DIŞI (Edge runtime'a
   sıkıştırılmaz); bu erişim yöntemini gerektiren kaynak `paused/degraded`
   olarak dürüstçe işaretlenir.
5. **Görsel**: v1 sırası = izinli kaynak fotoğrafı (yalnız izin kaydı varsa) →
   Pexels (anahtar varsa) → programatik bilgi kartı (satori+resvg) →
   görselsiz metin postu. Görsel üretim API'si (ücretli) v1'de kapalı.
6. **Canlı yayın**: `academy_dry_run=true` + `academy_enabled=false`
   varsayılanıyla kurulur; gerçek feed'e yayın yalnız kullanıcı onayıyla açılır.
7. **DeepSeek**: anahtar `DEEPSEEK_API_KEY` (edge secret). Yoksa üretim hattı
   fail-closed; fixture testleriyle doğrulanır. Model adı resmî dokümandan
   uygulama sırasında doğrulanır.

## Plan (fazlar)

- **Faz 1**: `academy_content_engine_v1` migration — bot tablo genişletme
  (subtopics/style/is_humor/allow_dm), `academy_sources`,
  `academy_bot_sources`, `academy_content_items`, `academy_drafts`,
  `academy_media`, `academy_jobs`(+runs, lease/dedupe), `academy_usage_daily`,
  `academy_engagement_prefs`; config anahtarları `app_runtime_config`'e;
  service-role RPC'ler (claim/complete/publish, idempotent yayın);
  `find_or_create_direct_conversation`'a is_bot+allow_dm kuralı;
  11 bot idempotent seed. İzole PG test paketi `supabase/tests/academy_engine/`.
- **Faz 2**: 40 aday kaynak sicil seed'i + yerel doğrulama probe script'i +
  makinece okunabilir rapor (`docs/academy/source_verification.json`).
- **Faz 3**: `academy-worker` edge fn (kuyruk tüketici: scan→classify→draft→
  media→publish), DeepSeek istemcisi (JSON şema doğrulamalı), bilgi kartı
  üretici, pg_cron tanımları, bütçe sayaçları, dry-run guard (server-side).
- **Faz 4**: Flutter — academy okuma katmanı + feed bot rozeti + FırınNet
  Akademi toplu profil sayfası (konu filtresi, sayfalama, boş/hata durumları) +
  Mizah profili; PR #102'nin kullanışlı desenleri güncel main'e yeniden yazılır.
- **Faz 5**: Mizah etkileşim kuralları (yanıt/kendiliğinden yorum/DM),
  hız+bütçe sınırları, bot-bot döngü engeli, ciddi-konu filtresi.
- **Faz 6**: testler (izole PG + Flutter + fixture), analyze, tam suite, CI,
  üç-durumlu teslim raporu.

## Tamamlananlar

- 2026-09-28: Keşif (yukarıdaki tablo). Branch `feature/academy-engine-v1`.
- **Faz 1** (26f5d65): `20260929090000_academy_content_engine_v1.sql` —
  tablolar+RLS+RPC'ler+11 bot seed; DM bot istisnası; izole PG paketi
  `supabase/tests/academy_engine/` (01-06).
- **Faz 2** (80f7d90): 41 aday kaynak (`sources_candidates.json` → üretilen
  `20260929100000_academy_sources_seed_v1.sql`, 70 bot eşleştirmesi);
  canlı probe `scripts/academy_probe_sources.ps1` →
  `source_verification.json`: **feed=7 sitemap=12 html=13 unreachable=9 /41**.
- **Faz 3**: `supabase/functions/academy-worker/` (lib.ts saf mantık +
  index.ts IO; deno test 12/12), `20260929110000_academy_cron_v1.sql`
  (academy_cron_tick + pg_cron 30dk, Vault academy_worker_url/key,
  fail-soft), PG testleri 07-08. DeepSeek: model env `DEEPSEEK_MODEL`
  (varsayılan `deepseek-flash`; resmî docs 2026-09: deepseek-flash /
  deepseek-v4-pro), `response_format json_object`, bütçe sayaçları.
  **Kapsam dışı bırakılanlar (bilinçli, raporda)**: görsel üretimi
  (info-card dahil) v1'de YOK → metin-postu; JS-render/OCR/video yok.

- **Faz 4** (513beac): Flutter — AcademyPage (/academy, filtre+sayfalama+
  boş/hata), SocialPostCard bot rozeti + akademi yönlendirme, profil AI
  rozeti + Mesaj gating, model 22 konu; academy testleri 13/13, analyze 0.
- Örnek içerikler: `docs/academy/sample_posts.md` (biçim örneği; model
  üretimi DEĞİL — anahtar yok).

## Sıradaki adım (Faz 4-6)

1. Flutter: `lib/features/academy/` okuma katmanı (PR #102 deseni güncel
   main'e yeniden yazılır: AcademyRepository/Supabase/providers + model
   subtopics/is_humor/allow_dm alanları) + feed kartında AI/Akademi rozeti
   (`social_post_card.dart`) + `/academy` toplu profil sayfası (konu
   filtreleri = bot chip'leri, cursor sayfalama feed_posts owner_id in
   botIds, boş/hata/loading) + router + profil sayfasında bot davranışı
   (academyBotProfileProvider; bot profilinde DM butonu yalnız allow_dm).
2. Flutter testleri: academy sayfa/rozet/filtre/sayfalama/boş-hata;
   mevcut 2497 test regresyonsuz; analyze.
3. PR aç (feature/academy-engine-v1), CI, teslim raporu (3-durum:
   kod/dış entegrasyon/canlı işletim). MERGE + prod migration + deploy +
   cron/vault/secret kurulumu = KULLANICI ONAYI (canlı yayın yetkisi yok).

## V1.1 tamamlama turu — SONUÇ (2026-09-28)

Tüm P1–P6 maddeleri uygulandı (aşağıdaki liste artık DONE durum kaydıdır):
P1 ad7a06e, P2+P3 a8b6a94, P5/P6 sonraki commit. Kanıtlar: PG paketi 9
dosya ALL PASS (91 kaynak/155 eşleştirme, stale-worker, partial-dedupe,
atıf, B/C/E diyalogları); deno 18/18 + typecheck; kartlar GERÇEK render
(docs/academy/preview/*.png — TR karakter/taşma gözle OK); analyze 0.
Kalan canlı doğrulamalar (anahtar/deploy gerektirir): gerçek DeepSeek
çağrısı, prod Storage yüklemesi, cihazda feed görünümü.

## V1.1 orijinal eksik listesi (kapatıldı — tarihçe)

Durum doğrulaması: yerel=uzak=PR#110 head 50352bc; main 6c878c1; harici
(ChatGPT) değişiklik GitHub'a ULAŞMAMIŞ; PR #102 açık bırakıldı.

- [ ] P1 DB: complete_job stale-worker guard'ı; jobs dedupe index'i PARTIAL
  (queued/running) → dry-run→canlı + ertesi-gün + anahtar-sonrası yeniden
  kuyruklama açılır; publish/humor günlük sayaçlarına advisory lock (yarış);
  yayında kullanıcı-görünür KAYNAK atfı (ad+doğrulanmış URL+ticari not+tarih
  bağlamı); academy_extend_lease; mizah reply/DM RPC'leri (gönderim-anı
  yeniden doğrulama + tek-seviye yorum + duplicate-event).
- [ ] P2 Worker: bütçe günü Istanbul (UTC bug); per-feed-URL ETag/LM
  (kaynak-geneli tek etag bug'ı); robots.txt disallow uygulaması; indirme
  sırasında akış boyut sınırı; kaynak 'active' YALNIZ gerçek makale
  çıkarımından sonra; bot seçimi adil dağılım (ilk-konu bug'ı); claim batch
  küçült + iş başına lease uzatma (sıralı işleme süre aşımı); iddia-kaynak
  otomatik denetimi (sayı/oran metinde yoksa publishable=false); uydurma URL
  reddi domain değil doğrulanmış-URL bazlı; arşiv tarama cursor'u.
- [ ] P3 Görsel: resvg-wasm + gömülü TTF ile deterministik PNG bilgi/mizah
  kartı (sarı-beyaz, TR karakter); storage→academy_media→feed_media hattı;
  en az 1 Akademi + 1 Mizah kartı GERÇEK render + gözle kontrol.
- [ ] P4 Mizah B–E: kendi postuna yorum cevabı, DM cevabı, kendiliğinden
  yorum tetiği (maintenance event tarama), izinli kendiliğinden DM; tümü
  gönderim anında yeniden doğrulama + testler.
- [ ] P5 Kaynak: 41→80-100 aday (publisher_group tekilleştirme, TR somut);
  probe v2 içerik-çıkarım kanıtı (örnek URL+başlık+metin uzunluğu+tarih) →
  canlı rapor; seed yenile.
- [ ] P6 Flutter: Ayarlar'da mizah yorum/DM tercihleri (prefs tablosu RLS'i
  hazır); tüm test paketleri; PR güncelle; kanıtlı rapor.

## Kurulum (canlı etkinleştirme — henüz YAPILMADI)

1. `supabase functions deploy academy-worker` (verify_jwt default ON kalsın
   mı? Hayır: cron token'la çağırır → `--no-verify-jwt` gerek).
2. Secrets: `ACADEMY_WORKER_TOKEN` (rastgele), `DEEPSEEK_API_KEY`,
   (ops) `DEEPSEEK_MODEL`.
3. Vault: `academy_worker_url` = https://<ref>.supabase.co/functions/v1/academy-worker,
   `academy_worker_key` = ACADEMY_WORKER_TOKEN değeri.
4. Migration'lar prod'a; `academy_enabled=true` (dry_run=true ile önce
   kuru koşu; feed'e yayın için `academy_dry_run=false`).
5. Acil durdurma: `academy_enabled=false` (tick+publish+humor hepsi durur).
