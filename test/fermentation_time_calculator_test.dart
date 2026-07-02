import 'package:firin_defter/features/bakery_panel/calculators/services/fermentation_time_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FermentationTimeCalculator();

  group('FermentationTimeCalculator', () {
    test('referans koşullar → süre baz süreye yakın, normal', () {
      final r = calc.calculate(ambientTemp: 24, doughTemp: 26, yeastPct: 2);
      expect(r.effectiveTemp, closeTo(25, 1e-9));
      // effTemp 25 → tempFactor 2^(1/8) ≈ 1.09; 90 dk baza yakın kalmalı.
      expect(r.minutes, greaterThan(80));
      expect(r.minutes, lessThan(120));
      expect(r.verdict, FermentationVerdict.normal);
    });

    test('soğuk ortam → süre uzar + coldSlow', () {
      final ref = calc.calculate(ambientTemp: 26, doughTemp: 26, yeastPct: 2);
      final cold = calc.calculate(ambientTemp: 10, doughTemp: 10, yeastPct: 2);
      expect(cold.minutes, greaterThan(ref.minutes));
      expect(cold.verdict, FermentationVerdict.coldSlow);
    });

    test('sıcak ortam → süre kısalır + hotFast', () {
      final ref = calc.calculate(ambientTemp: 26, doughTemp: 26, yeastPct: 2);
      final hot = calc.calculate(ambientTemp: 34, doughTemp: 34, yeastPct: 2);
      expect(hot.minutes, lessThan(ref.minutes));
      expect(hot.verdict, FermentationVerdict.hotFast);
    });

    test('maya %4 → süre referansa göre kısalır', () {
      final ref = calc.calculate(ambientTemp: 24, doughTemp: 26, yeastPct: 2);
      final more = calc.calculate(ambientTemp: 24, doughTemp: 26, yeastPct: 4);
      expect(more.minutes, lessThan(ref.minutes));
    });

    test('maya 0 → noYeast (süre 0, sıcaklık yine hesaplanır)', () {
      final r = calc.calculate(ambientTemp: 24, doughTemp: 26, yeastPct: 0);
      expect(r.verdict, FermentationVerdict.noYeast);
      expect(r.minutes, 0);
      expect(r.effectiveTemp, closeTo(25, 1e-9));
    });

    test('aşırı soğuk → maxMinutes üstüne çıkmaz', () {
      final r = calc.calculate(ambientTemp: -30, doughTemp: -30, yeastPct: 0.1);
      expect(r.minutes, lessThanOrEqualTo(720));
      expect(r.minutes, 720);
    });

    test('aşırı sıcak → minMinutes altına inmez', () {
      final r = calc.calculate(ambientTemp: 60, doughTemp: 60, yeastPct: 10);
      expect(r.minutes, greaterThanOrEqualTo(15));
      expect(r.minutes.isFinite, isTrue);
    });

    test('NaN / negatif girdiler → sonlu sonuç', () {
      final r = calc.calculate(
        ambientTemp: double.nan,
        doughTemp: double.infinity,
        yeastPct: -2,
      );
      expect(r.verdict, FermentationVerdict.noYeast);
      expect(r.minutes.isFinite, isTrue);
      expect(r.effectiveTemp.isFinite, isTrue);

      final r2 = calc.calculate(
        ambientTemp: double.nan,
        doughTemp: double.negativeInfinity,
        yeastPct: 2,
      );
      expect(r2.minutes.isFinite, isTrue);
      expect(r2.effectiveTemp.isFinite, isTrue);
    });
  });
}
