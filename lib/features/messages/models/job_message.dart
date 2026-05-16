/// FırınNet — `job_messages` modeli.
///
/// Supabase tablosu: `job_messages` (V1, migration 20260516200000).
class JobMessage {
  const JobMessage({
    this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.isDeleted = false,
    this.createdAt,
  });

  final String? id;
  final String conversationId;
  final String senderId;
  final String body;
  final bool isDeleted;
  final DateTime? createdAt;

  /// UI gösterimi — soft-deleted mesaj için placeholder metin.
  String get displayBody => isDeleted ? '[Mesaj silindi]' : body;

  JobMessage copyWith({
    String? id,
    String? body,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return JobMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      body: body ?? this.body,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toInsertRow() => <String, dynamic>{
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': body,
      };

  factory JobMessage.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return JobMessage(
      id: row['id'] as String?,
      conversationId: (row['conversation_id'] as String?) ?? '',
      senderId: (row['sender_id'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      isDeleted: (row['is_deleted'] as bool?) ?? false,
      createdAt: parse(row['created_at']),
    );
  }
}
