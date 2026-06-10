// FırınNet Messaging M1 — Message model.
//
// V1 message_type: 'text' veya 'system'. Client doğrudan 'text' atabilir
// (RLS WITH CHECK `message_type='text'`). 'system' yalnız SECURITY DEFINER
// RPC ile gelir (V1.1: konuşma seed).
//
// V1 attachments hep NULL; image/file V1.1'e ertelendi.

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.attachments,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    // Sidecar (UI)
    this.senderName,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;

  /// `text` | `system`.
  final String messageType;

  /// V1.1+ image/file için. V1'de hep null.
  final Map<String, dynamic>? attachments;

  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// Sidecar — UI render için (profiles join).
  final String? senderName;

  bool get isText => messageType == 'text';
  bool get isSystem => messageType == 'system';
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;

  // Sprint G — image eki. message_type 'text' kalır; resim attachments ile
  // taşınır. `imageUrl` repo tarafından signed URL ile doldurulur (url alanı).
  bool get hasImage => (attachments?['media_type'] as String?) == 'image';
  String? get imageUrl => attachments?['url'] as String?;
  String? get imageStoragePath => attachments?['storage_path'] as String?;

  Message copyWith({
    String? content,
    String? messageType,
    Map<String, dynamic>? attachments,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? senderName,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      senderName: senderName ?? this.senderName,
    );
  }

  /// Supabase INSERT için map. message_type sabit 'text' — V1 client.
  /// (RLS zaten ENFORCED ediyor ama defansif şekilde de burada zorlanır.)
  Map<String, dynamic> toInsertRow({
    required String senderId,
    required String conversationId,
    required String content,
  }) {
    return <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': 'text',
    };
  }

  static Message fromRow(
    Map<String, dynamic> row, {
    String? senderName,
  }) {
    DateTime parse(String s) =>
        DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      content: (row['content'] as String?) ?? '',
      messageType: (row['message_type'] as String?) ?? 'text',
      attachments: row['attachments'] as Map<String, dynamic>?,
      createdAt: parse((row['created_at'] as String?) ?? ''),
      editedAt: (row['edited_at'] as String?) != null
          ? DateTime.tryParse(row['edited_at'] as String)
          : null,
      deletedAt: (row['deleted_at'] as String?) != null
          ? DateTime.tryParse(row['deleted_at'] as String)
          : null,
      senderName: senderName,
    );
  }
}
