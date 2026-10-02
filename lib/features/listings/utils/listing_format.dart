// İlanlar tasarım geçişi — tek fiyat/ücret/tarih biçimleyici.
//
// Eskiden kart/detay/filtre/iş ilanı her biri kendi `'₺ ${v.toStringAsFixed(0)}'`
// biçimini üretiyordu: binlik ayıracı yoktu ("₺ 850000") ve form EUR/USD
// seçtirse bile her yerde "₺" görünüyordu. Bu dosya tek kaynak:
//   * para birimi kodu → sembol (TRY ₺ · EUR € · USD $; bilinmeyen → ₺)
//   * NumberFormat.decimalPattern('tr') binlik ayıracı ("25.000")
//   * form girişini doğru sayıya çevirme ("25.000" → 25000, "12,5" → 12.5)
//   * güvenli göreli tarih (locale verisi yüklenmemişse çökmez)

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/relative_time.dart';

/// Kayıt sonrası kısa geri bildirim: ödeme bekleyen ilan "yayında" denmez.
String listingSavedMessage({
  required bool isEdit,
  required bool isPendingPayment,
}) {
  if (isPendingPayment) return AppStrings.listingsSavedPendingPayment;
  return isEdit ? AppStrings.listingsUpdated : AppStrings.listingsPublished;
}

class ListingFormat {
  const ListingFormat._();

  static final NumberFormat _grouped = NumberFormat.decimalPattern('tr');
  static final NumberFormat _groupedFraction = NumberFormat('#,##0.##', 'tr');

  /// ISO para birimi kodu → sembol. Bilinmeyen/boş → ₺ (varsayılan TRY).
  static String currencySymbol(String? currencyCode) {
    switch ((currencyCode ?? '').trim().toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return r'$';
      default:
        return '₺';
    }
  }

  /// Binlik ayıraçlı sayı: 25000 → "25.000", 12.5 → "12,5".
  static String amount(num value) {
    if (value == value.roundToDouble()) return _grouped.format(value.round());
    return _groupedFraction.format(value);
  }

  /// "₺ 25.000" / "€ 1.200" / "$ 900".
  static String price(num value, {String? currency}) =>
      '${currencySymbol(currency)} ${amount(value)}';

  /// Ücret aralığı: ikisi de varsa "₺ 25.000 – 30.000", tek değer varsa
  /// "₺ 25.000"; hiçbiri yoksa null (çağıran fallback metni seçer).
  static String? priceRange(num? min, num? max, {String? currency}) {
    final lo = (min != null && min > 0) ? min : null;
    final hi = (max != null && max > 0) ? max : null;
    if (lo == null && hi == null) return null;
    final sym = currencySymbol(currency);
    if (lo != null && hi != null && hi > lo) {
      return '$sym ${amount(lo)} – ${amount(hi)}';
    }
    return '$sym ${amount((hi ?? lo)!)}';
  }

  /// Form girişi → sayı. Nokta binlik ayıracı kabul edilir, virgül ondalık:
  /// "25.000" → 25000, "12,5" → 12.5, "" → null.
  static double? parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll('.', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned.replaceAll(',', '.'));
  }

  /// Form alanına geri yazım (edit hydrate): 25000 → "25000", 12.5 → "12,5".
  static String editText(num? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString().replaceAll('.', ',');
  }

  /// Fiyat alanı: yalnız rakam + tek ondalık virgülü ("25.000" yazılamaz →
  /// yanlış "25" okunması imkânsız).
  static final List<TextInputFormatter> priceInputFormatters =
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
      ];

  /// Ücret / kira / devir alanı: yalnız rakam.
  static final List<TextInputFormatter> integerInputFormatters =
      <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

  /// Göreli tarih ("12 dk önce", "dün", "12 Eyl"). Tarih yerel verisi
  /// yüklenmemiş ortamda (test/erken açılış) sade sayısal tarihe düşer.
  static String relative(DateTime time, {DateTime? now}) {
    try {
      return relativeTimeTr(time, now: now);
    } catch (_) {
      final t = time.toLocal();
      return '${t.day}.${t.month}.${t.year}';
    }
  }

  /// Mutlak kısa tarih ("12 Eyl 2026"); locale yoksa "12.9.2026".
  static String date(DateTime time) {
    final t = time.toLocal();
    try {
      return DateFormat('d MMM y', 'tr_TR').format(t);
    } catch (_) {
      return '${t.day}.${t.month}.${t.year}';
    }
  }
}
