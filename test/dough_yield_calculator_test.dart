import 'package:firin_defter/features/bakery_panel/calculators/services/dough_yield_calculator.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_metadata.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_quantities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = DoughYieldCalculator();

  group('DoughYieldCalculator (calculateFromQuantities delegasyonu)', () {
    test('briefteki örnek: 50/30/0.5/1/250/2.445 → 316 adet', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
        wasteKg: 2.445,
      );
      final r = calc.calculate(q);
      expect(r.totalDoughKg, 81.5);
      expect(r.doughAfterWasteKg, closeTo(79.055, 1e-9));
      expect(r.estimatedPieces, 316);
    });

    test('fire boş (0) → toplam hamur olduğu gibi alınır', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
      );
      final r = calc.calculate(q);
      expect(r.doughAfterWasteKg, 81.5);
      expect(r.estimatedPieces, 326);
    });

    test('extras kg toplam hamuru artırır', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
      );
      const extras = <RecipeIngredient>[
        RecipeIngredient(name: 'Yağ', amount: 2, unit: 'kg'),
      ];
      final r = calc.calculate(q, extras: extras);
      expect(r.totalDoughKg, 83.5);
    });

    group('edge cases — NaN/Infinity/sıfıra bölme oluşmaz', () {
      test('0 gramaj → piece min 1\'e clamp, sonuç sonlu', () {
        const q = RecipeQuantities(
          flourKg: 1,
          waterKg: 0,
          yeastKg: 0,
          saltKg: 0,
          pieceWeightG: 0,
        );
        final r = calc.calculate(q);
        expect(r.estimatedPieces.isFinite, isTrue);
        expect(r.estimatedPieces, greaterThanOrEqualTo(0));
      });

      test('negatif değerler 0\'a clamp → 0 sonuç', () {
        const q = RecipeQuantities(
          flourKg: -10,
          waterKg: -5,
          yeastKg: -1,
          saltKg: -1,
          pieceWeightG: 250,
          wasteKg: -3,
        );
        final r = calc.calculate(q);
        expect(r.totalDoughKg, 0);
        expect(r.estimatedPieces, 0);
      });

      test('boş/sıfır giriş → 0 adet', () {
        const q = RecipeQuantities(
          flourKg: 0,
          waterKg: 0,
          yeastKg: 0,
          saltKg: 0,
          pieceWeightG: 250,
        );
        final r = calc.calculate(q);
        expect(r.estimatedPieces, 0);
      });

      test('fire toplamdan büyük → net 0, negatif olmaz', () {
        const q = RecipeQuantities(
          flourKg: 1,
          waterKg: 0,
          yeastKg: 0,
          saltKg: 0,
          pieceWeightG: 100,
          wasteKg: 999,
        );
        final r = calc.calculate(q);
        expect(r.doughAfterWasteKg, 0);
        expect(r.estimatedPieces, 0);
      });

      test('çok büyük sayı → sonuç sonlu (taşmaz)', () {
        const q = RecipeQuantities(
          flourKg: 1e9,
          waterKg: 1e9,
          yeastKg: 0,
          saltKg: 0,
          pieceWeightG: 250,
        );
        final r = calc.calculate(q);
        expect(r.totalDoughKg.isFinite, isTrue);
        expect(r.estimatedPieces.isFinite, isTrue);
      });
    });
  });
}
