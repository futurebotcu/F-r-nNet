// Borç & Gider Defteri — kategori presetleri. ProductChoiceChips ile
// kullanılır; "Diğer" chip'i + manuel giriş otomatik eklenir.

import '../models/debt_expense_entry.dart';

class DebtExpenseCategories {
  const DebtExpenseCategories._();

  /// Tedarik (fırın hammadde/sarf).
  static const List<String> supply = <String>[
    'Un',
    'Maya',
    'Yağ',
    'Tuz',
    'Şeker',
    'Susam',
    'Çörek otu',
    'Ambalaj',
    'Katkı maddesi',
  ];

  /// İşletme giderleri.
  static const List<String> operating = <String>[
    'Kira',
    'Elektrik',
    'Su',
    'Doğalgaz',
    'İnternet / telefon',
    'Temizlik',
    'Tamir / bakım',
    'Nakliye',
  ];

  /// Finansal (borç tarafında sık).
  static const List<String> financial = <String>[
    'Ekipman taksiti',
    'Kredi',
    'Senet',
    'Vergi / muhasebe',
  ];

  /// Borç formu kategorileri: tedarik + finansal.
  static const List<String> debt = <String>[...supply, ...financial];

  /// Gider formu kategorileri: tedarik + işletme.
  static const List<String> expense = <String>[...supply, ...operating];

  /// Verilen tür için kategori listesi.
  static List<String> forKind(DebtExpenseKind kind) =>
      kind == DebtExpenseKind.debt ? debt : expense;
}

/// Personel ödeme tipi label'ları.
class StaffPaymentLabels {
  const StaffPaymentLabels._();

  static const Map<StaffPaymentType, String> labels = {
    StaffPaymentType.salary: 'Maaş',
    StaffPaymentType.advance: 'Avans',
    StaffPaymentType.bonus: 'Prim',
    StaffPaymentType.mealTransport: 'Yemek / yol',
    StaffPaymentType.other: 'Diğer',
  };

  static String of(StaffPaymentType t) => labels[t] ?? 'Diğer';
}
