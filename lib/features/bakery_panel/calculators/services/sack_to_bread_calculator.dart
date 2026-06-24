import 'calc_safety.dart';

/// "Çuvaldan Kaç Ekmek Çıkar?" sonucu.
class SackToBreadResult {
  const SackToBreadResult({
    required this.totalFlourKg,
    required this.estimatedDoughKg,
    required this.netDoughKg,
    required this.estimatedPieces,
  });

  /// Çuval sayısı × çuval kg.
  final double totalFlourKg;

  /// Un + su (su kaldırma oranı uygulanmış) tahmini hamur.
  final double estimatedDoughKg;

  /// Fire sonrası net hamur.
  final double netDoughKg;

  /// Net hamurdan çıkan tahmini ekmek adedi.
  final int estimatedPieces;
}

/// Çuval sayısından tahmini ekmek adedi hesaplar (saf Dart).
///
/// su kaldırma oranı = unun yüzde kaçı kadar su tuttuğu (hamur = un + su).
/// NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize edilir.
class SackToBreadCalculator {
  const SackToBreadCalculator({this.defaultSackKg = 50.0});

  /// Çuval kg varsayılanı.
  final double defaultSackKg;

  SackToBreadResult calculate({
    required double sackCount,
    required double breadDoughG,
    double sackKg = 50.0,
    double waterAbsorptionPct = 60,
    double wastePct = 0,
  }) {
    final sacks = nonNeg(sackCount);
    final perSack = atLeast(nonNeg(sackKg), 0);
    final absorption = nonNeg(waterAbsorptionPct);
    final waste = nonNeg(wastePct).clamp(0, 100).toDouble();
    final pieceG = atLeast(nonNeg(breadDoughG), 1);

    final totalFlourKg = sacks * perSack;
    final estimatedDoughKg = totalFlourKg * (1.0 + absorption / 100.0);
    final netDoughKg = estimatedDoughKg * (1.0 - waste / 100.0);

    final pieces = safeDiv(nonNeg(netDoughKg) * 1000.0, pieceG).floor();

    return SackToBreadResult(
      totalFlourKg: finiteOrZero(totalFlourKg),
      estimatedDoughKg: finiteOrZero(estimatedDoughKg),
      netDoughKg: finiteOrZero(nonNeg(netDoughKg)),
      estimatedPieces: pieces < 0 ? 0 : pieces,
    );
  }
}
