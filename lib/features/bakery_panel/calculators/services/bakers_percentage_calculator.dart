import 'calc_safety.dart';

/// Fırıncı Yüzdesi sonucu — un baz alınarak hesaplanan malzeme miktarları.
class BakersPercentageResult {
  const BakersPercentageResult({
    required this.waterKg,
    required this.yeastKg,
    required this.saltKg,
    required this.otherKg,
    required this.totalDoughKg,
  });

  final double waterKg;
  final double yeastKg;
  final double saltKg;
  final double otherKg;
  final double totalDoughKg;
}

/// Fırıncı yüzdesi: un = %100 kabulü, her malzeme = un × yüzde / 100 (saf Dart).
///
/// NaN / Infinity / sıfıra bölme üretmez; negatif girişler 0'a normalize edilir.
class BakersPercentageCalculator {
  const BakersPercentageCalculator();

  BakersPercentageResult calculate({
    required double flourKg,
    required double waterPct,
    required double yeastPct,
    required double saltPct,
    double otherPct = 0,
  }) {
    final flour = nonNeg(flourKg);
    final water = flour * nonNeg(waterPct) / 100.0;
    final yeast = flour * nonNeg(yeastPct) / 100.0;
    final salt = flour * nonNeg(saltPct) / 100.0;
    final other = flour * nonNeg(otherPct) / 100.0;

    return BakersPercentageResult(
      waterKg: finiteOrZero(water),
      yeastKg: finiteOrZero(yeast),
      saltKg: finiteOrZero(salt),
      otherKg: finiteOrZero(other),
      totalDoughKg: finiteOrZero(flour + water + yeast + salt + other),
    );
  }
}
