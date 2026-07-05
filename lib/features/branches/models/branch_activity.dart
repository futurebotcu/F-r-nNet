import 'package:flutter/material.dart';

/// Şube Yönetimi V2 — aktivite geçmişi modelleri.
///
/// branch_activity_log satırlarının UI karşılığı. event_type persistKey'leri
/// DB CHECK constraint'iyle birebir aynıdır (branch_management_v1 migration);
/// yeni değer migration gerektirir. Log append-only'dir; yazma yalnız RPC içi.
enum BranchActivityEvent {
  processCreated,
  processUpdated,
  statusChanged,
  membershipChanged,
  inviteCreated,
  inviteResponded,
}

extension BranchActivityEventMeta on BranchActivityEvent {
  String get persistKey {
    switch (this) {
      case BranchActivityEvent.processCreated:
        return 'process_created';
      case BranchActivityEvent.processUpdated:
        return 'process_updated';
      case BranchActivityEvent.statusChanged:
        return 'status_changed';
      case BranchActivityEvent.membershipChanged:
        return 'membership_changed';
      case BranchActivityEvent.inviteCreated:
        return 'invite_created';
      case BranchActivityEvent.inviteResponded:
        return 'invite_responded';
    }
  }

  /// Personel (davet/üyelik) olayı mı, süreç olayı mı?
  bool get isStaffEvent =>
      this == BranchActivityEvent.membershipChanged ||
      this == BranchActivityEvent.inviteCreated ||
      this == BranchActivityEvent.inviteResponded;

  static BranchActivityEvent fromKey(String key) =>
      BranchActivityEvent.values.firstWhere(
        (e) => e.persistKey == key,
        orElse: () => BranchActivityEvent.processUpdated,
      );
}

/// Tek aktivite satırı. [note] RPC'lerin yazdığı makine değeridir
/// (örn. status persistKey'i, 'accepted'/'rejected', 'permissions');
/// kullanıcı diline [description] çevirir.
@immutable
class BranchActivityEntry {
  const BranchActivityEntry({
    required this.id,
    required this.branchId,
    required this.event,
    this.actorName = '',
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String branchId;
  final BranchActivityEvent event;
  final String actorName;
  final String note;
  final DateTime? createdAt;

  bool get isAttention =>
      event == BranchActivityEvent.statusChanged && note == 'attention';
  bool get isCompleted =>
      event == BranchActivityEvent.statusChanged && note == 'completed';

  /// Fırıncı dilinde kısa açıklama (note makine değerinden türetilir).
  String get description {
    switch (event) {
      case BranchActivityEvent.inviteCreated:
        return 'Personel daveti gönderildi';
      case BranchActivityEvent.inviteResponded:
        return note == 'accepted'
            ? 'Personel daveti kabul edildi'
            : 'Personel daveti reddedildi';
      case BranchActivityEvent.membershipChanged:
        switch (note) {
          case 'suspended':
            return 'Personel askıya alındı';
          case 'removed':
            return 'Personel çıkarıldı';
          case 'permissions':
            return 'Personel izinleri güncellendi';
          default:
            return 'Personel aktifleştirildi';
        }
      case BranchActivityEvent.processCreated:
        return 'Süreç oluşturuldu';
      case BranchActivityEvent.processUpdated:
        return 'Süreç güncellendi';
      case BranchActivityEvent.statusChanged:
        switch (note) {
          case 'attention':
            return 'Süreç dikkat durumuna alındı';
          case 'completed':
            return 'Süreç tamamlandı';
          case 'in_progress':
            return 'Süreç devam ediyor';
          default:
            return 'Süreç durumu güncellendi';
        }
    }
  }

  IconData get icon {
    if (isAttention) return Icons.priority_high_rounded;
    if (isCompleted) return Icons.check_circle_outline_rounded;
    return event.isStaffEvent
        ? Icons.group_outlined
        : Icons.pending_actions_outlined;
  }
}

/// Aktivite geçmişi filtresi (Tümü / Personel / Süreç / Dikkat / Tamamlanan).
enum BranchActivityFilter { all, staff, process, attention, completed }

extension BranchActivityFilterMeta on BranchActivityFilter {
  String get label {
    switch (this) {
      case BranchActivityFilter.all:
        return 'Tümü';
      case BranchActivityFilter.staff:
        return 'Personel';
      case BranchActivityFilter.process:
        return 'Süreç';
      case BranchActivityFilter.attention:
        return 'Dikkat';
      case BranchActivityFilter.completed:
        return 'Tamamlanan';
    }
  }

  bool matches(BranchActivityEntry entry) {
    switch (this) {
      case BranchActivityFilter.all:
        return true;
      case BranchActivityFilter.staff:
        return entry.event.isStaffEvent;
      case BranchActivityFilter.process:
        return !entry.event.isStaffEvent;
      case BranchActivityFilter.attention:
        return entry.isAttention;
      case BranchActivityFilter.completed:
        return entry.isCompleted;
    }
  }
}
