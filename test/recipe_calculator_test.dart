import 'package:firin_defter/features/bakery_panel/models/recipe.dart';
import 'package:firin_defter/features/bakery_panel/services/recipe_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = RecipeCalculator();

  group('RecipeCalculator', () {
    test('default brief example: 50 kg / 60 / 1 / 2 / 250 / 3', () {
      const input = RecipeInput.defaults;
      final r = calc.calculate(input);

      // 50 kg unun %60'ı = 30 L su
      expect(r.waterLiters, closeTo(30.0, 1e-9));
      // %1 maya = 0.5 kg
      expect(r.yeastKg, closeTo(0.5, 1e-9));
      // %2 tuz = 1.0 kg
      expect(r.saltKg, closeTo(1.0, 1e-9));
      // 50 + 30 + 0.5 + 1 = 81.5
      expect(r.totalDoughKg, closeTo(81.5, 1e-9));
      // %3 fire → 81.5 * 0.97 = 79.055
      expect(r.doughAfterWasteKg, closeTo(79.055, 1e-6));
      // 79055 g / 250 g = 316.22 → 316 adet
      expect(r.estimatedPieces, 316);
    });

    test('zero flour produces zero output', () {
      final r = calc.calculate(
        const RecipeInput(
          flourKg: 0,
          waterPct: 60,
          yeastPct: 1,
          saltPct: 2,
          pieceWeightG: 250,
          wastePct: 3,
        ),
      );
      expect(r.waterLiters, 0);
      expect(r.totalDoughKg, 0);
      expect(r.estimatedPieces, 0);
    });

    test('100% waste leaves no dough and 0 pieces', () {
      final r = calc.calculate(
        const RecipeInput(
          flourKg: 50,
          waterPct: 60,
          yeastPct: 1,
          saltPct: 2,
          pieceWeightG: 250,
          wastePct: 100,
        ),
      );
      expect(r.doughAfterWasteKg, closeTo(0.0, 1e-9));
      expect(r.estimatedPieces, 0);
    });

    test('larger piece weight reduces estimated pieces', () {
      final small = calc.calculate(
        const RecipeInput(
          flourKg: 50,
          waterPct: 60,
          yeastPct: 1,
          saltPct: 2,
          pieceWeightG: 100,
          wastePct: 3,
        ),
      );
      final big = calc.calculate(
        const RecipeInput(
          flourKg: 50,
          waterPct: 60,
          yeastPct: 1,
          saltPct: 2,
          pieceWeightG: 500,
          wastePct: 3,
        ),
      );
      expect(small.estimatedPieces, greaterThan(big.estimatedPieces));
    });
  });
}
