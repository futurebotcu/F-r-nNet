import 'package:flutter/foundation.dart';

import 'bakery_day_book.dart';
import 'production_entry.dart';
import 'waste_entry.dart';

/// Gün Sonu Defteri satırı — seçili dönemde KAYDI OLAN her gün için bir
/// satır (rapor tablosu). Boş günler satır üretmez.
@immutable
class LedgerDayRow {
  const LedgerDayRow({
    required this.date,
    this.revenue,
    this.production = 0,
    this.waste = 0,
    this.isClosed = false,
  });

  final DateTime date;
  final double? revenue;
  final int production;
  final int waste;
  final bool isClosed;

  /// Fire oranı: fire / üretim. Üretim yoksa null ('—').
  double? get wasteRatio => production > 0 ? waste / production : null;

  /// Deterministik uyarı eşiği: üretim varken fire > %10.
  bool get isHighWaste => (wasteRatio ?? 0) > 0.10;
}

/// Ürün Bazlı Özet satırı — dönemdeki üretim + fire toplamları.
@immutable
class LedgerProductRow {
  const LedgerProductRow({
    required this.product,
    this.production = 0,
    this.waste = 0,
    this.estimatedLoss = 0,
  });

  final String product;
  final int production;
  final int waste;
  final double estimatedLoss;

  double? get wasteRatio => production > 0 ? waste / production : null;
  bool get isHighWaste => (wasteRatio ?? 0) > 0.10;
}

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
    this.dailyRows = const [],
    this.productRows = const [],
    this.noteRows = const [],
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

  /// (gün, not) — yeniden eskiye, en fazla 5 (geriye uyumluluk).
  final List<(DateTime, String)> recentDayNotes;

  /// Gün Sonu Defteri: kaydı olan günler, en yeni tarih üstte.
  final List<LedgerDayRow> dailyRows;

  /// Ürün Bazlı Özet: en yüksek fire üstte, sonra ürün adı.
  final List<LedgerProductRow> productRows;

  /// Son Notlar: (gün, gün notu, ciro/kasa notu) — yeniden eskiye, en fazla 7.
  final List<(DateTime, String, String)> noteRows;

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
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    // ── Ürün bazlı toplamlar ──
    final prodByProduct = <String, int>{};
    for (final p in production) {
      prodByProduct[p.product] = (prodByProduct[p.product] ?? 0) + p.quantity;
    }
    final wasteByProduct = <String, int>{};
    final lossByProduct = <String, double>{};
    var totalWaste = 0;
    var totalLoss = 0.0;
    for (final w in wastes) {
      totalWaste += w.quantity;
      totalLoss += w.estimatedLoss;
      wasteByProduct[w.product] = (wasteByProduct[w.product] ?? 0) + w.quantity;
      lossByProduct[w.product] =
          (lossByProduct[w.product] ?? 0) + w.estimatedLoss;
    }
    final productNames = <String>{
      ...prodByProduct.keys,
      ...wasteByProduct.keys,
    };
    final productRows =
        productNames
            .map(
              (name) => LedgerProductRow(
                product: name,
                production: prodByProduct[name] ?? 0,
                waste: wasteByProduct[name] ?? 0,
                estimatedLoss: lossByProduct[name] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byWaste = b.waste.compareTo(a.waste);
            return byWaste != 0 ? byWaste : a.product.compareTo(b.product);
          });

    // ── Gün bazlı satırlar (kaydı olan günler) ──
    final prodByDay = <DateTime, int>{};
    for (final p in production) {
      final d = dateOnly(p.createdAt);
      prodByDay[d] = (prodByDay[d] ?? 0) + p.quantity;
    }
    final wasteByDay = <DateTime, int>{};
    for (final w in wastes) {
      final d = dateOnly(w.createdAt);
      wasteByDay[d] = (wasteByDay[d] ?? 0) + w.quantity;
    }
    final bookByDay = <DateTime, BakeryDayBook>{
      for (final b in dayBooks) dateOnly(b.businessDate): b,
    };
    final days = <DateTime>{
      ...prodByDay.keys,
      ...wasteByDay.keys,
      ...bookByDay.keys,
    }.toList()..sort((a, b) => b.compareTo(a)); // en yeni üstte
    final dailyRows = [
      for (final d in days)
        LedgerDayRow(
          date: d,
          revenue: bookByDay[d]?.revenueAmount,
          production: prodByDay[d] ?? 0,
          waste: wasteByDay[d] ?? 0,
          isClosed: bookByDay[d]?.isClosed ?? false,
        ),
    ];

    final top = wasteByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final notes =
        dayBooks
            .where((b) => b.dayNote.isNotEmpty || b.cashNote.isNotEmpty)
            .toList(growable: true)
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
        for (final b in notes.where((b) => b.dayNote.isNotEmpty).take(5))
          (b.businessDate, b.dayNote),
      ],
      dailyRows: dailyRows,
      productRows: productRows,
      noteRows: [
        for (final b in notes.take(7)) (b.businessDate, b.dayNote, b.cashNote),
      ],
    );
  }
}
