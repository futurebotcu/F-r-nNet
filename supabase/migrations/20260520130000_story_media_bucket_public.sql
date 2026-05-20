-- FırınNet — Story P0 reality fix: `story-media` bucket public.
--
-- Smoke gözlemi (Commit 3.6 sonrası):
--   * Story upload + INSERT + soft-delete chain çalışıyor.
--   * DB'de `feed_stories` row'ları + storage'da object'ler var.
--   * Ama viewer açıldığında `CachedNetworkImage(story.contentUrl)`
--     resmi yüklemiyor → Story "çalışmıyor" hissi.
--
-- Root cause:
--   * `story-media` bucket `public=false` ile kuruldu (V1 Commit 2).
--   * `supabase_social_stories_repository.dart:119`:
--       `_client.storage.from('story-media').getPublicUrl(path)` private
--       bucket'tan da URL string'i döndürür ama bu URL **erişilemez**.
--   * Sonuçta DB'de saklanan content_url Image.network ile açılmıyor.
--
-- Karar (kullanıcı onaylı):
--   * V1 için story görünür sosyal içerik (feed-media + avatars gibi).
--   * `feed_stories` RLS tablo seviyesinde zaten görünürlüğü kontrol
--     ediyor: `(is_deleted=false AND expires_at>now()) OR
--     owner_id=auth.uid()`. Yani app içinde expired/silinmiş story'ler
--     gizli kalır.
--   * UUID path (`{owner_id}/{story_id}.jpg`) brute-force güvenli.
--   * Bucket public=true → mevcut content_url'ler hiç değişmeden
--     çalışır (rebuild gerekmez).
--
-- Release-öncesi P1 (out of scope):
--   * Expired story storage cleanup cron (24h sonra orphan object
--     temizliği).
--   * Veya signed URL hardening (private bucket + createSignedUrl).
--   * Bu V1'de yapılmaz; bucket public yeterli.

update storage.buckets
set public = true
where id = 'story-media';
