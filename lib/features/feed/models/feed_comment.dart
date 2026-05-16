/// Sosyal Omurga V1 — feed_comments satırı.
///
/// Supabase tablosu zaten `social_spine_v1` migration'ında tanımlı:
/// `feed_comments(id, post_id, owner_id, text, author_name, author_role,
///                is_deleted, created_at, updated_at)`
/// RLS: select_visible (is_deleted=false), insert/update/delete owner_id=auth.uid().
/// author_name + author_role server-side BEFORE INSERT trigger ile snapshot.
/// comment_count feed_posts'ta AFTER trigger ile bakım edilir.
class FeedComment {
  const FeedComment({
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

  factory FeedComment.fromRow(Map<String, dynamic> row) {
    return FeedComment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      ownerId: row['owner_id'] as String,
      text: (row['text'] as String?) ?? '',
      authorName: (row['author_name'] as String?) ?? 'FırınNet Kullanıcısı',
      authorRole: (row['author_role'] as String?) ?? 'Üye',
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
