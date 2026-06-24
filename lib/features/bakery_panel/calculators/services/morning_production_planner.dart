import 'calc_safety.dart';

/// Sabah Üretim Planlayıcı sonucu.
class MorningPlanResult {
  const MorningPlanResult({
    required this.flourKg,
    required this.sacks,
    required this.waterKg,
    required this.yeastKg,
    required this.saltKg,
    required this.totalDoughKg,
    required this.expectedPiecesAfterWaste,
    required this.capacityExceeded,
  });

  final double flourKg;
  final double sacks;
  final double waterKg;
  final double yeastKg;
  final double saltKg;
  final double totalDoughKg;
  final int expectedPiecesAfterWaste;
  final bool capacityExceeded;
}

/// Adetten malzeme planı çıkarır (saf Dart).
///
/// Varsayılan oranlar (briefte tanımlı, ileride değiştirilebilir):
///   un  = toplam hedef hamur × [flourCoef]
///   su  = un × [waterCoef]
///   maya= un × [yeastCoef]
///   tuz = un × [saltCoef]
class MorningProductionPlanner {
  const MorningProductionPlanner({
    this.flourCoef = 0.62,
    this.waterCoef = 0.62,
    this.yeastCoef = 0.023,
    this.saltCoef = 0.018,
    this.sackKg = 50.0,
  });

  final double flourCoef;
  final double waterCoef;
  final double yeastCoef;
  final double saltCoef;
  final double sackKg;

  /// [count] adet × [pieceWeightG] gr hedef için malzeme planı.
  /// [wastePct] fire oranı; [mixerCapacityKg] > 0 verilirse kapasite uyarısı.
  MorningPlanResult plan({
    required double count,
    required double pieceWeightG,
    double wastePct = 0,
    double mixerCapacityKg = 0,
  }) {
    final pieces = nonNeg(count);
    final pieceG = nonNeg(pieceWeightG);
    final waste = nonNeg(wastePct).clamp(0, 100).toDouble();
    final capacity = nonNeg(mixerCapacityKg);

    final totalDoughKg = pieces * pieceG / 1000.0;
    final flourKg = totalDoughKg * flourCoef;
    final waterKg = flourKg * waterCoef;
    final yeastKg = flourKg * yeastCoef;
    final saltKg = flourKg * saltCoef;
    final sacks = safeDiv(flourKg, sackKg);

    final netDoughKg = totalDoughKg * (1.0 - waste / 100.0);
    final expectedPieces = safeDiv(
      nonNeg(netDoughKg) * 1000.0,
      atLeast(pieceG, 1),
    ).floor();

    return MorningPlanResult(
      flourKg: flourKg,
      sacks: sacks,
      waterKg: waterKg,
      yeastKg: yeastKg,
      saltKg: saltKg,
      totalDoughKg: totalDoughKg,
      expectedPiecesAfterWaste: expectedPieces < 0 ? 0 : expectedPieces,
      capacityExceeded: capacity > 0 && totalDoughKg > capacity,
    );
  }
}
