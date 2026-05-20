-- FırınNet — Social P0 delete fix: RETURNING SELECT policy rollback.
--
-- Background:
--   `supabase_flutter ^2.5.6` (postgrest 2.x) `.update()` çağrısı sonrası
--   RETURNING phase'inde `SELECT policy` uygulanır. Mevcut
--   `feed_posts_select_visible USING (is_deleted = false)` ve
--   `feed_comments_select_visible USING (is_deleted = false)` politikaları,
--   soft-delete UPDATE (`is_deleted=true` set) sonrası RETURNING ile dönen
--   yeni satır için SELECT testini geçemiyor. Postgres `42501 new row
--   violates row-level security policy` fırlatıyor, transaction rollback
--   oluyor; `is_deleted` değişmeden kalıyor.
--
-- Fix:
--   SELECT policy USING clause'una OR ile owner-self koşulu eklenir.
--   Soft-delete sonrası owner kendi yeni-soft-deleted satırını RETURNING
--   ile geri okuyabilir; transaction commit olur.
--
-- Güvenlik:
--   Diğer kullanıcılar hâlâ soft-deleted satırları göremez. Tüm liste
--   query'leri client tarafında `.eq('is_deleted', false)` filtresi
--   uygular (listPosts, listPostsByOwner, listMedia, listComments). Bu
--   yüzden owner'ın UI feed'inde de soft-deleted satırlar gözükmez —
--   sadece UPDATE RETURNING context'inde owner self görür.
--
-- Risk: düşük; sadece USING clause genişletilir, INSERT/UPDATE/DELETE
-- politikaları etkilenmez.

ALTER POLICY feed_posts_select_visible
  ON public.feed_posts
  USING (is_deleted = false OR owner_id = auth.uid());

ALTER POLICY feed_comments_select_visible
  ON public.feed_comments
  USING (is_deleted = false OR owner_id = auth.uid());
