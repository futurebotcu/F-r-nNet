import 'calc_safety.dart';

/// Bir bayinin kârlılık yorumu.
///
/// Öncelik: zarar → iade oranı yüksek → sınırda → kârlı.
enum DealerProfitVerdict { lossy, highReturns, marginal, profitable }

/// "Bayi Kârlılık Ölçeği" sonucu.
class DealerProfitResult {
  const DealerProfitResult({
    required this.dailyRevenue,
    required this.returnLoss,
    required this.netProfit,
    required this.profitMarginPct,
    required this.returnRatePct,
    required this.verdict,
  });

  /// Satılan adetten gelen günlük ciro (iadeler ciro getirmez).
  final double dailyRevenue;

  /// İade/bayat adetin maliyet bazlı zararı.
  final double returnLoss;

  /// Dağıtım sonrası tahmini günlük net kâr (zarar negatif olabilir).
  final double netProfit;

  /// Ciroya göre kâr oranı %.
  final double profitMarginPct;

  /// İade oranı % (iade / verilen adet).
  final double returnRatePct;

  final DealerProfitVerdict verdict;
}

/// Bir bayiye verilen üründen, iade ve dağıtım maliyeti sonrası gerçek
/// günlük kârı hesaplar (saf Dart).
///
/// Üretilen tüm adetin maliyeti yüklenilir; ciro yalnız satılan adetten
/// gelir. NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize
/// edilir.
class DealerProfitCalculator {
  const DealerProfitCalculator({
    this.highReturnRatePct = 15,
    this.marginalMarginPct = 8,
  });

  /// İade oranı bunun üstündeyse "iade kârı eritiyor".
  final double highReturnRatePct;

  /// Kâr oranı bunun altındaysa (zarar değilse) "sınırda".
  final double marginalMarginPct;

  DealerProfitResult calculate({
    required double dailyUnits,
    required double dealerSalePrice,
    required double costPerUnit,
    required double dailyReturns,
    double distributionCost = 0,
  }) {
    final units = nonNeg(dailyUnits);
    final price = nonNeg(dealerSalePrice);
    final cost = nonNeg(costPerUnit);
    // İade verilen adedi aşamaz.
    final returns = nonNeg(dailyReturns).clamp(0, units).toDouble();
    final distribution = nonNeg(distributionCost);

    final soldUnits = units - returns;
    final dailyRevenue = soldUnits * price;
    final totalCost = units * cost;
    final returnLoss = returns * cost;
    final netProfit = dailyRevenue - totalCost - distribution;
    final marginPct = safeDiv(netProfit, dailyRevenue) * 100.0;
    final returnRatePct = safeDiv(returns, units) * 100.0;

    final DealerProfitVerdict verdict;
    if (netProfit < 0) {
      verdict = DealerProfitVerdict.lossy;
    } else if (returnRatePct >= highReturnRatePct) {
      verdict = DealerProfitVerdict.highReturns;
    } else if (marginPct < marginalMarginPct) {
      verdict = DealerProfitVerdict.marginal;
    } else {
      verdict = DealerProfitVerdict.profitable;
    }

    return DealerProfitResult(
      dailyRevenue: finiteOrZero(dailyRevenue),
      returnLoss: finiteOrZero(returnLoss),
      netProfit: finiteOrZero(netProfit),
      profitMarginPct: finiteOrZero(marginPct),
      returnRatePct: finiteOrZero(returnRatePct),
      verdict: verdict,
    );
  }
}
