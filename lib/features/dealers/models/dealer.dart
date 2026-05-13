/// Bayinin fırınla çalışma şekli.
enum DealerWorkingType {
  cash,   // peşin
  term,   // vadeli
  mixed,  // karma
}

extension DealerWorkingTypeLabel on DealerWorkingType {
  String get label {
    switch (this) {
      case DealerWorkingType.cash:
        return 'Peşin';
      case DealerWorkingType.term:
        return 'Vadeli';
      case DealerWorkingType.mixed:
        return 'Karma';
    }
  }

  String get persistKey {
    switch (this) {
      case DealerWorkingType.cash:
        return 'cash';
      case DealerWorkingType.term:
        return 'term';
      case DealerWorkingType.mixed:
        return 'mixed';
    }
  }

  static DealerWorkingType fromPersistKey(String key) {
    switch (key) {
      case 'cash':
        return DealerWorkingType.cash;
      case 'term':
        return DealerWorkingType.term;
      default:
        return DealerWorkingType.mixed;
    }
  }
}

/// Fırının çalıştığı bir bayi (bakkal, market, simit yeri vb.).
///
/// V1: in-memory. Şema Supabase'e olduğu gibi taşınabilir:
/// dealers(id, name, contact_name, phone, area, working_type, is_active, note, created_at)
class Dealer {
  const Dealer({
    required this.id,
    required this.name,
    this.contactName = '',
    this.phone = '',
    this.area = '',
    this.workingType = DealerWorkingType.mixed,
    this.isActive = true,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String contactName;
  final String phone;
  final String area;
  final DealerWorkingType workingType;
  final bool isActive;
  final String note;
  final DateTime createdAt;

  Dealer copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? area,
    DealerWorkingType? workingType,
    bool? isActive,
    String? note,
  }) {
    return Dealer(
      id: id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      area: area ?? this.area,
      workingType: workingType ?? this.workingType,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}
