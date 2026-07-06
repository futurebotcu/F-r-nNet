import 'package:flutter/foundation.dart';

import 'bakery_day_book.dart';
import 'production_entry.dart';
import 'waste_entry.dart';

/// Fırın Defteri basit dönem raporu (Bugün / Dün / 7 Gün / 30 Gün).
///
/// Ham kayıtlardan saf fonksiyonla türetilir ([build]) — Supabase ve Local
/// repo aynı hesabı paylaşır, unit test doğrudan bunu sınar.
/// PDF/Excel/grafik YOK (V2).
@immutable
class LedgerRangeReport {
  const LedgerRangeReport({
    required this.from,
    required this.to,
    this.totalProduction = 0,
    this.totalWaste = 0,
    this.totalEstimatedLoss = 0,
    this.totalRevenue = 0,
    this.closedDays = 0,
    this.topWasteProducts = const [],
    this.recentDayNotes = const [],
  });

  final DateTime from;
  final DateTime to;
  final int totalProduction;
  final int totalWaste;
  final double totalEstimatedLoss;
  final double totalRevenue;
  final int closedDays;

  /// (ürün adı, toplam fire adedi) — çoktan aza, en fazla 5.
  final List<(String, int)> topWasteProducts;

  /// (gün, not) — yeniden eskiye, en fazla 5.
  final List<(DateTime, String)> recentDayNotes;

  /// Dönem fire oranı: fire / üretim. Üretim yoksa null ('—' gösterilir).
  double? get wasteRatio =>
      totalProduction > 0 ? totalWaste / totalProduction : null;

  static LedgerRangeReport build({
    required DateTime from,
    required DateTime to,
    required List<ProductionEntry> production,
    required List<WasteEntry> wastes,
    required List<BakeryDayBook> dayBooks,
  }) {
    final wasteByProduct = <String, int>{};
    var totalWaste = 0;
    var totalLoss = 0.0;
    for (final w in wastes) {
      totalWaste += w.quantity;
      totalLoss += w.estimatedLoss;
      wasteByProduct[w.product] = (wasteByProduct[w.product] ?? 0) + w.quantity;
    }
    final top = wasteByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final notes =
        dayBooks.where((b) => b.dayNote.isNotEmpty).toList(growable: true)
          ..sort((a, b) => b.businessDate.compareTo(a.businessDate));
    return LedgerRangeReport(
      from: from,
      to: to,
      totalProduction: production.fold(0, (sum, e) => sum + e.quantity),
      totalWaste: totalWaste,
      totalEstimatedLoss: totalLoss,
      totalRevenue: dayBooks.fold(
        0.0,
        (sum, b) => sum + (b.revenueAmount ?? 0),
      ),
      closedDays: dayBooks.where((b) => b.isClosed).length,
      topWasteProducts: [for (final e in top.take(5)) (e.key, e.value)],
      recentDayNotes: [
        for (final b in notes.take(5)) (b.businessDate, b.dayNote),
      ],
    );
  }
}
