import 'package:flutter/material.dart';

/// Şube Yönetimi V1 — saf veri modelleri + kontrollü taksonomiler.
///
/// persistKey değerleri DB CHECK constraint'leriyle birebir aynıdır
/// (20260705120000_branch_management_v1.sql); yeni değer eklemek migration
/// gerektirir. Etiketler fırıncı/patron dilinde tek noktada burada tutulur.

/// Şube personel rolü (branch_memberships.role / branch_invites.role).
enum BranchRole {
  branchManager,
  counter,
  production,
  cashier,
  shipping,
  accountingAssistant,
}

extension BranchRoleMeta on BranchRole {
  String get persistKey {
    switch (this) {
      case BranchRole.branchManager:
        return 'branch_manager';
      case BranchRole.counter:
        return 'counter';
      case BranchRole.production:
        return 'production';
      case BranchRole.cashier:
        return 'cashier';
      case BranchRole.shipping:
        return 'shipping';
      case BranchRole.accountingAssistant:
        return 'accounting_assistant';
    }
  }

  String get label {
    switch (this) {
      case BranchRole.branchManager:
        return 'Şube Sorumlusu';
      case BranchRole.counter:
        return 'Tezgah Personeli';
      case BranchRole.production:
        return 'Üretim Personeli';
      case BranchRole.cashier:
        return 'Kasa / Satış';
      case BranchRole.shipping:
        return 'Sevkiyat';
      case BranchRole.accountingAssistant:
        return 'Muhasebe / Cari Yardımcısı';
    }
  }

  /// Şube sorumlusu izin listesinden bağımsız TÜM süreç tiplerine yetkilidir
  /// (server-side kuralla birebir).
  bool get hasAllProcessPermissions => this == BranchRole.branchManager;

  static BranchRole fromKey(String key) => BranchRole.values.firstWhere(
    (r) => r.persistKey == key,
    orElse: () => BranchRole.counter,
  );
}

/// Şube süreç tipi (branch_processes.type).
enum BranchProcessType {
  openingCheck,
  productionNote,
  shipmentPrep,
  dealerCollection,
  accountNote,
  generalNote,
}

extension BranchProcessTypeMeta on BranchProcessType {
  String get persistKey {
    switch (this) {
      case BranchProcessType.openingCheck:
        return 'opening_check';
      case BranchProcessType.productionNote:
        return 'production_note';
      case BranchProcessType.shipmentPrep:
        return 'shipment_prep';
      case BranchProcessType.dealerCollection:
        return 'dealer_collection';
      case BranchProcessType.accountNote:
        return 'account_note';
      case BranchProcessType.generalNote:
        return 'general_note';
    }
  }

  String get label {
    switch (this) {
      case BranchProcessType.openingCheck:
        return 'Günlük Açılış Kontrolü';
      case BranchProcessType.productionNote:
        return 'Üretim Notu';
      case BranchProcessType.shipmentPrep:
        return 'Sevkiyat Hazırlığı';
      case BranchProcessType.dealerCollection:
        return 'Bayi Tahsilat Takibi';
      case BranchProcessType.accountNote:
        return 'Cari Not';
      case BranchProcessType.generalNote:
        return 'Genel Şube Notu';
    }
  }

  IconData get icon {
    switch (this) {
      case BranchProcessType.openingCheck:
        return Icons.checklist_rounded;
      case BranchProcessType.productionNote:
        return Icons.bakery_dining_outlined;
      case BranchProcessType.shipmentPrep:
        return Icons.local_shipping_outlined;
      case BranchProcessType.dealerCollection:
        return Icons.payments_outlined;
      case BranchProcessType.accountNote:
        return Icons.receipt_long_outlined;
      case BranchProcessType.generalNote:
        return Icons.sticky_note_2_outlined;
    }
  }

  /// V2 şablon açıklaması — "Şablondan süreç oluştur" kartlarında görünür.
  String get templateDescription {
    switch (this) {
      case BranchProcessType.openingCheck:
        return 'Şubenin güne hazır olup olmadığını kontrol et.';
      case BranchProcessType.productionNote:
        return 'Üretimle ilgili eksik, fire veya plan notu ekle.';
      case BranchProcessType.shipmentPrep:
        return 'Bayi/teslimat hazırlığını takip et.';
      case BranchProcessType.dealerCollection:
        return 'Bayi tahsilat veya iade durumunu not al.';
      case BranchProcessType.accountNote:
        return 'Şubeye bağlı cari/ödeme notu ekle.';
      case BranchProcessType.generalNote:
        return 'Şubeyle ilgili genel not veya görev oluştur.';
    }
  }

  static BranchProcessType fromKey(String key) =>
      BranchProcessType.values.firstWhere(
        (t) => t.persistKey == key,
        orElse: () => BranchProcessType.generalNote,
      );
}

/// Süreç durumu (branch_processes.status).
enum BranchProcessStatus { pending, inProgress, completed, attention }

