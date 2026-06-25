import 'package:firin_defter/features/bakery_panel/calculators/services/price_update_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = PriceUpdateSimulator();

  group('PriceUpdateSimulator', () {
    test('normal senaryo → yeni maliyet/önerilen fiyat, marj erimiş', () {
      final r = calc.calculate(
        currentUnitCost: 5,
        oldMainCost: 1000,
        newMainCost: 1200,
        currentSalePrice: 7.5,
        targetMarginPct: 30,
      );
      expect(r.newUnitCost, closeTo(6, 1e-9));
      expect(r.currentMarginPct, closeTo(20, 1e-9));
      expect(r.suggestedPrice, closeTo(8.5714, 1e-3));
      expect(r.priceDiff, closeTo(1.0714, 1e-3));
      expect(r.verdict, PriceUpdateVerdict.marginEroded);
    });

    test('zarar: yeni maliyet satış fiyatının üstünde → sellingAtLoss', () {
      final r = calc.calculate(
        currentUnitCost: 5,
        oldMainCost: 1000,
        newMainCost: 1200,
        currentSalePrice: 5,
        targetMarginPct: 30,
      );
      expect(r.newUnitCost, closeTo(6, 1e-9));
      expect(r.verdict, PriceUpdateVerdict.sellingAtLoss);
    });

    test('hedef tutuyorsa → comfortable', () {
      final r = calc.calculate(
        currentUnitCost: 5,
        oldMainCost: 1000,
        newMainCost: 1200,
        currentSalePrice: 7.5,
        targetMarginPct: 10,
      );
      expect(r.currentMarginPct, greaterThanOrEqualTo(10));
      expect(r.verdict, PriceUpdateVerdict.comfortable);
    });

    test('eski ana maliyet 0 → oran 1 (maliyet değişmez, sonsuz değil)', () {
      final r = calc.calculate(
        currentUnitCost: 5,
        oldMainCost: 0,
        newMainCost: 1200,
        currentSalePrice: 7.5,
        targetMarginPct: 30,
      );
      expect(r.newUnitCost, closeTo(5, 1e-9));
      expect(r.newUnitCost.isFinite, isTrue);
    });

    test('hedef kâr %100+ → %95\'e kırpılır, önerilen fiyat sonlu', () {
      final r = calc.calculate(
        currentUnitCost: 5,
        oldMainCost: 1000,
        newMainCost: 1000,
        currentSalePrice: 7.5,
        targetMarginPct: 100,
      );
      expect(r.suggestedPrice.isFinite, isTrue);
      // newCost 5 / (1 - 0.95) = 100
      expect(r.suggestedPrice, closeTo(100, 1e-6));
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        currentUnitCost: -5,
        oldMainCost: -1000,
        newMainCost: -1200,
        currentSalePrice: -7.5,
        targetMarginPct: -30,
      );
      expect(r.newUnitCost, 0);
      expect(r.suggestedPrice, 0);
      expect(r.currentMarginPct.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        currentUnitCost: 1e6,
        oldMainCost: 1,
        newMainCost: 1e9,
        currentSalePrice: 1e6,
        targetMarginPct: 30,
      );
      expect(r.newUnitCost.isFinite, isTrue);
      expect(r.suggestedPrice.isFinite, isTrue);
    });
  });
}
