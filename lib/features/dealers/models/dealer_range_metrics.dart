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

/// Çok-bayi (toplu) aralık metrikleri (Sprint Raporlar).
///
/// `DealerRangeMetrics`'in **aktif bayiler** üzerinden toplanmış agregat
/// versiyonu. Per-dealer dağılımı ayrıca [perDealerNet] olarak tutar —
/// Raporlar tab "Bayi Bazlı Rapor" listesi tek pass'te dealer adına ek
/// olarak bu periyottaki net değişimi de gösterebilsin diye.
///
/// `activeDealerCount` toplam aktif bayi sayısı (per-dealer metric boş
/// olsa bile dealer sayılır — özet başlığı için).
class DealerAggregateRangeMetrics {
  const DealerAggregateRangeMetrics({
    required this.start,
    required this.end,
    required this.totalDelivery,
    required this.totalReturn,
    required this.totalPayment,
    required this.totalAdjustment,
    required this.netChange,
    required this.txCount,
    required this.activeDealerCount,
    required this.perDealerNet,
    required this.perDealerTxCount,
  });

  final DateTime start;
  final DateTime end;
  final double totalDelivery;
  final double totalReturn;
  final double totalPayment;
  final double totalAdjustment;
  final double netChange;
  final int txCount;
  final int activeDealerCount;

  /// `dealerId -> netChange` map. UI tarafı dealer listesi sıralarken /
  /// chip gösterirken kullanır.
  final Map<String, double> perDealerNet;

  /// `dealerId -> txCount` map (Gün Sonu V1). "Bugün hareketi var mı?"
  /// sorusunu net=0 senaryosunda da doğru cevaplar (delivery + payment
  /// eşitliği netChange'i sıfırlar ama tx vardır).
  final Map<String, int> perDealerTxCount;

  factory DealerAggregateRangeMetrics.empty({
    required DateTime start,
    required DateTime end,
  }) {
    return DealerAggregateRangeMetrics(
      start: start,
      end: end,
      totalDelivery: 0,
      totalReturn: 0,
      totalPayment: 0,
      totalAdjustment: 0,
      netChange: 0,
      txCount: 0,
      activeDealerCount: 0,
      perDealerNet: const {},
      perDealerTxCount: const {},
    );
  }
}
