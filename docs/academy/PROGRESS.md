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

- 2026-09-28: Keşif tamamlandı (yukarıdaki tablo). Branch:
  `feature/academy-engine-v1`.

## Sıradaki adım

- Faz 1 migration + seed + RLS + izole PG testleri.
