/// Bayi Defteri "Nabız" anlık görüntüsü (Sprint 3.5).
///
/// Bugünün delivery / payment / netChange değerleri ile son 20 non-empty
/// gün'ün EMA baseline'ı karşılaştırılır. UI tarafı (DealerPulseCard)
/// `today X vs baseline Y` farkını arrow + delta% ile gösterir.
///
/// `baselineDays < kMinBaselineDays` (3) olduğunda baseline değerleri
/// güvenilir değildir; UI placeholder ("Pulse hesabı için en az 3
/// günlük geçmiş gerek") gösterir.
class DealerPulseSnapshot {
  const DealerPulseSnapshot({
    required this.todayDelivery,
    required this.todayPayment,
    required this.todayNetChange,
    required this.baselineDelivery,
    required this.baselinePayment,
    required this.baselineNetChange,
    required this.baselineDays,
  });

  /// Bugünün gross teslimat toplamı.
  final double todayDelivery;

  /// Bugünün gross tahsilat toplamı.
  final double todayPayment;

  /// Bugünün net değişimi (delivery − return − payment + adjustment).
  final double todayNetChange;

  /// Son 20 non-empty gün'ün günlük teslimat EMA'sı.
  final double baselineDelivery;

  /// Son 20 non-empty gün'ün günlük tahsilat EMA'sı.
  final double baselinePayment;

  /// Son 20 non-empty gün'ün günlük netChange EMA'sı.
  final double baselineNetChange;

  /// Baseline hesabına katılan non-empty gün sayısı (≤ 20).
  /// 3'ten az ise UI insufficient-data placeholder gösterir.
  final int baselineDays;

  /// Pulse hesabı için yeterli geçmiş veri var mı.
  bool get hasSufficientBaseline => baselineDays >= kMinBaselineDays;

  /// Boş snapshot — hiç tx yokken veya hesap edilemediğinde.
  factory DealerPulseSnapshot.empty() => const DealerPulseSnapshot(
        todayDelivery: 0,
        todayPayment: 0,
        todayNetChange: 0,
        baselineDelivery: 0,
        baselinePayment: 0,
        baselineNetChange: 0,
        baselineDays: 0,
      );

  /// Minimum güvenilir baseline gün sayısı. Donor pattern ile aynı
  /// felsefe: çok az gün varsa EMA gürültülü olur.
  static const int kMinBaselineDays = 3;
}
