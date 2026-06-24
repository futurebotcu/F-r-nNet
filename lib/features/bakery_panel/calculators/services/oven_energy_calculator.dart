import 'calc_safety.dart';

/// Fırın Enerji Maliyeti sonucu.
class OvenEnergyResult {
  const OvenEnergyResult({
    required this.energyKwh,
    required this.totalEnergyCost,
    required this.costPerUnit,
  });

  /// Tüketilen enerji (kWh) = güç × süre.
  final double energyKwh;
  final double totalEnergyCost;

  /// Ürün başı enerji maliyeti (adet verilmezse 0).
  final double costPerUnit;
}

/// Fırın enerji maliyetini hesaplar (saf Dart).
///
/// toplam = kW × saat × birim fiyat; adet > 0 ise ürün başı maliyet.
/// Negatif girişler 0'a normalize edilir; sıfıra bölme üretmez.
class OvenEnergyCalculator {
  const OvenEnergyCalculator();

  OvenEnergyResult calculate({
    required double powerKw,
    required double hours,
    required double unitPrice,
    double pieces = 0,
  }) {
    final kw = nonNeg(powerKw);
    final hrs = nonNeg(hours);
    final price = nonNeg(unitPrice);
    final count = nonNeg(pieces);

    final kwh = kw * hrs;
    final total = kwh * price;
    final perUnit = safeDiv(total, count);

    return OvenEnergyResult(
      energyKwh: finiteOrZero(kwh),
      totalEnergyCost: finiteOrZero(total),
      costPerUnit: finiteOrZero(perUnit),
    );
  }
}
