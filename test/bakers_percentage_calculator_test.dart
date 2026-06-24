import 'package:firin_defter/features/bakery_panel/calculators/services/bakers_percentage_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = BakersPercentageCalculator();

  group('BakersPercentageCalculator', () {
    test('normal: 50 un, su %62, maya %2.3, tuz %1.8', () {
      final r = calc.calculate(
        flourKg: 50,
        waterPct: 62,
        yeastPct: 2.3,
        saltPct: 1.8,
      );
      expect(r.waterKg, closeTo(31, 1e-9));
      expect(r.yeastKg, closeTo(1.15, 1e-9));
      expect(r.saltKg, closeTo(0.9, 1e-9));
      expect(r.otherKg, 0);
      expect(r.totalDoughKg, closeTo(83.05, 1e-9));
    });

    test('diğer katkı toplam hamuru artırır', () {
      final r = calc.calculate(
        flourKg: 50,
        waterPct: 60,
        yeastPct: 0,
        saltPct: 0,
        otherPct: 4,
      );
      expect(r.otherKg, closeTo(2, 1e-9));
      expect(r.totalDoughKg, closeTo(82, 1e-9));
    });

    test('0 un → her şey 0', () {
      final r = calc.calculate(
        flourKg: 0,
        waterPct: 62,
        yeastPct: 2,
        saltPct: 2,
      );
      expect(r.totalDoughKg, 0);
      expect(r.waterKg, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        flourKg: -50,
        waterPct: -62,
        yeastPct: -2,
        saltPct: -2,
      );
      expect(r.totalDoughKg, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        flourKg: 1e9,
        waterPct: 62,
        yeastPct: 2,
        saltPct: 2,
      );
      expect(r.totalDoughKg.isFinite, isTrue);
      expect(r.waterKg.isFinite, isTrue);
    });
  });
}
