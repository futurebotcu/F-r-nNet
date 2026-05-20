// FırınNet Social V2 Commit 2 — Story repository interface.
// Donor `StoriesBaseRepository` muadili. Üç impl:
//   * Supabase — `feed_stories` table + `story-media` bucket.
//   * Local — in-memory test/guest parite.
//   * Guarded — guest write guard dekoratörü.

import 'dart:typed_data';

import '../models/social_story.dart';

abstract class SocialStoriesRepository {
  /// Aktif (is_deleted=false AND expires_at > now()) story'leri newest
  /// first döner. RLS owner self soft-deleted/expired'ı görür ama client
  /// query'si defansif `expires_at > now()` filtresi de uygular.
  Future<List<SocialStory>> listFreshStories();

  /// Belirli kullanıcının aktif story listesi (owner profile için).
  Future<List<SocialStory>> listFreshStoriesOf(String ownerId);

  /// Yeni story oluştur. Akış:
  ///   1. Storage'a yükle → `{owner_id}/{story_id}.{ext}` path
  ///   2. `feed_stories` INSERT — RLS owner_id=auth.uid() WITH CHECK
  ///   3. Geri dönen `SocialStory`'de `content_url` storage public URL
  /// Upload veya INSERT fail → orphan engellemek için cleanup yapılır.
  Future<SocialStory> createImageStory({
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Soft-delete owner-only. Update sonrası `.select('id')` boş ise
  /// StateError fırlatır (P0 hardening pattern'i).
  Future<void> deleteStory(String storyId);

  /// Mutation tick — UI invalidate için.
  Stream<void> watch();
}
