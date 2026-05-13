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

/// Bayinin müşteri kategorisi.
///
/// V1.2: ticari kullanıcının bayisi (`bakery_dealer`) ve toptancı kullanıcısının
/// müşterisi (`wholesale_customer`) aynı `dealers` tablosunu paylaşır.
enum DealerCustomerType {
  bakeryDealer,
  wholesaleCustomer,
}

extension DealerCustomerTypeLabel on DealerCustomerType {
  String get label {
    switch (this) {
      case DealerCustomerType.bakeryDealer:
        return 'Bayi';
      case DealerCustomerType.wholesaleCustomer:
        return 'Müşteri';
    }
  }

  String get persistKey {
    switch (this) {
      case DealerCustomerType.bakeryDealer:
        return 'bakery_dealer';
      case DealerCustomerType.wholesaleCustomer:
        return 'wholesale_customer';
    }
  }

  static DealerCustomerType fromPersistKey(String? key) {
    switch (key) {
      case 'wholesale_customer':
        return DealerCustomerType.wholesaleCustomer;
      case 'bakery_dealer':
      default:
        return DealerCustomerType.bakeryDealer;
    }
  }
}

/// Fırının çalıştığı bir bayi (bakkal, market, simit yeri vb.) veya
/// toptancının bir müşterisi. [customerType] hangisi olduğunu söyler.
///
/// Supabase tablosu: `dealers` (V1 + V1.2 sütunları).
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
    this.customerType = DealerCustomerType.bakeryDealer,
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
  final DealerCustomerType customerType;
  final DateTime createdAt;

  Dealer copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? area,
    DealerWorkingType? workingType,
    bool? isActive,
    String? note,
    DealerCustomerType? customerType,
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
      customerType: customerType ?? this.customerType,
      createdAt: createdAt,
    );
  }
}
