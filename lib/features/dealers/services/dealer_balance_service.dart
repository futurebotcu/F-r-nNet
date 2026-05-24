import '../models/dealer_balance_summary.dart';
import '../models/dealer_range_metrics.dart';
import '../models/dealer_transaction.dart';

/// Bayi cari bakiyesini transactions üzerinden hesaplar.
/// Saf, dependency-free — UI ve repository'den bağımsız.
class DealerBalanceService {
  const DealerBalanceService();

  DealerBalanceSummary summarize({
    required String dealerId,
    required List<DealerTransaction> transactions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(ref.year, ref.month, 1);

    double totalDelivery = 0;
    double totalReturn = 0;
    double totalPayment = 0;
    double totalAdjustment = 0;

    double todayDebt = 0;
    double weekDebt = 0;
    double monthDebt = 0;

    DateTime? lastPayment;
    DateTime? lastTransactionAt;

    for (final t in transactions) {
      if (t.dealerId != dealerId) continue;

      // İmzalı katkı: bakiyeye kattığı net etki.
      // delivery: +, return/payment: −, adjustment: amount işareti olduğu gibi
      double signed;
      switch (t.type) {
        case DealerTransactionType.delivery:
          totalDelivery += t.amount;
          signed = t.amount;
          break;
        case DealerTransactionType.returned:
          totalReturn += t.amount;
          signed = -t.amount;
          break;
        case DealerTransactionType.payment:
          totalPayment += t.amount;
          signed = -t.amount;
          if (lastPayment == null || t.createdAt.isAfter(lastPayment)) {
            lastPayment = t.createdAt;
          }
          break;
        case DealerTransactionType.adjustment:
          totalAdjustment += t.amount;
          signed = t.amount;
          break;
      }

      if (!t.createdAt.isBefore(today)) todayDebt += signed;
      if (!t.createdAt.isBefore(weekStart)) weekDebt += signed;
      if (!t.createdAt.isBefore(monthStart)) monthDebt += signed;

      if (lastTransactionAt == null ||
          t.createdAt.isAfter(lastTransactionAt)) {
        lastTransactionAt = t.createdAt;
      }
    }

    final currentBalance =
        totalDelivery - totalReturn - totalPayment + totalAdjustment;

    return DealerBalanceSummary(
      dealerId: dealerId,
      totalDelivery: totalDelivery,
      totalReturn: totalReturn,
      totalPayment: totalPayment,
      totalAdjustment: totalAdjustment,
      currentBalance: currentBalance,
      todayDebt: todayDebt,
      weekDebt: weekDebt,
      monthDebt: monthDebt,
      lastPayment: lastPayment,
      lastTransactionAt: lastTransactionAt,
    );
  }

  /// Verilen `[start, end)` aralığında bayinin gross toplamlarını ve net
  /// değişimini hesaplar. `summarize` ile aynı imzalı katkı konvansiyonunu
  /// kullanır; range dışındaki ve farklı dealer'a ait hareketler atlanır.
  ///
  /// Concept inspired by evan361425/flutter-pos-system Seller.getMetrics
  /// (Apache-2.0); written from scratch for FırınNet, no code copied.
  DealerRangeMetrics summarizeRange({
    required String dealerId,
    required List<DealerTransaction> transactions,
    required DateTime start,
    required DateTime end,
  }) {
    double totalDelivery = 0;
    double totalReturn = 0;
    double totalPayment = 0;
    double totalAdjustment = 0;
    double netChange = 0;
    int txCount = 0;

    for (final t in transactions) {
      if (t.dealerId != dealerId) continue;
      // [start, end) — start dahil, end hariç.
      if (t.createdAt.isBefore(start)) continue;
      if (!t.createdAt.isBefore(end)) continue;

      switch (t.type) {
        case DealerTransactionType.delivery:
          totalDelivery += t.amount;
          netChange += t.amount;
          break;
        case DealerTransactionType.returned:
          totalReturn += t.amount;
          netChange -= t.amount;
          break;
        case DealerTransactionType.payment:
          totalPayment += t.amount;
          netChange -= t.amount;
          break;
        case DealerTransactionType.adjustment:
          totalAdjustment += t.amount;
          netChange += t.amount;
          break;
      }
      txCount++;
    }

    return DealerRangeMetrics(
      dealerId: dealerId,
      start: start,
      end: end,
      totalDelivery: totalDelivery,
      totalReturn: totalReturn,
      totalPayment: totalPayment,
      totalAdjustment: totalAdjustment,
      netChange: netChange,
      txCount: txCount,
    );
  }
}
