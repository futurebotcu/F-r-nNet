import 'calc_safety.dart';

/// Reçete Büyüt/Küçült sonucu.
class RecipeScaleResult {
  const RecipeScaleResult({
    required this.multiplier,
    required this.flourKg,
    required this.waterKg,
    required this.yeastKg,
    required this.saltKg,
    required this.otherKg,
  });

  /// Ölçekleme çarpanı = yeni hedef / eski hedef.
  final double multiplier;

  final double flourKg;
  final double waterKg;
  final double yeastKg;
  final double saltKg;
  final double otherKg;
}

/// Reçeteyi yeni hedefe (adet/kg) göre ölçekler (saf Dart).
///
/// Çarpan = yeni / eski; her malzeme = eski miktar × çarpan. Eski hedef 0/NaN
/// ise çarpan 0 olur (güvenli bölme) — taşma / sonsuz değer üretmez.
class RecipeScalerCalculator {
  const RecipeScalerCalculator();

  RecipeScaleResult scale({
    required double oldTarget,
    required double newTarget,
    required double flourKg,
    double waterKg = 0,
    double yeastKg = 0,
    double saltKg = 0,
    double otherKg = 0,
  }) {
    final multiplier = safeDiv(nonNeg(newTarget), nonNeg(oldTarget));

    return RecipeScaleResult(
      multiplier: finiteOrZero(multiplier),
      flourKg: finiteOrZero(nonNeg(flourKg) * multiplier),
      waterKg: finiteOrZero(nonNeg(waterKg) * multiplier),
      yeastKg: finiteOrZero(nonNeg(yeastKg) * multiplier),
      saltKg: finiteOrZero(nonNeg(saltKg) * multiplier),
      otherKg: finiteOrZero(nonNeg(otherKg) * multiplier),
    );
  }
}
