import 'calc_safety.dart';

/// Günlük fire/bayat zarar yorumu.
enum WasteLossVerdict { low, moderate, high }

/// "Günlük Fire / Bayat Zarar" sonucu.
class WasteLossResult {
  const WasteLossResult({
    required this.wasteCount,
    required this.wasteRatePct,
    required this.costLoss,
    required this.missedSaleValue,
    required this.verdict,
  });

  /// Fire/bayat/iade adet (üretileni aşamaz).
  final double wasteCount;

  /// Fire oranı % (fire / üretilen).
  final double wasteRatePct;

  /// Maliyet bazlı zarar (çöpe giden ürünün maliyeti).
  final double costLoss;

  /// Kaçırılan satış değeri (fire satılabilseydi gelecek ciro).
  final double missedSaleValue;

  final WasteLossVerdict verdict;
}

/// Geri dönen, bayatlayan veya çöpe giden ürünün günlük parasal zararını
/// hesaplar (saf Dart).
///
/// Fire üretilen adedi aşamaz. NaN / Infinity / sıfıra bölme üretmez;
/// negatifler 0'a normalize edilir.
class WasteLossCalculator {
  const WasteLossCalculator({this.highRatePct = 10, this.moderateRatePct = 5});

  /// Fire oranı bunun üstündeyse "yüksek".
  final double highRatePct;

  /// Fire oranı bunun üstündeyse "orta" (yüksek değilse).
  final double moderateRatePct;

  WasteLossResult calculate({
    required double producedCount,
    required double soldCount,
    required double wasteCount,
    required double costPerUnit,
    required double salePrice,
  }) {
    final produced = nonNeg(producedCount);
    // soldCount şu an yorumda kullanılmıyor ama API tamlığı için normalize
    // edilir (gelecekte satılan-bazlı metrikler için).
    nonNeg(soldCount);
    final waste = nonNeg(wasteCount).clamp(0, produced).toDouble();
    final cost = nonNeg(costPerUnit);
    final price = nonNeg(salePrice);

    final wasteRatePct = safeDiv(waste, produced) * 100.0;
    final costLoss = waste * cost;
    final missedSaleValue = waste * price;

    final WasteLossVerdict verdict;
    if (wasteRatePct > highRatePct) {
      verdict = WasteLossVerdict.high;
    } else if (wasteRatePct > moderateRatePct) {
      verdict = WasteLossVerdict.moderate;
    } else {
      verdict = WasteLossVerdict.low;
    }

    return WasteLossResult(
      wasteCount: finiteOrZero(waste),
      wasteRatePct: finiteOrZero(wasteRatePct),
      costLoss: finiteOrZero(costLoss),
      missedSaleValue: finiteOrZero(missedSaleValue),
      verdict: verdict,
    );
  }
}
