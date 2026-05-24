/// Bir bayi için verilen `[start, end)` aralığında toplulaştırılmış
/// metrikler.
///
/// `DealerBalanceSummary`'den ayrı tutulur — o all-time toplamlar +
/// sabit periyot (today/week/month) karışımıdır; bu sınıf yalnız bir
/// aralık için hesaplanır.
///
/// Tutar konvansiyonları `DealerBalanceService.summarize` ile aynı:
/// - `totalDelivery`, `totalReturn`, `totalPayment` → gross pozitif toplamlar
/// - `totalAdjustment` → işaretli (negatif olabilir)
/// - `netChange = totalDelivery − totalReturn − totalPayment + totalAdjustment`
class DealerRangeMetrics {
  const DealerRangeMetrics({
    required this.dealerId,
    required this.start,
    required this.end,
    required this.totalDelivery,
    required this.totalReturn,
    required this.totalPayment,
    required this.totalAdjustment,
    required this.netChange,
    required this.txCount,
  });

  final String dealerId;
  final DateTime start;
  final DateTime end;
  final double totalDelivery;
  final double totalReturn;
  final double totalPayment;
  final double totalAdjustment;
  final double netChange;
  final int txCount;

  /// Boş aralık (hiçbir hareket yok) için sıfır metrik.
  factory DealerRangeMetrics.empty({
    required String dealerId,
    required DateTime start,
    required DateTime end,
  }) {
    return DealerRangeMetrics(
      dealerId: dealerId,
      start: start,
      end: end,
      totalDelivery: 0,
      totalReturn: 0,
      totalPayment: 0,
      totalAdjustment: 0,
      netChange: 0,
      txCount: 0,
    );
  }
}
