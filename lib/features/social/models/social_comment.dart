/// FırınNet Social — Comment model.
///
/// Supabase `feed_comments` şemasına uyarlandı (post_id, owner_id, text,
/// author_name/role snapshot, is_deleted, created_at). RLS owner-only CRUD +
/// select visible.
///
/// PR #2: yoruma beğeni ([likeCount]/[isLiked]) + tek-seviye cevap
/// ([parentCommentId]). `parentCommentId` null → üst yorum; dolu → cevap.
class SocialComment {
  const SocialComment({
    required this.id,
    required this.postId,
    required this.ownerId,
    required this.text,
    required this.authorName,
    required this.authorRole,
    required this.isDeleted,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.parentCommentId,
  });

  final String id;
  final String postId;
  final String ownerId;
  final String text;
  final String authorName;
  final String authorRole;
  final bool isDeleted;
  final DateTime createdAt;

  /// Yorum beğeni sayısı (feed_comment_likes trigger ile tutulur).
  final int likeCount;

  /// Mevcut kullanıcı bu yorumu beğenmiş mi (repo türetir, satırda değil).
  final bool isLiked;

  /// Tek-seviye cevap: dolu ise üst yoruma cevap. null → üst yorum.
  final String? parentCommentId;

  bool get isReply => parentCommentId != null;

  SocialComment copyWith({
    bool? isDeleted,
    int? likeCount,
    bool? isLiked,
  }) {
    return SocialComment(
      id: id,
      postId: postId,
      ownerId: ownerId,
      text: text,
      authorName: authorName,
      authorRole: authorRole,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      parentCommentId: parentCommentId,
    );
  }

  factory SocialComment.fromRow(
    Map<String, dynamic> row, {
    bool isLiked = false,
  }) {
    return SocialComment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      ownerId: row['owner_id'] as String,
      text: (row['text'] as String?) ?? '',
      authorName:
          (row['author_name'] as String?) ?? 'FırınNet Kullanıcısı',
      authorRole: (row['author_role'] as String?) ?? 'Üye',
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      likeCount: (row['like_count'] as int?) ?? 0,
      isLiked: isLiked,
      parentCommentId: row['parent_comment_id'] as String?,
    );
  }
}
