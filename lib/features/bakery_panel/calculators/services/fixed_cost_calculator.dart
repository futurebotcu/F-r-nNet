import 'calc_safety.dart';

/// "Dükkan Boşta Kaça Çalışıyor?" sonucu.
class FixedCostResult {
  const FixedCostResult({
    required this.dailyFixedCost,
    required this.perSackFixedCost,
    required this.perUnitFixedCost,
  });

  /// Aylık sabit giderin çalışma gününe bölünmüş günlük yükü.
  final double dailyFixedCost;

  /// Günlük işlenen çuvala düşen sabit gider.
  final double perSackFixedCost;

  /// Günlük üretilen ürüne düşen sabit gider (ürün adedi 0 ise 0).
  final double perUnitFixedCost;
}

/// Kira, maaş, elektrik gibi sabit giderlerin günlük / çuval / ürün başına
/// yükünü hesaplar (saf Dart).
///
/// NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize edilir.
/// Çalışma günü 0 ise günlük yük 0 döner (sonsuz değil).
class FixedCostCalculator {
  const FixedCostCalculator();

  FixedCostResult calculate({
    required double monthlyFixedTotal,
    required double workDaysPerMonth,
    required double dailySacks,
    double dailyUnits = 0,
  }) {
    final monthly = nonNeg(monthlyFixedTotal);
    final workDays = nonNeg(workDaysPerMonth);
    final sacks = nonNeg(dailySacks);
    final units = nonNeg(dailyUnits);

    final dailyFixed = safeDiv(monthly, workDays);
    final perSack = safeDiv(dailyFixed, sacks);
    final perUnit = safeDiv(dailyFixed, units);

    return FixedCostResult(
      dailyFixedCost: finiteOrZero(dailyFixed),
      perSackFixedCost: finiteOrZero(perSack),
      perUnitFixedCost: finiteOrZero(perUnit),
    );
  }
}
