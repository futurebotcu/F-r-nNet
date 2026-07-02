import 'calc_safety.dart';

/// İşçilik hesabı yorumu: süre veya adet yoksa hesap yapılamaz.
enum LaborIndexVerdict { invalid, ok }

/// "Ürün Başı İşçilik" sonucu.
class LaborIndexResult {
  const LaborIndexResult({
    required this.secondsPerUnit,
    required this.laborCostPerUnit,
    required this.hourlyOutput,
    required this.verdict,
  });

  /// Bir ürüne giden süre (saniye).
  final double secondsPerUnit;

  /// Bir ürüne giden işçilik maliyeti (TL).
  final double laborCostPerUnit;

  /// Saatlik üretim hızı (adet/saat).
  final double hourlyOutput;

  final LaborIndexVerdict verdict;
}

/// Toplam üretim süresi, çıkan ürün adedi ve işçilik maliyetinden ürün
/// başı süre/işçilik ile saatlik üretim hızını hesaplar (saf Dart).
///
/// Süre veya ürün adedi 0 ise [LaborIndexVerdict.invalid] döner.
/// NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize edilir.
class LaborIndexCalculator {
  const LaborIndexCalculator();

  LaborIndexResult calculate({
    required double totalMinutes,
    required double producedCount,
    required double laborCost,
  }) {
    final minutes = nonNeg(totalMinutes);
    final count = nonNeg(producedCount);
    final cost = nonNeg(laborCost);

    if (minutes <= 0 || count <= 0) {
      return const LaborIndexResult(
        secondsPerUnit: 0,
        laborCostPerUnit: 0,
        hourlyOutput: 0,
        verdict: LaborIndexVerdict.invalid,
      );
    }

    final secondsPerUnit = safeDiv(minutes * 60, count);
    final laborCostPerUnit = safeDiv(cost, count);
    final hourlyOutput = safeDiv(count * 60, minutes);

    return LaborIndexResult(
      secondsPerUnit: finiteOrZero(secondsPerUnit),
      laborCostPerUnit: finiteOrZero(laborCostPerUnit),
      hourlyOutput: finiteOrZero(hourlyOutput),
      verdict: LaborIndexVerdict.ok,
    );
  }
}