extension BranchProcessStatusMeta on BranchProcessStatus {
  String get persistKey {
    switch (this) {
      case BranchProcessStatus.pending:
        return 'pending';
      case BranchProcessStatus.inProgress:
        return 'in_progress';
      case BranchProcessStatus.completed:
        return 'completed';
      case BranchProcessStatus.attention:
        return 'attention';
    }
  }

  String get label {
    switch (this) {
      case BranchProcessStatus.pending:
        return 'Beklemede';
      case BranchProcessStatus.inProgress:
        return 'Devam Ediyor';
      case BranchProcessStatus.completed:
        return 'Tamamlandı';
      case BranchProcessStatus.attention:
        return 'Dikkat';
    }
  }

  /// Açık süreç = tamamlanmamış süreç (KPI/durum rozetleri bunu sayar).
  bool get isOpen => this != BranchProcessStatus.completed;

  static BranchProcessStatus fromKey(String key) =>
      BranchProcessStatus.values.firstWhere(
        (s) => s.persistKey == key,
        orElse: () => BranchProcessStatus.pending,
      );
}

/// Üyelik durumu (branch_memberships.status).
enum BranchMembershipStatus { active, suspended, removed }

extension BranchMembershipStatusMeta on BranchMembershipStatus {
  String get persistKey {
    switch (this) {
      case BranchMembershipStatus.active:
        return 'active';
      case BranchMembershipStatus.suspended:
        return 'suspended';
      case BranchMembershipStatus.removed:
        return 'removed';
    }
  }

  String get label {
    switch (this) {
      case BranchMembershipStatus.active:
        return 'Aktif';
      case BranchMembershipStatus.suspended:
        return 'Askıda';
      case BranchMembershipStatus.removed:
        return 'Çıkarıldı';
    }
  }

  static BranchMembershipStatus fromKey(String key) =>
      BranchMembershipStatus.values.firstWhere(
        (s) => s.persistKey == key,
        orElse: () => BranchMembershipStatus.removed,
      );
}

/// Şube (branches satırı) + liste görünümü için türetilmiş sayaçlar.
@immutable
class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
    this.isMainBranch = false,
    this.memberCount = 0,
    this.openProcessCount = 0,
    this.attentionCount = 0,
    this.managerName,
  });

  final String id;
  final String name;
  final String address;
  final String phone;

  /// branches.status == 'active'. "Dikkat" ayrı SAKLANMAZ; açık attention
  /// süreçten türetilir ([hasAttention]).
  final bool isActive;
  final bool isMainBranch;

  // Liste kartı sayaçları (repo doldurur).
  final int memberCount;
  final int openProcessCount;
  final int attentionCount;
  final String? managerName;

  bool get hasAttention => attentionCount > 0;
}

/// Şube personel üyeliği (owner ve bireysel taraf ortak görünümü).
@immutable
class BranchMembership {
  const BranchMembership({
    required this.id,
    required this.branchId,
    required this.userId,
    required this.role,
    required this.status,
    this.permissions = const <BranchProcessType>[],
    this.memberName = '',
    this.branchName = '',
  });

  final String id;
  final String branchId;
  final String userId;
  final BranchRole role;
  final BranchMembershipStatus status;
  final List<BranchProcessType> permissions;
  final String memberName;
  final String branchName;

  /// Bu üyelik verilen süreç tipinde yazabilir mi (server kuralının client
  /// yansıması — asıl karar RPC'de).
  bool canWrite(BranchProcessType type) =>
      status == BranchMembershipStatus.active &&
      (role.hasAllProcessPermissions || permissions.contains(type));
}

/// Bekleyen/yanıtlanmış şube daveti.
@immutable
class BranchInvite {
  const BranchInvite({
    required this.id,
    required this.branchId,
    required this.role,
    this.branchName = '',
    this.ownerName = '',
    this.invitedName = '',
    this.permissions = const <BranchProcessType>[],
    this.createdAt,
  });

  final String id;
  final String branchId;
  final BranchRole role;
  final String branchName;
  final String ownerName;
  final String invitedName;
  final List<BranchProcessType> permissions;
  final DateTime? createdAt;
}

/// Şube süreci/görevi.
@immutable
class BranchProcess {
  const BranchProcess({
    required this.id,
    required this.branchId,
    required this.type,
    required this.title,
    this.note = '',
    this.status = BranchProcessStatus.pending,
    this.createdByName = '',
    this.createdAt,
    this.dueAt,
    this.completedAt,
  });

  final String id;
  final String branchId;
  final BranchProcessType type;
  final String title;
  final String note;
  final BranchProcessStatus status;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? dueAt;
  final DateTime? completedAt;
}

/// Ticari ana ekran "Bugün Öne Çıkanlar" KPI özeti.
@immutable
class BranchOverview {
  const BranchOverview({
    this.totalBranches = 0,
    this.activeMembers = 0,
    this.openProcesses = 0,
    this.pendingInvites = 0,
    this.attentionProcesses = 0,
    this.completedToday = 0,
  });

  final int totalBranches;
  final int activeMembers;
  final int openProcesses;
  final int pendingInvites;

  // V2: operasyon özeti genişletmesi.
  final int attentionProcesses;
  final int completedToday;
}
