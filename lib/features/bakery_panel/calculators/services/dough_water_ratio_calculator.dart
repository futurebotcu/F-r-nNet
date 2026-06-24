import 'calc_safety.dart';

/// Hamur su oranı kıvam yorumu.
enum DoughHydrationBand { tooStiff, lowWater, ideal, highWater }

/// Hamur Su Oranı Ustası sonucu.
class DoughWaterRatioResult {
  const DoughWaterRatioResult({
    required this.ratioPct,
    required this.band,
  });

  final double ratioPct;
  final DoughHydrationBand band;
}

/// Su / un oranını yüzde olarak hesaplar ve kıvam bandını verir (saf Dart).
///
/// Eşikler varsayılan parametre; ileride ürün tipine göre değiştirilebilir.
class DoughWaterRatioCalculator {
  const DoughWaterRatioCalculator({
    this.stiffBelow = 60,
    this.lowWaterBelow = 65,
    this.idealBelow = 70,
  });

  /// Bu oranın altı "çok sert".
  final double stiffBelow;

  /// [stiffBelow]–[lowWaterBelow] arası "su az".
  final double lowWaterBelow;

  /// [lowWaterBelow]–[idealBelow] arası "ideal"; üstü "su fazla".
  final double idealBelow;

  DoughWaterRatioResult evaluate({
    required double flourKg,
    required double waterKg,
  }) {
    final flour = nonNeg(flourKg);
    final water = nonNeg(waterKg);
    final ratio = safeDiv(water, flour) * 100.0;

    final DoughHydrationBand band;
    if (ratio < stiffBelow) {
      band = DoughHydrationBand.tooStiff;
    } else if (ratio < lowWaterBelow) {
      band = DoughHydrationBand.lowWater;
    } else if (ratio < idealBelow) {
      band = DoughHydrationBand.ideal;
    } else {
      band = DoughHydrationBand.highWater;
    }

    return DoughWaterRatioResult(ratioPct: ratio, band: band);
  }
}
