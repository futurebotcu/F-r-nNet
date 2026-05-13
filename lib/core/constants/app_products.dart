/// Hazır ürün isimleri — chip seçimi için.
class AppProducts {
  const AppProducts._();

  static const List<String> defaults = <String>[
    'Ekmek',
    'Simit',
    'Pide',
    'Poğaça',
    'Açma',
    'Börek',
  ];
}

/// Meslek rozeti seçenekleri.
class RoleBadges {
  const RoleBadges._();

  /// Eski API — backward compat (mevcut UI'lar bunu kullanıyor).
  static const List<String> all = <String>[
    'Usta Fırıncı',
    'Fırın Sahibi',
    'Uncu',
    'Mayacı',
    'Susamcı',
    'Toptancı',
    'Pastacı',
    'Ekipman Satıcısı',
    'Çalışan/Usta',
    'Diğer',
  ];

  /// Ticari rolü için meslek rozeti seçenekleri.
  static const List<String> commercial = <String>[
    'Usta Fırıncı',
    'Fırın Sahibi',
    'İşletmeci',
    'Pastacı',
    'Diğer',
  ];

  /// Bireysel rolü için meslek rozeti seçenekleri.
  static const List<String> individual = <String>[
    'Usta Fırıncı',
    'Mayacı',
    'Hamurcu',
    'Simitçi',
    'Poğaçacı',
    'Pasta Ustası',
    'Çırak',
    'Kalfa',
    'Diğer',
  ];

  /// Toptancı rolü için meslek rozeti seçenekleri.
  static const List<String> wholesaler = <String>[
    'Toptancı',
    'Uncu',
    'Susamcı',
    'Ekipman Satıcısı',
    'Diğer',
  ];
}
