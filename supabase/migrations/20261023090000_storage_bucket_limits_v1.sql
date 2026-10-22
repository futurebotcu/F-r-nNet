-- ============================================================
-- Storage bucket sunucu tarafı sınırları (boyut + MIME allowlist)
--
-- Sorun (denetim 2026-10-16 S4): 5 bucket'ın hiçbirinde file_size_limit /
-- allowed_mime_types yoktu; 4'ü public. Upload policy'leri yalnız yol
-- sahipliğini (<uid>/...) denetliyor → doğrudan API çağrısıyla herhangi bir
-- türde (HTML/SVG dahil) ve büyüklükte dosya public bucket'ta barındırılabilir.
--
-- Değerler istemcinin GERÇEKTEN ürettiği türlerden çıkarıldı (2026-10-23):
--   avatars      : jpeg/png/webp/gif       · istemci cap 5 MB
--   market-media : jpeg/png/webp           · ilan + B2B (5 MB)
--   story-media  : jpeg/png/webp           · 5 MB
--   feed-media   : jpeg/png/webp/gif + mp4/quicktime/webm · video 50 MB
--   chat-media   : jpeg/png/webp + mp4/quicktime · görsel 10 / video 25 MB
-- Sınırlar istemci cap'lerinin ÜSTÜNDE marjlı (sıkıştırma farkları için).
--
-- ADDİTİF / VERİ DEĞİŞTİRMEZ: yalnız storage.buckets ayarları. Mevcut
-- nesneler etkilenmez (sınırlar yalnız yeni yüklemelerde uygulanır).
-- Geri alma: dosya sonundaki blok (limitleri null'a çeker).
-- PRODUCTION'A ONAYLA UYGULANIR.
-- ============================================================

update storage.buckets
   set file_size_limit = 6 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
 where id = 'avatars';

update storage.buckets
   set file_size_limit = 6 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'market-media';

update storage.buckets
   set file_size_limit = 6 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'story-media';

update storage.buckets
   set file_size_limit = 52 * 1024 * 1024,
       allowed_mime_types = array[
         'image/jpeg', 'image/png', 'image/webp', 'image/gif',
         'video/mp4', 'video/quicktime', 'video/webm'
       ]
 where id = 'feed-media';

update storage.buckets
   set file_size_limit = 26 * 1024 * 1024,
       allowed_mime_types = array[
         'image/jpeg', 'image/png', 'image/webp',
         'video/mp4', 'video/quicktime'
       ]
 where id = 'chat-media';

-- ROLLBACK (referans):
--   update storage.buckets set file_size_limit = null, allowed_mime_types = null
--    where id in ('avatars','market-media','story-media','feed-media','chat-media');
