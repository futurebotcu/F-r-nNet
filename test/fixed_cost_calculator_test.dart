import 'package:firin_defter/features/bakery_panel/calculators/services/fixed_cost_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FixedCostCalculator();

  group('FixedCostCalculator', () {
    test('normal senaryo → günlük/çuval/ürün başı doğru', () {
      final r = calc.calculate(
        monthlyFixedTotal: 90000,
        workDaysPerMonth: 30,
        dailySacks: 10,
        dailyUnits: 1200,
      );
      expect(r.dailyFixedCost, closeTo(3000, 1e-9));
      expect(r.perSackFixedCost, closeTo(300, 1e-9));
      expect(r.perUnitFixedCost, closeTo(2.5, 1e-9));
    });

    test('bölme riski: çalışma günü 0 → günlük yük 0 (sonsuz değil)', () {
      final r = calc.calculate(
        monthlyFixedTotal: 90000,
        workDaysPerMonth: 0,
        dailySacks: 10,
        dailyUnits: 1200,
      );
      expect(r.dailyFixedCost, 0);
      expect(r.dailyFixedCost.isFinite, isTrue);
    });

    test('bölme riski: çuval 0 → çuval başı 0', () {
      final r = calc.calculate(
        monthlyFixedTotal: 90000,
        workDaysPerMonth: 30,
        dailySacks: 0,
        dailyUnits: 0,
      );
      expect(r.perSackFixedCost, 0);
      expect(r.perUnitFixedCost, 0);
      expect(r.perSackFixedCost.isFinite, isTrue);
    });

    test('0 değer → her şey sonlu', () {
      final r = calc.calculate(
        monthlyFixedTotal: 0,
        workDaysPerMonth: 0,
        dailySacks: 0,
      );
      expect(r.dailyFixedCost, 0);
      expect(r.perSackFixedCost.isFinite, isTrue);
      expect(r.perUnitFixedCost.isFinite, isTrue);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        monthlyFixedTotal: -90000,
        workDaysPerMonth: -30,
        dailySacks: -10,
        dailyUnits: -1200,
      );
      expect(r.dailyFixedCost, 0);
      expect(r.perSackFixedCost, 0);
      expect(r.perUnitFixedCost, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        monthlyFixedTotal: 1e9,
        workDaysPerMonth: 1,
        dailySacks: 1,
        dailyUnits: 1,
      );
      expect(r.dailyFixedCost.isFinite, isTrue);
      expect(r.perSackFixedCost.isFinite, isTrue);
    });
  });
}
