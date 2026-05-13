/// Grup içinde paylaşılmış tek bir mesaj.
///
/// Supabase şeması:
/// group_messages(
///   id, group_id, author_name, author_role, text,
///   is_pinned, reaction_count, created_at
/// )
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.createdAt,
    this.isPinned = false,
    this.reactionCount = 0,
  });

  final String id;
  final String groupId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime createdAt;
  final bool isPinned;
  final int reactionCount;
}
