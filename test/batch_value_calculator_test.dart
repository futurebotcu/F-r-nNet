import 'package:firin_defter/features/bakery_panel/calculators/services/batch_value_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = BatchValueCalculator();

  group('BatchValueCalculator', () {
    test('normal senaryo → toplam/kâr doğru, sağlıklı', () {
      final r = calc.calculate(
        unitsPerBatch: 40,
        costPerUnit: 4,
        salePricePerUnit: 7.5,
        batchCount: 6,
      );
      expect(r.totalUnits, closeTo(240, 1e-9));
      expect(r.totalCost, closeTo(960, 1e-9));
      expect(r.totalSale, closeTo(1800, 1e-9));
      expect(r.grossProfit, closeTo(840, 1e-9));
      expect(r.profitPerUnit, closeTo(3.5, 1e-9));
      expect(r.profitMarginPct, closeTo(46.6667, 1e-3));
      expect(r.verdict, BatchProfitVerdict.healthy);
    });

    test('zarar senaryosu: maliyet fiyatın üstünde → loss', () {
      final r = calc.calculate(
        unitsPerBatch: 40,
        costPerUnit: 8,
        salePricePerUnit: 7.5,
        batchCount: 6,
      );
      expect(r.grossProfit, lessThan(0));
      expect(r.verdict, BatchProfitVerdict.loss);
    });

    test('ince kâr: marj %10 altı → thin', () {
      final r = calc.calculate(
        unitsPerBatch: 40,
        costPerUnit: 4.7,
        salePricePerUnit: 5,
        batchCount: 6,
      );
      expect(r.profitMarginPct, closeTo(6, 1e-9));
      expect(r.verdict, BatchProfitVerdict.thin);
    });

    test('0 değer → her şey sonlu', () {
      final r = calc.calculate(
        unitsPerBatch: 0,
        costPerUnit: 0,
        salePricePerUnit: 0,
        batchCount: 0,
      );
      expect(r.totalUnits, 0);
      expect(r.profitMarginPct.isFinite, isTrue);
    });

    test('bölme riski: satış fiyatı 0 → marj sonlu (0)', () {
      final r = calc.calculate(
        unitsPerBatch: 40,
        costPerUnit: 4,
        salePricePerUnit: 0,
        batchCount: 6,
      );
      expect(r.profitMarginPct.isFinite, isTrue);
      expect(r.profitMarginPct, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        unitsPerBatch: -40,
        costPerUnit: -4,
        salePricePerUnit: -7.5,
        batchCount: -6,
      );
      expect(r.totalUnits, 0);
      expect(r.totalCost, 0);
      expect(r.totalSale, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        unitsPerBatch: 1e6,
        costPerUnit: 1e6,
        salePricePerUnit: 1e6,
        batchCount: 1e6,
      );
      expect(r.totalSale.isFinite, isTrue);
      expect(r.grossProfit.isFinite, isTrue);
    });
  });
}
