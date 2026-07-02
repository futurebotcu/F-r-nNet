import 'package:firin_defter/features/bakery_panel/calculators/services/labor_index_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = LaborIndexCalculator();

  group('LaborIndexCalculator', () {
    test('normal senaryo → ürün başı süre + işçilik + saatlik üretim', () {
      final r = calc.calculate(
        totalMinutes: 480,
        producedCount: 2000,
        laborCost: 3200,
      );
      expect(r.secondsPerUnit, closeTo(14.4, 1e-9));
      expect(r.laborCostPerUnit, closeTo(1.6, 1e-9));
      expect(r.hourlyOutput, closeTo(250, 1e-9));
      expect(r.verdict, LaborIndexVerdict.ok);
    });

    test('ürün adedi 0 → invalid', () {
      final r = calc.calculate(
        totalMinutes: 480,
        producedCount: 0,
        laborCost: 3200,
      );
      expect(r.verdict, LaborIndexVerdict.invalid);
      expect(r.secondsPerUnit, 0);
      expect(r.laborCostPerUnit, 0);
      expect(r.hourlyOutput, 0);
    });

    test('süre 0 → invalid', () {
      final r = calc.calculate(
        totalMinutes: 0,
        producedCount: 2000,
        laborCost: 3200,
      );
      expect(r.verdict, LaborIndexVerdict.invalid);
      expect(r.hourlyOutput, 0);
    });

    test('negatif → 0\'a normalize (invalid, sonuç sonlu)', () {
      final r = calc.calculate(
        totalMinutes: -480,
        producedCount: -2000,
        laborCost: -3200,
      );
      expect(r.verdict, LaborIndexVerdict.invalid);
      expect(r.secondsPerUnit.isFinite, isTrue);
      expect(r.laborCostPerUnit.isFinite, isTrue);
      expect(r.hourlyOutput.isFinite, isTrue);
    });

    test('işçilik maliyeti 0 → ürün başı işçilik 0 ve sonlu', () {
      final r = calc.calculate(
        totalMinutes: 480,
        producedCount: 2000,
        laborCost: 0,
      );
      expect(r.laborCostPerUnit, 0);
      expect(r.laborCostPerUnit.isFinite, isTrue);
      expect(r.verdict, LaborIndexVerdict.ok);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        totalMinutes: 1e12,
        producedCount: 1,
        laborCost: 1e12,
      );
      expect(r.secondsPerUnit.isFinite, isTrue);
      expect(r.laborCostPerUnit.isFinite, isTrue);
      expect(r.hourlyOutput.isFinite, isTrue);
    });
  });
}
