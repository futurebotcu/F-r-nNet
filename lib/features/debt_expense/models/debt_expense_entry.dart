// FırınNet — Borç & Gider Defteri V1 modeli.
//
// Tek model üç türü kapsar (kind): borç / gider / personel ödemesi.
// remaining ve status UYGULAMADA türetilir (DB'de tutulmaz → drift yok).

enum DebtExpenseKind { debt, expense, staffPayment }

enum DebtExpenseStatus { open, partial, paid, overdue }

enum StaffPaymentType { salary, advance, bonus, mealTransport, other }

extension DebtExpenseKindCode on DebtExpenseKind {
  String get code => switch (this) {
        DebtExpenseKind.debt => 'debt',
        DebtExpenseKind.expense => 'expense',
        DebtExpenseKind.staffPayment => 'staff_payment',
      };

  static DebtExpenseKind fromCode(String? c) => switch (c) {
        'expense' => DebtExpenseKind.expense,
        'staff_payment' => DebtExpenseKind.staffPayment,
        _ => DebtExpenseKind.debt,
      };
}

extension StaffPaymentTypeCode on StaffPaymentType {
  String get code => switch (this) {
        StaffPaymentType.salary => 'salary',
        StaffPaymentType.advance => 'advance',
        StaffPaymentType.bonus => 'bonus',
        StaffPaymentType.mealTransport => 'meal_transport',
        StaffPaymentType.other => 'other',
      };

  static StaffPaymentType? fromCode(String? c) => switch (c) {
        'salary' => StaffPaymentType.salary,
        'advance' => StaffPaymentType.advance,
        'bonus' => StaffPaymentType.bonus,
        'meal_transport' => StaffPaymentType.mealTransport,
        'other' => StaffPaymentType.other,
        _ => null,
      };
}

class DebtExpenseEntry {
  const DebtExpenseEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.category,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.dueDate,
    this.staffPaymentType,
    this.note,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final DebtExpenseKind kind;
  final String title;
  final String? category;
  final double totalAmount;
  final double paidAmount;
  final DateTime? dueDate;
  final StaffPaymentType? staffPaymentType;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kalan tutar (negatife düşmez).
  double get remaining {
    final r = totalAmount - paidAmount;
    return r > 0 ? r : 0;
  }

  bool get isClosed => totalAmount > 0 && paidAmount >= totalAmount;

  /// Durum, verilen güne göre türetilir (gün-bazlı; saat yok).
  DebtExpenseStatus statusOn(DateTime today) {
    if (isClosed) return DebtExpenseStatus.paid;
    final due = dueDate;
    if (due != null) {
      final d = DateTime(due.year, due.month, due.day);
      final t = DateTime(today.year, today.month, today.day);
      if (d.isBefore(t)) return DebtExpenseStatus.overdue;
    }
    return paidAmount > 0 ? DebtExpenseStatus.partial : DebtExpenseStatus.open;
  }

  DebtExpenseEntry copyWith({
    String? title,
    String? category,
    double? totalAmount,
    double? paidAmount,
    DateTime? dueDate,
    bool clearDueDate = false,
    StaffPaymentType? staffPaymentType,
    String? note,
    DateTime? updatedAt,
  }) {
    return DebtExpenseEntry(
      id: id,
      kind: kind,
      title: title ?? this.title,
      category: category ?? this.category,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      staffPaymentType: staffPaymentType ?? this.staffPaymentType,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DebtExpenseEntry.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return DebtExpenseEntry(
      id: row['id'].toString(),
      kind: DebtExpenseKindCode.fromCode(row['kind'] as String?),
      title: (row['title'] as String?) ?? '',
      category: row['category'] as String?,
      totalAmount: ((row['total_amount'] as num?) ?? 0).toDouble(),
      paidAmount: ((row['paid_amount'] as num?) ?? 0).toDouble(),
      dueDate: parseDate(row['due_date']),
      staffPaymentType:
          StaffPaymentTypeCode.fromCode(row['staff_payment_type'] as String?),
      note: row['note'] as String?,
      createdAt: parseDate(row['created_at']) ?? DateTime(2026),
      updatedAt: parseDate(row['updated_at']),
    );
  }

  /// Insert payload (id/owner_id server tarafında). created_at formdaki
  /// tarihten gelir (gider/personel tarihi geriye dönük girilebilsin).
  Map<String, dynamic> toInsert() => <String, dynamic>{
        'kind': kind.code,
        'title': title,
        if (category != null && category!.isNotEmpty) 'category': category,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        if (dueDate != null) 'due_date': _dateOnly(dueDate!),
        if (staffPaymentType != null)
          'staff_payment_type': staffPaymentType!.code,
        if (note != null && note!.isNotEmpty) 'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
