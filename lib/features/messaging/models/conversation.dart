// FırınNet Messaging M1 — Generic conversation model.
//
// Migration: 20260520160000_messaging_m1_generic.sql
// Bağlam: market_listing / profile_direct / job_offer / job_seek.
// V1 sadece direct (1-1); group V1.2'ye ertelendi.

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.contextType,
    this.contextId,
    this.title,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    // Sidecar — repository tarafında doldurulur (UI rendering için).
    this.otherUserId,
    this.otherUserName,
    this.lastMessageContent,
    this.lastMessageSenderId,
    this.lastMessageCreatedAt,
    this.lastReadAt,
    this.unreadCount = 0,
  });

  /// `direct` (V1) veya `group` (V1.2 reserved).
  final String type;

  /// `market_listing` / `profile_direct` / `job_offer` / `job_seek`.
  final String contextType;

  /// V1: profile_direct → null; diğer 3 → ilgili entity id (DB CHECK).
  final String? contextId;

  /// Group only — V1 direct'te null.
  final String? title;

  final String id;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Sidecar (UI yardımcıları, DB kolonu değil) ────────────────────

  /// Direct conversation karşı taraf id (kendim hariç katılımcı).
  final String? otherUserId;

  /// Karşı taraf görünür adı (profiles join sidecar).
  final String? otherUserName;

  final String? lastMessageContent;
  final String? lastMessageSenderId;
  final DateTime? lastMessageCreatedAt;

  /// Self katılımcının `conversation_participants.last_read_at`.
  final DateTime? lastReadAt;

  /// Self için okunmamış mesaj sayısı (RPC `conversation_unread_count`).
  final int unreadCount;

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';
  bool get hasUnread => unreadCount > 0;

  bool get isMarketListingContext => contextType == 'market_listing';
  bool get isProfileDirectContext => contextType == 'profile_direct';
  bool get isJobOfferContext => contextType == 'job_offer';
  bool get isJobSeekContext => contextType == 'job_seek';

  Conversation copyWith({
    String? type,
    String? contextType,
    String? contextId,
    String? title,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? otherUserId,
    String? otherUserName,
    String? lastMessageContent,
    String? lastMessageSenderId,
    DateTime? lastMessageCreatedAt,
    DateTime? lastReadAt,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      type: type ?? this.type,
      contextType: contextType ?? this.contextType,
      contextId: contextId ?? this.contextId,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageCreatedAt:
          lastMessageCreatedAt ?? this.lastMessageCreatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  static Conversation fromRow(
    Map<String, dynamic> row, {
    String? otherUserId,
    String? otherUserName,
    String? lastMessageContent,
    String? lastMessageSenderId,
    DateTime? lastMessageCreatedAt,
    DateTime? lastReadAt,
    int unreadCount = 0,
  }) {
    DateTime parse(String s) =>
        DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Conversation(
      id: row['id'] as String,
      type: (row['type'] as String?) ?? 'direct',
      contextType: (row['context_type'] as String?) ?? 'profile_direct',
      contextId: row['context_id'] as String?,
      title: row['title'] as String?,
      createdBy: row['created_by'] as String?,
      createdAt: parse((row['created_at'] as String?) ?? ''),
      updatedAt: parse((row['updated_at'] as String?) ?? ''),
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      lastMessageContent: lastMessageContent,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageCreatedAt: lastMessageCreatedAt,
      lastReadAt: lastReadAt,
      unreadCount: unreadCount,
    );
  }
}
