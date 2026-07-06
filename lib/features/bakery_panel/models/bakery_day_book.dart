import 'package:flutter/foundation.dart';

/// Fırın Defteri — gün başına ciro / gün notu / kasa notu / kapanış durumu
/// (bakery_day_books satırı). Yazma yalnız RPC üzerinden yapılır.
///
/// Ciro bir GÜNLÜK NOTTUR — muhasebe/fatura/tahsilat kaydı değildir;
/// gider ve bayi finansı kendi modüllerinde kalır.
@immutable
class BakeryDayBook {
  const BakeryDayBook({
    required this.id,
    required this.businessDate,
    this.revenueAmount,
    this.cashNote = '',
    this.dayNote = '',
    this.isClosed = false,
    this.closedAt,
  });

  final String id;
  final DateTime businessDate;
  final double? revenueAmount;
  final String cashNote;
  final String dayNote;
  final bool isClosed;
  final DateTime? closedAt;

  factory BakeryDayBook.fromRow(Map<String, dynamic> row) => BakeryDayBook(
    id: row['id'] as String,
    businessDate: DateTime.parse(row['business_date'] as String),
    revenueAmount: (row['revenue_amount'] as num?)?.toDouble(),
    cashNote: (row['cash_note'] as String?) ?? '',
    dayNote: (row['day_note'] as String?) ?? '',
    isClosed: row['status'] == 'closed',
    closedAt: row['closed_at'] == null
        ? null
        : DateTime.tryParse(row['closed_at'] as String),
  );
}
