import 'package:firin_defter/features/bakery_panel/calculators/services/recipe_cost_detail_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = RecipeCostDetailCalculator();

  const items = [
    RecipeCostItem(name: 'Un', quantity: 100, unitPrice: 18),
    RecipeCostItem(name: 'Maya/Tuz/Katkı', flatCost: 250),
    RecipeCostItem(name: 'Yağ', quantity: 5, unitPrice: 90),
    RecipeCostItem(name: 'Diğer Malzeme', flatCost: 150),
    RecipeCostItem(name: 'Ambalaj', flatCost: 100),
  ];

  group('RecipeCostDetailCalculator', () {
    test('normal senaryo → toplam + ürün başı + önerilen fiyat', () {
      final r = calc.calculate(
        productionCount: 1000,
        items: items,
        targetProfitPct: 25,
      );
      expect(r.totalCost, closeTo(2750, 1e-9));
      expect(r.costPerUnit, closeTo(2.75, 1e-9));
      expect(r.suggestedPrice, closeTo(3.4375, 1e-9));
      expect(r.verdict, RecipeCostVerdict.ok);
    });

    test('dominant kalem → en yüksek maliyetli kalem (Un)', () {
      final r = calc.calculate(productionCount: 1000, items: items);
      expect(r.dominantItemName, 'Un');
      expect(r.dominantItemCost, closeTo(1800, 1e-9));
    });

    test('üretim adedi 0 → invalid', () {
      final r = calc.calculate(productionCount: 0, items: items);
      expect(r.verdict, RecipeCostVerdict.invalid);
      expect(r.totalCost, 0);
      expect(r.costPerUnit, 0);
      expect(r.suggestedPrice, 0);
      expect(r.dominantItemName, '');
    });

    test('boş kalem listesi → invalid', () {
      final r = calc.calculate(productionCount: 1000, items: const []);
      expect(r.verdict, RecipeCostVerdict.invalid);
      expect(r.totalCost, 0);
      expect(r.dominantItemName, '');
    });

    test('negatif miktar → 0\'a normalize (kalem maliyeti düşmez)', () {
      final r = calc.calculate(
        productionCount: 1000,
        items: const [
          RecipeCostItem(name: 'Un', quantity: -100, unitPrice: 18),
          RecipeCostItem(name: 'Ambalaj', flatCost: 100),
        ],
      );
      expect(r.totalCost, closeTo(100, 1e-9));
      expect(r.dominantItemName, 'Ambalaj');
      expect(r.costPerUnit.isFinite, isTrue);
      expect(r.verdict, RecipeCostVerdict.ok);
    });

    test('hedef %0 kâr → önerilen fiyat = ürün başı maliyet', () {
      final r = calc.calculate(productionCount: 1000, items: items);
      expect(r.suggestedPrice, closeTo(r.costPerUnit, 1e-9));
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        productionCount: 1e9,
        items: const [
          RecipeCostItem(name: 'Un', quantity: 1e9, unitPrice: 1e9),
        ],
        targetProfitPct: 1e9,
      );
      expect(r.totalCost.isFinite, isTrue);
      expect(r.costPerUnit.isFinite, isTrue);
      expect(r.suggestedPrice.isFinite, isTrue);
      expect(r.dominantItemCost.isFinite, isTrue);
    });
  });
}
