import 'package:firin_defter/features/bakery_panel/calculators/services/tip_split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = TipSplitCalculator();

  group('TipSplitCalculator', () {
    test('normal senaryo → 50/30/20 tam dağıtım, kalan 0', () {
      final r = calc.calculate(
        totalAmount: 3000,
        productionPct: 50,
        counterPct: 30,
        apprenticePct: 20,
      );
      expect(r.productionShare, closeTo(1500, 1e-9));
      expect(r.counterShare, closeTo(900, 1e-9));
      expect(r.apprenticeShare, closeTo(600, 1e-9));
      expect(r.remainder, closeTo(0, 1e-9));
      expect(r.sumPct, closeTo(100, 1e-9));
      expect(r.verdict, TipSplitVerdict.ok);
    });

    test('yüzdeler 90 → pctMismatch + kalan tutar açıkta', () {
      final r = calc.calculate(
        totalAmount: 3000,
        productionPct: 50,
        counterPct: 30,
        apprenticePct: 10,
      );
      expect(r.sumPct, closeTo(90, 1e-9));
      expect(r.remainder, closeTo(300, 1e-9));
      expect(r.verdict, TipSplitVerdict.pctMismatch);
    });

    test('yüzdeler 110 → pctMismatch + negatif kalan (fazla dağıtım)', () {
      final r = calc.calculate(
        totalAmount: 3000,
        productionPct: 50,
        counterPct: 40,
        apprenticePct: 20,
      );
      expect(r.sumPct, closeTo(110, 1e-9));
      expect(r.remainder, closeTo(-300, 1e-9));
      expect(r.verdict, TipSplitVerdict.pctMismatch);
    });

    test('toplam tutar 0 → invalid', () {
      final r = calc.calculate(
        totalAmount: 0,
        productionPct: 50,
        counterPct: 30,
        apprenticePct: 20,
      );
      expect(r.productionShare, 0);
      expect(r.counterShare, 0);
      expect(r.apprenticeShare, 0);
      expect(r.verdict, TipSplitVerdict.invalid);
    });

    test('yüzde toplamı 0 → invalid', () {
      final r = calc.calculate(
        totalAmount: 3000,
        productionPct: 0,
        counterPct: 0,
        apprenticePct: 0,
      );
      expect(r.verdict, TipSplitVerdict.invalid);
    });

    test('negatif → 0\'a normalize (sonuç sonlu)', () {
      final r = calc.calculate(
        totalAmount: 3000,
        productionPct: -50,
        counterPct: 30,
        apprenticePct: 20,
      );
      expect(r.productionShare, 0);
      expect(r.sumPct, closeTo(50, 1e-9));
      expect(r.remainder.isFinite, isTrue);
      expect(r.verdict, TipSplitVerdict.pctMismatch);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        totalAmount: 1e12,
        productionPct: 50,
        counterPct: 30,
        apprenticePct: 20,
      );
      expect(r.productionShare.isFinite, isTrue);
      expect(r.counterShare.isFinite, isTrue);
      expect(r.apprenticeShare.isFinite, isTrue);
      expect(r.remainder.isFinite, isTrue);
    });
  });
}
