import 'dart:math' as math;

import 'calc_safety.dart';

/// Mayalanma ortamının yorumu.
enum FermentationVerdict { noYeast, coldSlow, normal, hotFast }

/// "Mayalanma Süresi Tahmini" sonucu.
class FermentationResult {
  const FermentationResult({
    required this.minutes,
    required this.effectiveTemp,
    required this.verdict,
  });

  /// Tahmini mayalanma süresi (dakika). Maya yoksa 0.
  final double minutes;

  /// Ortam ve hamur sıcaklığının ortalaması (°C).
  final double effectiveTemp;

  final FermentationVerdict verdict;
}

/// Ortam/hamur sıcaklığı ve maya oranına göre yaklaşık mayalanma süresi
/// tahmin eder (saf Dart).
///
/// Bu bir pratik saha tahminidir; bilimsel kesinlik iddiası yoktur. Un,
/// maya tazeliği ve hamur yapısına göre gerçek süre değişir. Kaba kural:
/// sıcaklık her [tempDoublingStep] °C düştüğünde süre yaklaşık ikiye
/// katlanır; maya oranı arttıkça süre kısalır. Tüm eşik ve parametreler
/// ctor'dan ayarlanabilir.
///
/// NaN / Infinity üretmez; sıcaklıklar -10..60 °C aralığına, süre
/// [minMinutes]..[maxMinutes] aralığına kırpılır.
class FermentationTimeCalculator {
  const FermentationTimeCalculator({
    this.baseMinutes = 90,
    this.refTemp = 26,
    this.refYeastPct = 2,
    this.tempDoublingStep = 8,
    this.minMinutes = 15,
    this.maxMinutes = 720,
  });

  /// Referans koşullarda ([refTemp] °C, %[refYeastPct] maya) baz süre (dk).
  final double baseMinutes;

  /// Referans etkili sıcaklık (°C).
  final double refTemp;

  /// Referans maya oranı (una göre %).
  final double refYeastPct;

  /// Sıcaklık bu kadar °C düşünce süre yaklaşık ikiye katlanır.
  final double tempDoublingStep;

  /// Tahmin bu dakikanın altına kırpılmaz.
  final double minMinutes;

  /// Tahmin bu dakikanın üstüne kırpılmaz.
  final double maxMinutes;

  FermentationResult calculate({
    required double ambientTemp,
    required double doughTemp,
    required double yeastPct,
  }) {
    final ambient = _clampTemp(finiteTemp(ambientTemp));
    final dough = _clampTemp(finiteTemp(doughTemp));
    final yeast = nonNeg(yeastPct);

    final effectiveTemp = (ambient + dough) / 2;

    if (yeast <= 0) {
      return FermentationResult(
        minutes: 0,
        effectiveTemp: effectiveTemp,
        verdict: FermentationVerdict.noYeast,
      );
    }

    final tempFactor = math
        .pow(2, (refTemp - effectiveTemp) / tempDoublingStep)
        .toDouble();
    final yeastFactor = safeDiv(refYeastPct, yeast).clamp(0.25, 4.0);
    final rawMinutes = finiteOrZero(baseMinutes * tempFactor * yeastFactor);
    final minutes = rawMinutes.clamp(minMinutes, maxMinutes).toDouble();

    final FermentationVerdict verdict;
    if (effectiveTemp < 20) {
      verdict = FermentationVerdict.coldSlow;
    } else if (effectiveTemp > 30) {
      verdict = FermentationVerdict.hotFast;
    } else {
      verdict = FermentationVerdict.normal;
    }

    return FermentationResult(
      minutes: finiteOrZero(minutes),
      effectiveTemp: effectiveTemp,
      verdict: verdict,
    );
  }

  /// Fırın ortamında anlamlı sıcaklık aralığı: -10..60 °C.
  double _clampTemp(double t) => t.clamp(-10.0, 60.0).toDouble();
}
