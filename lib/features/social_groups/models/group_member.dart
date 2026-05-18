/// V1 Sprint 2 — Grup üyesi profil snapshot'ı.
///
/// `listMembers` join sonucu: group_members + profiles. Profile alanları
/// nullable (RLS başka kullanıcı için minimum görünür alanları döner).
class GroupMemberProfile {
  const GroupMemberProfile({
    required this.userId,
    required this.displayName,
    this.professionBadge,
    this.city,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final String? professionBadge;
  final String? city;

  /// 'owner' | 'member' (DB'de free-text; default 'member').
  final String role;
  final DateTime joinedAt;

  bool get isOwner => role == 'owner';

  GroupMemberProfile copyWith({
    String? displayName,
    String? professionBadge,
    String? city,
    String? role,
    DateTime? joinedAt,
  }) {
    return GroupMemberProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      professionBadge: professionBadge ?? this.professionBadge,
      city: city ?? this.city,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

/// V1 Sprint 2 — Owner gruptan çıktığında `leave_group_safely` RPC sonucu.
///
///  * left        → non-owner üye çıktı veya owner için (tasarımca bu yola
///                  girilmez); owner için 'transferred' veya 'closed' döner.
///  * transferred → owner çıktı, liderlik en eski üyeye geçti.
///  * closed      → owner tek üyeydi, grup soft-delete oldu.
enum GroupLeaveOutcome {
  left,
  transferred,
  closed;

  static GroupLeaveOutcome fromPersist(String? value) {
    switch (value) {
      case 'transferred':
        return GroupLeaveOutcome.transferred;
      case 'closed':
        return GroupLeaveOutcome.closed;
      case 'left':
      default:
        return GroupLeaveOutcome.left;
    }
  }
}
