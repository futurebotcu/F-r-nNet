import 'package:firin_defter/features/bakery_panel/calculators/services/evening_discount_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = EveningDiscountCalculator();

  group('EveningDiscountCalculator', () {
    test('başabaş: 40 adet, maliyet 5, normal 7.5', () {
      final r = calc.calculate(
        remainingCount: 40,
        costPerUnit: 5,
        normalPrice: 7.5,
      );
      expect(r.minSalePrice, closeTo(5, 1e-9));
      expect(r.maxDiscountPct, closeTo(100 / 3, 1e-6));
      expect(r.discountedCashIncome, closeTo(200, 1e-9));
      expect(r.revenueDropVsNormal, closeTo(100, 1e-9));
    });

    test('hedef minimum kâr → minimum fiyat maliyet + hedef kâr', () {
      final r = calc.calculate(
        remainingCount: 40,
        costPerUnit: 5,
        normalPrice: 7.5,
        mode: DiscountMode.minProfit,
        targetMinProfitPerUnit: 0.5,
      );
      expect(r.minSalePrice, closeTo(5.5, 1e-9));
      expect(r.maxDiscountPct, closeTo((2 / 7.5) * 100, 1e-6));
    });

    test('maliyet normalden büyük → indirim tavanı 0 (negatif olmaz)', () {
      final r = calc.calculate(
        remainingCount: 10,
        costPerUnit: 10,
        normalPrice: 7.5,
      );
      expect(r.maxDiscountPct, 0);
    });

    test('bölme riski: normal 0 → indirim oranı sonlu (0)', () {
      final r = calc.calculate(
        remainingCount: 10,
        costPerUnit: 5,
        normalPrice: 0,
      );
      expect(r.maxDiscountPct.isFinite, isTrue);
      expect(r.maxDiscountPct, 0);
    });

    test('0 değer → 0', () {
      final r = calc.calculate(
        remainingCount: 0,
        costPerUnit: 0,
        normalPrice: 0,
      );
      expect(r.minSalePrice, 0);
      expect(r.discountedCashIncome, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        remainingCount: -40,
        costPerUnit: -5,
        normalPrice: -7.5,
      );
      expect(r.minSalePrice, 0);
      expect(r.discountedCashIncome, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        remainingCount: 1e6,
        costPerUnit: 1e6,
        normalPrice: 2e6,
      );
      expect(r.minSalePrice.isFinite, isTrue);
      expect(r.discountedCashIncome.isFinite, isTrue);
    });
  });
}
