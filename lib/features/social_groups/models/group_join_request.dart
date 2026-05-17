/// V1 P1-D — Bir kullanıcının private gruba katılma isteği.
///
/// Supabase tablosu (`group_join_requests`):
///   id, group_id, requester_id, status, message, decided_by, decided_at,
///   created_at, updated_at
///
/// `status` enum'u DB CHECK'iyle eşleşir: pending / approved / rejected / cancelled.
/// Yazma yalnız `request_group_join` + `decide_group_join_request` RPC üzerinden.
enum GroupJoinRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static GroupJoinRequestStatus fromPersist(String? key) {
    switch (key) {
      case 'approved':
        return GroupJoinRequestStatus.approved;
      case 'rejected':
        return GroupJoinRequestStatus.rejected;
      case 'cancelled':
        return GroupJoinRequestStatus.cancelled;
      case 'pending':
      default:
        return GroupJoinRequestStatus.pending;
    }
  }

  String get persistKey {
    switch (this) {
      case GroupJoinRequestStatus.pending:
        return 'pending';
      case GroupJoinRequestStatus.approved:
        return 'approved';
      case GroupJoinRequestStatus.rejected:
        return 'rejected';
      case GroupJoinRequestStatus.cancelled:
        return 'cancelled';
    }
  }
}

class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.requesterId,
    required this.status,
    this.message,
    this.requesterName,
    this.requesterBadge,
    this.requesterCity,
    required this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String groupId;
  final String requesterId;
  final GroupJoinRequestStatus status;
  final String? message;

  /// Owner UI'da gösterilecek requester profili bilgileri — listPending sorgusu
  /// `profiles` join'i ile doldurur. Tek-istek lookup'larda null olabilir.
  final String? requesterName;
  final String? requesterBadge;
  final String? requesterCity;

  final DateTime createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == GroupJoinRequestStatus.pending;

  factory GroupJoinRequest.fromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? profileRow,
  }) {
    return GroupJoinRequest(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      requesterId: row['requester_id'] as String,
      status: GroupJoinRequestStatus.fromPersist(row['status'] as String?),
      message: row['message'] as String?,
      requesterName: profileRow?['display_name'] as String?,
      requesterBadge: profileRow?['profession_badge'] as String?,
      requesterCity: profileRow?['city'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      decidedAt: row['decided_at'] == null
          ? null
          : DateTime.parse(row['decided_at'] as String),
    );
  }
}
