import '../models/social_comment.dart';

/// FırınNet Social Comments — soyut erişim.
///
/// Üç impl:
///   * [SupabaseSocialCommentsRepository] — `feed_comments` tablosuna.
///   * [LocalSocialCommentsRepository] — in-memory parite (test/guest).
///   * [GuardedSocialCommentsRepository] — guest write guard.
///
/// Donor (itsezlife) `PostsRepository.commentsOf()` + `createComment()` +
/// `deleteComment()` pattern'ı; bizim sıkı RLS standardına uyumlu (owner
/// kontrolü server-side `auth.uid()` ile).
abstract class SocialCommentsRepository {
  /// Bir post için yorumlar (eski tarih önce, is_deleted=false).
  /// V1 için tek seviye; donor `replied_to_comment_id` field'ı şu an
  /// kullanılmaz.
  Future<List<SocialComment>> listComments(String postId);

  /// Yeni yorum oluştur. `author_name` ve `author_role` server-side
  /// snapshot trigger ile doldurulur. Client sadece `text` gönderir.
  Future<SocialComment> addComment({
    required String postId,
    required String text,
  });

  /// Soft delete (`is_deleted=true`). RLS owner-only.
  Future<void> deleteComment(String commentId);

  /// Repository değişikliklerinde tetiklenir (UI invalidate için).
  Stream<void> watch();
}
