import 'calc_safety.dart';

/// Gerçek Maliyet + Kâr sonucu.
class CostProfitResult {
  const CostProfitResult({
    required this.totalCost,
    required this.costPerUnit,
    required this.profitPerUnit,
    required this.profitMarginPct,
    required this.dailyTotalProfit,
  });

  final double totalCost;
  final double costPerUnit;

  /// Adet başı kâr (zarar negatif olabilir).
  final double profitPerUnit;

  /// Satış fiyatına göre kâr oranı %.
  final double profitMarginPct;

  /// Günlük toplam kâr (zarar negatif olabilir).
  final double dailyTotalProfit;
}

/// Üretim maliyeti ve kârı hesaplar (saf Dart).
///
/// Genel gider yüzdesi baz maliyetin üzerine eklenir. Kâr/zarar negatif
/// olabilir (zarar göstergesi). NaN / Infinity / sıfıra bölme üretmez.
class CostProfitCalculator {
  const CostProfitCalculator();

  CostProfitResult calculate({
    required double productionCount,
    required double flourCost,
    required double otherIngredientCost,
    required double packagingCost,
    required double laborCost,
    required double energyCost,
    required double salePrice,
    double otherExpensePct = 0,
  }) {
    final count = nonNeg(productionCount);
    final baseCost =
        nonNeg(flourCost) +
        nonNeg(otherIngredientCost) +
        nonNeg(packagingCost) +
        nonNeg(laborCost) +
        nonNeg(energyCost);
    final overhead = nonNeg(otherExpensePct);
    final price = nonNeg(salePrice);

    final totalCost = baseCost * (1.0 + overhead / 100.0);
    final costPerUnit = safeDiv(totalCost, count);
    final profitPerUnit = price - costPerUnit;
    final marginPct = safeDiv(profitPerUnit, price) * 100.0;
    final dailyProfit = profitPerUnit * count;

    return CostProfitResult(
      totalCost: finiteOrZero(totalCost),
      costPerUnit: finiteOrZero(costPerUnit),
      profitPerUnit: finiteOrZero(profitPerUnit),
      profitMarginPct: finiteOrZero(marginPct),
      dailyTotalProfit: finiteOrZero(dailyProfit),
    );
  }
}
