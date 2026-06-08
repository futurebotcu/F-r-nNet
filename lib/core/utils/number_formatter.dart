import 'package:intl/intl.dart';

/// Türkçe ondalıklı sayı / TL biçimleyici.
class NumberFormatter {
  const NumberFormatter._();

  static final NumberFormat _decimal = NumberFormat.decimalPattern('tr_TR');
  static final NumberFormat _decimal2 = NumberFormat('#,##0.##', 'tr_TR');
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static String integer(num value) => _decimal.format(value.round());

  static String decimal(num value) => _decimal2.format(value);

  static String currency(num value) => _currency.format(value);

  /// "60", "60.5", "60,5" → 60.5
  static double parseLoose(String raw) {
    final clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty) return 0;
    return double.tryParse(clean) ?? 0;
  }
}
