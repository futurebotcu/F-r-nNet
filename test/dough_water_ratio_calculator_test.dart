import 'package:firin_defter/features/bakery_panel/calculators/services/dough_water_ratio_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = DoughWaterRatioCalculator();

  group('DoughWaterRatioCalculator', () {
    test('normal: 50 un / 33 su → %66 ideal', () {
      final r = calc.evaluate(flourKg: 50, waterKg: 33);
      expect(r.ratioPct, closeTo(66, 1e-9));
      expect(r.band, DoughHydrationBand.ideal);
    });

    test('bantlar: çok sert / su az / ideal / su fazla', () {
      expect(
        calc.evaluate(flourKg: 50, waterKg: 29).band,
        DoughHydrationBand.tooStiff,
      );
      expect(
        calc.evaluate(flourKg: 50, waterKg: 31).band,
        DoughHydrationBand.lowWater,
      );
      expect(
        calc.evaluate(flourKg: 50, waterKg: 34).band,
        DoughHydrationBand.ideal,
      );
      expect(
        calc.evaluate(flourKg: 50, waterKg: 40).band,
        DoughHydrationBand.highWater,
      );
    });

    test('0 değer → oran 0, çok sert', () {
      final r = calc.evaluate(flourKg: 0, waterKg: 0);
      expect(r.ratioPct, 0);
      expect(r.band, DoughHydrationBand.tooStiff);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.evaluate(flourKg: -50, waterKg: -10);
      expect(r.ratioPct, 0);
    });

    test('bölme riski: un 0, su 20 → oran 0 (sonsuz değil)', () {
      final r = calc.evaluate(flourKg: 0, waterKg: 20);
      expect(r.ratioPct.isFinite, isTrue);
      expect(r.ratioPct, 0);
    });

    test('çok büyük değer → oran sonlu', () {
      final r = calc.evaluate(flourKg: 1e9, waterKg: 1e9);
      expect(r.ratioPct.isFinite, isTrue);
      expect(r.ratioPct, closeTo(100, 1e-6));
    });

    test('özel eşikler parametreyle değiştirilebilir', () {
      const custom = DoughWaterRatioCalculator(
        stiffBelow: 55,
        lowWaterBelow: 60,
        idealBelow: 75,
      );
      expect(
        custom.evaluate(flourKg: 50, waterKg: 36).band,
        DoughHydrationBand.ideal,
      );
    });
  });
}
