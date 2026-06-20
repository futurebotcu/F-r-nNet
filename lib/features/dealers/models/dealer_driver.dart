/// Patron/ticari kullanıcının kendi şoförü — bir FırınNet kullanıcısına bağlı
/// yönetim kaydı.
///
/// Supabase tablosu: `dealer_drivers` (Sprint 1 şeması).
/// "Tek defter, çoklu görünüm": şoför bu sprintte yalnız patron tarafından
/// yönetilen bir bağlantıdır; şoför login erişimi/ yazma Sprint 3-4'te gelir.
/// owner_id daima patrondur (repo katmanında set edilir).
class DealerDriver {
  const DealerDriver({
    required this.id,
    required this.driverUserId,
    required this.name,
    this.phone = '',
    this.note = '',
    this.isActive = true,
    required this.createdAt,
    this.assignedDealerCount = 0,
    this.permissionLevel = DriverPermission.half,
  });

  final String id;

  /// Şoförün gerçek FırınNet profile/user ID'si (profiles.id).
  final String driverUserId;

  final String name;
  final String phone;
  final String note;
  final bool isActive;
  final DateTime createdAt;

  /// Bu şoföre atanmış bayi sayısı (liste kartı için; repo doldurur).
  final int assignedDealerCount;

  /// Yarı/Tam yetki (feature/dealer-driver-permission-levels). Tam yetkili
  /// şoför atanmış bayilerde fiyat/silme/düzeltme yapabilir. Varsayılan yarı.
  final DriverPermission permissionLevel;

  bool get isFullPermission => permissionLevel == DriverPermission.full;

  DealerDriver copyWith({
    String? name,
    String? phone,
    String? note,
    bool? isActive,
    int? assignedDealerCount,
    DriverPermission? permissionLevel,
  }) {
    return DealerDriver(
      id: id,
      driverUserId: driverUserId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      assignedDealerCount: assignedDealerCount ?? this.assignedDealerCount,
      permissionLevel: permissionLevel ?? this.permissionLevel,
    );
  }
}

/// Şoför yetki seviyesi. DB `dealer_drivers.permission_level` ('half'/'full').
enum DriverPermission {
  half,
  full;

  String get persistKey => name; // 'half' | 'full'

  static DriverPermission fromKey(String? key) =>
      key == 'full' ? DriverPermission.full : DriverPermission.half;
}
