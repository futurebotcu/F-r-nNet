import 'calc_safety.dart';

/// Önerilen su sıcaklığının yorum bandı.
enum WaterTempBand { iced, normal, lukewarm }

/// Hamur Suyu Sıcaklığı sonucu.
class WaterTemperatureResult {
  const WaterTemperatureResult({required this.waterTempC, required this.band});

  /// Önerilen su sıcaklığı (°C). Negatif olabilir → buzlu su gerekir.
  final double waterTempC;
  final WaterTempBand band;
}

/// Hamur suyu sıcaklığı: su = hedef×3 − (un + oda + sürtünme) (saf Dart).
///
/// Sıcaklıklar negatif olabilir; yalnız NaN/Infinity'den korunur (clamp yok).
/// Eşikler varsayılan parametre — ileride ürün/iklim için değiştirilebilir.
class WaterTemperatureCalculator {
  const WaterTemperatureCalculator({
    this.icedBelow = 4,
    this.lukewarmAbove = 35,
  });

  /// Bu sıcaklığın altı "buzlu su" uyarısı.
  final double icedBelow;

  /// Bu sıcaklığın üstü "ılık su" uyarısı.
  final double lukewarmAbove;

  WaterTemperatureResult calculate({
    required double flourTempC,
    required double roomTempC,
    required double targetDoughTempC,
    double frictionFactor = 0,
  }) {
    final flour = finiteTemp(flourTempC);
    final room = finiteTemp(roomTempC);
    final target = finiteTemp(targetDoughTempC);
    final friction = finiteTemp(frictionFactor);

    final waterTemp = finiteTemp(target * 3.0 - (flour + room + friction));

    final WaterTempBand band;
    if (waterTemp < icedBelow) {
      band = WaterTempBand.iced;
    } else if (waterTemp > lukewarmAbove) {
      band = WaterTempBand.lukewarm;
    } else {
      band = WaterTempBand.normal;
    }

    return WaterTemperatureResult(waterTempC: waterTemp, band: band);
  }
}
