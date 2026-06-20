import 'dealer_driver.dart';

/// Şoför daveti (Sprint 6). Patron pending davet oluşturur; şoför kabul edince
/// dealer_drivers (aktif bağlantı) oluşur. Supabase: dealer_driver_invites.
enum DealerDriverInviteStatus { pending, accepted, rejected, cancelled }

extension DealerDriverInviteStatusX on DealerDriverInviteStatus {
  String get persistKey => name;

  String get label {
    switch (this) {
      case DealerDriverInviteStatus.pending:
        return 'Bekliyor';
      case DealerDriverInviteStatus.accepted:
        return 'Kabul edildi';
      case DealerDriverInviteStatus.rejected:
        return 'Reddedildi';
      case DealerDriverInviteStatus.cancelled:
        return 'İptal edildi';
    }
  }

  static DealerDriverInviteStatus fromKey(String? key) {
    switch (key) {
      case 'accepted':
        return DealerDriverInviteStatus.accepted;
      case 'rejected':
        return DealerDriverInviteStatus.rejected;
      case 'cancelled':
        return DealerDriverInviteStatus.cancelled;
      case 'pending':
      default:
        return DealerDriverInviteStatus.pending;
    }
  }
}

class DealerDriverInvite {
  const DealerDriverInvite({
    required this.id,
    required this.invitedUserId,
    required this.driverName,
    this.driverPhone = '',
    this.note = '',
    required this.status,
    required this.createdAt,
    this.ownerName = '',
    this.permissionLevel = DriverPermission.half,
  });

  final String id;
  final String invitedUserId;
  final String driverName;
  final String driverPhone;
  final String note;
  final DealerDriverInviteStatus status;
  final DateTime createdAt;

  /// Şoför tarafı görünümü için davet eden işletme/kişi adı (opsiyonel).
  final String ownerName;

  /// Davette taşınan yetki seviyesi; kabul edilince dealer_drivers'a kopyalanır.
  final DriverPermission permissionLevel;
}
