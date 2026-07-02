import 'package:firin_defter/features/bakery_panel/calculators/services/weight_change_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = WeightChangeCalculator();

  group('WeightChangeCalculator', () {
    test('normal senaryo → 100 kg, 250→240 g: adet artar', () {
      final r = calc.calculate(
        totalDoughKg: 100,
        oldGramsPerPiece: 250,
        newGramsPerPiece: 240,
      );
      expect(r.oldCount, 400);
      expect(r.newCount, 416);
      expect(r.pieceDiff, 16);
      expect(r.pctChangePct, closeTo(4, 1e-9));
      expect(r.hasRevenue, isFalse);
      expect(r.verdict, WeightChangeVerdict.morePieces);
    });

    test('gramaj 0 → invalid (sıfıra bölme yok)', () {
      final r = calc.calculate(
        totalDoughKg: 100,
        oldGramsPerPiece: 0,
        newGramsPerPiece: 240,
      );
      expect(r.verdict, WeightChangeVerdict.invalid);
      expect(r.oldCount, 0);
      expect(r.newCount, 0);
      expect(r.pieceDiff, 0);
      expect(r.pctChangePct, 0);
      expect(r.revenueDiff, 0);
    });

    test('negatif girdiler → normalize + sonlu sonuç', () {
      final r = calc.calculate(
        totalDoughKg: -100,
        oldGramsPerPiece: -250,
        newGramsPerPiece: -240,
        salePrice: -15,
      );
      expect(r.verdict, WeightChangeVerdict.invalid);
      expect(r.pctChangePct.isFinite, isTrue);
      expect(r.revenueDiff.isFinite, isTrue);
      expect(r.hasRevenue, isFalse);
    });

    test('satış fiyatı girilirse ciro farkı hesaplanır', () {
      final r = calc.calculate(
        totalDoughKg: 100,
        oldGramsPerPiece: 250,
        newGramsPerPiece: 240,
        salePrice: 15,
      );
      expect(r.hasRevenue, isTrue);
      expect(r.revenueDiff, closeTo(16 * 15, 1e-9));
    });

    test('gramaj artışı → fewerPieces + negatif fark', () {
      final r = calc.calculate(
        totalDoughKg: 100,
        oldGramsPerPiece: 250,
        newGramsPerPiece: 300,
        salePrice: 15,
      );
      expect(r.oldCount, 400);
      expect(r.newCount, 333);
      expect(r.pieceDiff, lessThan(0));
      expect(r.revenueDiff, lessThan(0));
      expect(r.verdict, WeightChangeVerdict.fewerPieces);
    });

    test('aynı gramaj → same, fark 0', () {
      final r = calc.calculate(
        totalDoughKg: 100,
        oldGramsPerPiece: 250,
        newGramsPerPiece: 250,
      );
      expect(r.pieceDiff, 0);
      expect(r.pctChangePct, 0);
      expect(r.verdict, WeightChangeVerdict.same);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        totalDoughKg: 1e9,
        oldGramsPerPiece: 1,
        newGramsPerPiece: 2,
        salePrice: 1e6,
      );
      expect(r.pctChangePct.isFinite, isTrue);
      expect(r.revenueDiff.isFinite, isTrue);
    });
  });
}
