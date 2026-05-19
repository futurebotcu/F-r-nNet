/// FırınNet Social — Comment model.
///
/// Donor (itsezlife flutter-instagram-offline-first-clone) `Comment`
/// modelinden esinlenildi; Supabase `feed_comments` şemasına uyarlandı
/// (post_id, owner_id, text, author_name/role snapshot, is_deleted,
/// created_at). RLS owner-only CRUD + select visible.
///
/// V1: tek seviye yorum. Nested reply (replied_to_comment_id) V2'de
/// eklenebilir (donor şemasında var; biz şimdilik kullanmıyoruz).
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
  });

  final String id;
  final String postId;
  final String ownerId;
  final String text;
  final String authorName;
  final String authorRole;
  final bool isDeleted;
  final DateTime createdAt;

  factory SocialComment.fromRow(Map<String, dynamic> row) {
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
    );
  }
}
