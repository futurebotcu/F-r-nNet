import 'package:firin_defter/features/bakery_panel/calculators/services/recipe_scaler_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = RecipeScalerCalculator();

  group('RecipeScalerCalculator', () {
    test('normal: 100 → 250 çarpan 2.5, un 50 → 125', () {
      final r = calc.scale(
        oldTarget: 100,
        newTarget: 250,
        flourKg: 50,
        waterKg: 31,
        yeastKg: 1.2,
        saltKg: 0.9,
      );
      expect(r.multiplier, closeTo(2.5, 1e-9));
      expect(r.flourKg, closeTo(125, 1e-9));
      expect(r.waterKg, closeTo(77.5, 1e-9));
      expect(r.yeastKg, closeTo(3, 1e-9));
      expect(r.saltKg, closeTo(2.25, 1e-9));
    });

    test('küçültme: 200 → 100 çarpan 0.5', () {
      final r = calc.scale(oldTarget: 200, newTarget: 100, flourKg: 50);
      expect(r.multiplier, closeTo(0.5, 1e-9));
      expect(r.flourKg, closeTo(25, 1e-9));
    });

    test('bölme riski: eski hedef 0 → çarpan 0 (sonsuz değil)', () {
      final r = calc.scale(oldTarget: 0, newTarget: 250, flourKg: 50);
      expect(r.multiplier.isFinite, isTrue);
      expect(r.multiplier, 0);
      expect(r.flourKg, 0);
    });

    test('0 değer → çarpan 0', () {
      final r = calc.scale(oldTarget: 0, newTarget: 0, flourKg: 0);
      expect(r.multiplier, 0);
      expect(r.flourKg, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.scale(oldTarget: -100, newTarget: -250, flourKg: -50);
      expect(r.multiplier, 0);
      expect(r.flourKg, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.scale(oldTarget: 1, newTarget: 1e9, flourKg: 1e6);
      expect(r.multiplier.isFinite, isTrue);
      expect(r.flourKg.isFinite, isTrue);
    });
  });
}
