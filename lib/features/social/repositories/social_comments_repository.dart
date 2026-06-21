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
  /// Bir post için yorumlar (eski tarih önce, is_deleted=false). Üst yorumlar
  /// ve cevaplar birlikte döner; UI parentCommentId'ye göre gruplar.
  /// `isLiked` mevcut kullanıcının beğenisinden türetilir.
  Future<List<SocialComment>> listComments(String postId);

  /// Yeni yorum/cevap oluştur. `author_name`/`author_role` server-side
  /// snapshot trigger ile doldurulur. `parentCommentId` dolu ise tek-seviye
  /// cevaptır (parent bir ÜST yorum olmalı; server guard zorlar).
  Future<SocialComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });

  /// Yoruma beğeni toggle. Dönen değer yeni beğeni durumu (true = beğenildi).
  Future<bool> toggleCommentLike(String commentId);

  /// Soft delete (`is_deleted=true`). RLS owner-only. Üst yorum silinince
  /// cevapları da server trigger ile soft-delete olur.
  Future<void> deleteComment(String commentId);

  /// Repository değişikliklerinde tetiklenir (UI invalidate için).
  Stream<void> watch();
}
