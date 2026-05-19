import 'dart:typed_data';

import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
import '../models/feed_media.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';

/// Feed için soyut erişim.
///
/// V1: [LocalFeedRepository] (in-memory) ile çalışır, demo seed barındırır.
/// V2: SupabaseFeedRepository — yalnızca aynı yüzeyi uyarlayacak,
///      UI ve servis katmanı değişmeyecek.
abstract class FeedRepository {
  /// Tüm postlar (newest first). Opsiyonel tip filtresi.
  Future<List<FeedPost>> listPosts({PostType? type});

  /// V1 Social S1 — Belirli bir kullanıcının post listesi (newest first).
  /// Public profile sayfası için. `is_deleted=false` filtreli; RLS herkesi
  /// public feed select için zaten yetkilendiriyor.
  Future<List<FeedPost>> listPostsByOwner(String ownerId);

  /// Yeni post ekle (composer'dan). Postu döner.
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  });

  /// V1 Social S3 — Mevcut bir post'a image attach et.
  ///
  /// Akış:
  ///   1. Supabase Storage `feed-media` bucket'ına bytes yüklenir
  ///      ({owner_id}/{post_id}/{media_id}.{ext} path).
  ///   2. `feed_media` satırı INSERT edilir.
  ///   3. Geri dönen `FeedMedia` modelinde publicUrl dolu olur.
  ///
  /// Local impl test/seed için sahte URL üretir.
  Future<FeedMedia> uploadFeedImage({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
  });

  /// V1 Feed F1 — Owner-only post soft-delete. `feed_posts.is_deleted=true`.
  /// RLS DELETE/UPDATE policy zaten owner-only; defansif olarak client
  /// `eq('owner_id', userId)` da ekler. Owner olmayan çağrı sessiz no-op.
  Future<void> deletePost(String postId);

  /// Like toggle: false → true (count+1), true → false (count-1).
  Future<FeedPost> toggleLike(String postId);

  /// Save (bookmark) toggle.
  Future<FeedPost> toggleSave(String postId);

  /// Insight kartları (sosyal büyüme rozetleri).
  Future<List<FeedInsight>> listInsights();

  /// V1 — Feed yorumları (post bazlı liste, yalnız is_deleted=false).
  /// Eski tarih önce; UI üst-üste-eklenir akış için reversed yapabilir.
  Future<List<FeedComment>> listComments(String postId);

  /// Yorum ekle. `author_name` ve `author_role` Supabase tarafında snapshot
  /// trigger ile doldurulur; client yalnız `text` gönderir. Local impl
  /// caller'dan gelen `currentAuthorName/Role` ile doldurur (offline demo).
  Future<FeedComment> addComment({
    required String postId,
    required String text,
    String? currentAuthorName,
    String? currentAuthorRole,
  });

  /// Soft delete — yalnız `is_deleted=true` (yorumlar V1'de geri silinmez).
  Future<void> deleteComment(String commentId);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
