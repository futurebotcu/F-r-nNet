/// FırınNet — `job_conversations` modeli.
///
/// Supabase tablosu: `job_conversations` (V1, migration 20260516200000).
/// 1-1 sohbet kanalı. `related_type` ile bağlı olduğu post tablosu:
/// `job_offer` ↔ `job_offer_posts(id)`, `job_seek` ↔ `job_seek_posts(id)`.
class JobConversation {
  const JobConversation({
    this.id,
    required this.relatedType,
    this.jobOfferId,
    this.jobSeekPostId,
    required this.initiatorId,
    required this.recipientId,
    this.status = 'open',
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    this.relatedTitle,
    this.otherPartyName,
  });

  final String? id;

  /// `'job_offer'` veya `'job_seek'`.
  final String relatedType;
  final String? jobOfferId;
  final String? jobSeekPostId;

  final String initiatorId;
  final String recipientId;

  /// `'open'` veya `'closed'`.
  final String status;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// UI joini — list ekranı için ilan başlığı (Supabase select join'inden gelir).
  final String? relatedTitle;

  /// UI joini — list ekranı için karşı tarafın display_name'i.
  final String? otherPartyName;

  bool get isClosed => status == 'closed';
  bool get isOpen => status == 'open';

  /// Verilen user perspektifinden "öteki taraf" id'si.
  String otherPartyId(String selfId) =>
      initiatorId == selfId ? recipientId : initiatorId;

  JobConversation copyWith({
    String? id,
    String? status,
    DateTime? lastMessageAt,
    DateTime? updatedAt,
    String? relatedTitle,
    String? otherPartyName,
  }) {
    return JobConversation(
      id: id ?? this.id,
      relatedType: relatedType,
      jobOfferId: jobOfferId,
      jobSeekPostId: jobSeekPostId,
      initiatorId: initiatorId,
      recipientId: recipientId,
      status: status ?? this.status,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relatedTitle: relatedTitle ?? this.relatedTitle,
      otherPartyName: otherPartyName ?? this.otherPartyName,
    );
  }

  Map<String, dynamic> toInsertRow() => <String, dynamic>{
        'related_type': relatedType,
        if (jobOfferId != null) 'job_offer_id': jobOfferId,
        if (jobSeekPostId != null) 'job_seek_post_id': jobSeekPostId,
        'initiator_id': initiatorId,
        'recipient_id': recipientId,
        'status': status,
      };

  factory JobConversation.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return JobConversation(
      id: row['id'] as String?,
      relatedType: (row['related_type'] as String?) ?? 'job_offer',
      jobOfferId: row['job_offer_id'] as String?,
      jobSeekPostId: row['job_seek_post_id'] as String?,
      initiatorId: (row['initiator_id'] as String?) ?? '',
      recipientId: (row['recipient_id'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'open',
      lastMessageAt: parse(row['last_message_at']),
      createdAt: parse(row['created_at']),
      updatedAt: parse(row['updated_at']),
      relatedTitle: row['related_title'] as String?,
      otherPartyName: row['other_party_name'] as String?,
    );
  }
}
