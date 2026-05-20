// FırınNet Messaging M1 — conversation_participants modeli.
//
// V1 direct: 2 row per conversation (owner + member). V1.2 group: N row.
// `last_read_at` unread hesaplaması için kullanılır.

class ConversationParticipant {
  const ConversationParticipant({
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.lastReadAt,
  });

  final String conversationId;
  final String userId;

  /// `owner` | `admin` | `member`.
  final String role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';

  static ConversationParticipant fromRow(Map<String, dynamic> row) {
    DateTime parse(String s) =>
        DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ConversationParticipant(
      conversationId: row['conversation_id'] as String,
      userId: row['user_id'] as String,
      role: (row['role'] as String?) ?? 'member',
      joinedAt: parse((row['joined_at'] as String?) ?? ''),
      lastReadAt: (row['last_read_at'] as String?) != null
          ? DateTime.tryParse(row['last_read_at'] as String)
          : null,
    );
  }
}
