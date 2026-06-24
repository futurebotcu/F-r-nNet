import 'calc_safety.dart';

/// Un Zammı Etki Hesabı sonucu.
class FlourPriceHikeResult {
  const FlourPriceHikeResult({
    required this.perSackDiff,
    required this.dailyExtraCost,
    required this.monthlyExtraCost,
  });

  /// Çuval başı fiyat farkı (yeni − eski). Zam düşerse negatif olabilir.
  final double perSackDiff;
  final double dailyExtraCost;
  final double monthlyExtraCost;
}

/// Un zammının günlük/aylık ek maliyetini hesaplar (saf Dart).
///
/// Fiyat düşerse fark negatif olur (tasarruf göstergesi). Fiyatlar/çuval
/// adedi negatif girilirse 0'a normalize edilir; ay = 30 gün kabulü.
class FlourPriceHikeCalculator {
  const FlourPriceHikeCalculator({this.daysPerMonth = 30});

  final int daysPerMonth;

  FlourPriceHikeResult calculate({
    required double oldSackPrice,
    required double newSackPrice,
    required double dailySacks,
  }) {
    final oldPrice = nonNeg(oldSackPrice);
    final newPrice = nonNeg(newSackPrice);
    final sacks = nonNeg(dailySacks);

    final perSackDiff = newPrice - oldPrice;
    final dailyExtra = perSackDiff * sacks;
    final monthlyExtra = dailyExtra * daysPerMonth;

    return FlourPriceHikeResult(
      perSackDiff: finiteOrZero(perSackDiff),
      dailyExtraCost: finiteOrZero(dailyExtra),
      monthlyExtraCost: finiteOrZero(monthlyExtra),
    );
  }
}
