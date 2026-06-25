import 'calc_safety.dart';

/// Bir parti üretimin kâr durumu yorumu.
enum BatchProfitVerdict { loss, thin, healthy }

/// "Tepsi / Parti Bazında Değer" sonucu.
class BatchValueResult {
  const BatchValueResult({
    required this.totalUnits,
    required this.totalCost,
    required this.totalSale,
    required this.grossProfit,
    required this.profitPerUnit,
    required this.profitMarginPct,
    required this.verdict,
  });

  /// Toplam üretilen adet = tepsi/parti başı adet × parti sayısı.
  final double totalUnits;

  final double totalCost;
  final double totalSale;

  /// Toplam brüt kâr (zarar negatif olabilir).
  final double grossProfit;

  /// Adet başı kâr (zarar negatif olabilir).
  final double profitPerUnit;

  /// Satış fiyatına göre kâr oranı %.
  final double profitMarginPct;

  final BatchProfitVerdict verdict;
}

/// Bir tepsi/parti üretimin maliyetini, satış değerini ve brüt kârını
/// hesaplar (saf Dart).
///
/// Kâr/zarar negatif olabilir (zarar göstergesi). NaN / Infinity / sıfıra
/// bölme üretmez; negatifler 0'a normalize edilir.
class BatchValueCalculator {
  const BatchValueCalculator({this.thinMarginPct = 10});

  /// Kâr oranı bunun altındaysa (zarar değilse) "ince kâr" sayılır.
  final double thinMarginPct;

  BatchValueResult calculate({
    required double unitsPerBatch,
    required double costPerUnit,
    required double salePricePerUnit,
    required double batchCount,
  }) {
    final perBatch = nonNeg(unitsPerBatch);
    final cost = nonNeg(costPerUnit);
    final price = nonNeg(salePricePerUnit);
    final batches = nonNeg(batchCount);

    final totalUnits = perBatch * batches;
    final totalCost = totalUnits * cost;
    final totalSale = totalUnits * price;
    final grossProfit = totalSale - totalCost;
    final profitPerUnit = price - cost;
    final marginPct = safeDiv(profitPerUnit, price) * 100.0;

    final BatchProfitVerdict verdict;
    if (profitPerUnit < 0) {
      verdict = BatchProfitVerdict.loss;
    } else if (marginPct < thinMarginPct) {
      verdict = BatchProfitVerdict.thin;
    } else {
      verdict = BatchProfitVerdict.healthy;
    }

    return BatchValueResult(
      totalUnits: finiteOrZero(totalUnits),
      totalCost: finiteOrZero(totalCost),
      totalSale: finiteOrZero(totalSale),
      grossProfit: finiteOrZero(grossProfit),
      profitPerUnit: finiteOrZero(profitPerUnit),
      profitMarginPct: finiteOrZero(marginPct),
      verdict: verdict,
    );
  }
}
