/// Bir bayi için toplulaştırılmış cari hesap özeti.
/// Service tarafında transactions üzerinden hesaplanır.
///
/// `currentBalance > 0` → bayi fırına borçlu.
/// `currentBalance < 0` → fırın bayiye borçlu (fazla ödeme / fazla iade).
class DealerBalanceSummary {
  const DealerBalanceSummary({
    required this.dealerId,
    required this.totalDelivery,
    required this.totalReturn,
    required this.totalPayment,
    required this.totalAdjustment,
    required this.currentBalance,
    required this.todayDebt,
    required this.weekDebt,
    required this.monthDebt,
    this.lastPayment,
    this.lastTransactionAt,
  });

  final String dealerId;
  final double totalDelivery;
  final double totalReturn;
  final double totalPayment;
  final double totalAdjustment;

  /// teslimat − iade − ödeme + düzeltme
  final double currentBalance;

  /// Gün/hafta/ay içinde net olarak biriken borç (teslimat − iade − ödeme).
  final double todayDebt;
  final double weekDebt;
  final double monthDebt;

  final DateTime? lastPayment;
  final DateTime? lastTransactionAt;

  /// Boş bayi (henüz hareket yok) için sıfır özet.
  static DealerBalanceSummary empty(String dealerId) => DealerBalanceSummary(
        dealerId: dealerId,
        totalDelivery: 0,
        totalReturn: 0,
        totalPayment: 0,
        totalAdjustment: 0,
        currentBalance: 0,
        todayDebt: 0,
        weekDebt: 0,
        monthDebt: 0,
      );
}
