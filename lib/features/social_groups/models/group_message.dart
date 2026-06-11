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
    this.ownerId,
    this.isPinned = false,
    this.reactionCount = 0,
    this.attachments,
  });

  final String id;
  final String groupId;

  /// UGC Safety V1 — yazarın user id'si (DB `owner_id`, eskiden parse
  /// edilmiyordu). Şikayet/engelleme ve "kendi mesajı" ayrımı için.
  /// Eski local/optimistic kayıtlarda null olabilir.
  final String? ownerId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime createdAt;
  final bool isPinned;
  final int reactionCount;

  /// Sprint G — opsiyonel resim eki metadata (jsonb):
  /// `{media_type:image, storage_path, width, height, size_bytes, url}`.
  /// `url` repo tarafından signed URL ile doldurulur.
  final Map<String, dynamic>? attachments;

  bool get hasImage => (attachments?['media_type'] as String?) == 'image';
  String? get imageUrl => attachments?['url'] as String?;
  String? get imageStoragePath => attachments?['storage_path'] as String?;

  // Chat Media V1.1 — video eki (media_type=video). Bilinmeyen media_type
  // iki getter'da da false → text bubble fallback, eski mesajlar bozulmaz.
  bool get hasVideo => (attachments?['media_type'] as String?) == 'video';
  String? get videoUrl => attachments?['url'] as String?;
}
