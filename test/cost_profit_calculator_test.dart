import 'package:firin_defter/features/bakery_panel/calculators/services/cost_profit_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = CostProfitCalculator();

  group('CostProfitCalculator', () {
    test('normal senaryo → beklenen maliyet/kâr', () {
      final r = calc.calculate(
        productionCount: 500,
        flourCost: 1000,
        otherIngredientCost: 250,
        packagingCost: 150,
        laborCost: 900,
        energyCost: 300,
        otherExpensePct: 10,
        salePrice: 7.5,
      );
      expect(r.totalCost, closeTo(2860, 1e-9));
      expect(r.costPerUnit, closeTo(5.72, 1e-9));
      expect(r.profitPerUnit, closeTo(1.78, 1e-9));
      expect(r.profitMarginPct, closeTo(23.7333, 1e-3));
      expect(r.dailyTotalProfit, closeTo(890, 1e-9));
    });

    test('zarar senaryosu: fiyat maliyetin altında → negatif kâr', () {
      final r = calc.calculate(
        productionCount: 100,
        flourCost: 1000,
        otherIngredientCost: 0,
        packagingCost: 0,
        laborCost: 0,
        energyCost: 0,
        salePrice: 5,
      );
      // costPerUnit = 1000/100 = 10 → profit = 5-10 = -5
      expect(r.costPerUnit, closeTo(10, 1e-9));
      expect(r.profitPerUnit, closeTo(-5, 1e-9));
      expect(r.dailyTotalProfit, closeTo(-500, 1e-9));
    });

    test('bölme riski: adet 0 → ürün başı maliyet 0 (sonsuz değil)', () {
      final r = calc.calculate(
        productionCount: 0,
        flourCost: 1000,
        otherIngredientCost: 0,
        packagingCost: 0,
        laborCost: 0,
        energyCost: 0,
        salePrice: 5,
      );
      expect(r.costPerUnit.isFinite, isTrue);
      expect(r.costPerUnit, 0);
    });

    test('satış fiyatı 0 → kâr oranı sonlu (0)', () {
      final r = calc.calculate(
        productionCount: 100,
        flourCost: 100,
        otherIngredientCost: 0,
        packagingCost: 0,
        laborCost: 0,
        energyCost: 0,
        salePrice: 0,
      );
      expect(r.profitMarginPct.isFinite, isTrue);
      expect(r.profitMarginPct, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        productionCount: -100,
        flourCost: -1000,
        otherIngredientCost: -1,
        packagingCost: -1,
        laborCost: -1,
        energyCost: -1,
        salePrice: -5,
      );
      expect(r.totalCost, 0);
      expect(r.profitPerUnit, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        productionCount: 1e9,
        flourCost: 1e9,
        otherIngredientCost: 0,
        packagingCost: 0,
        laborCost: 0,
        energyCost: 0,
        salePrice: 1e6,
      );
      expect(r.totalCost.isFinite, isTrue);
      expect(r.dailyTotalProfit.isFinite, isTrue);
    });
  });
}
