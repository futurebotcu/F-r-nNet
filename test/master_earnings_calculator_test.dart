import 'package:firin_defter/features/bakery_panel/calculators/services/master_earnings_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = MasterEarningsCalculator();

  group('MasterEarningsCalculator', () {
    test('normal senaryo → 12×90 prim, kesinti yok, net 1080', () {
      final r = calc.calculate(unitsProcessed: 12, ratePerUnit: 90);
      expect(r.bonusTotal, closeTo(1080, 1e-9));
      expect(r.gross, closeTo(1080, 1e-9));
      expect(r.net, closeTo(1080, 1e-9));
      expect(r.verdict, MasterEarningsVerdict.ok);
    });

    test('sabit günlük ücretli senaryo → prim + sabit', () {
      final r = calc.calculate(
        unitsProcessed: 10,
        ratePerUnit: 50,
        fixedDaily: 600,
      );
      expect(r.bonusTotal, closeTo(500, 1e-9));
      expect(r.gross, closeTo(1100, 1e-9));
      expect(r.net, closeTo(1100, 1e-9));
      expect(r.verdict, MasterEarningsVerdict.ok);
    });

    test('kesinti/avans netten düşer', () {
      final r = calc.calculate(
        unitsProcessed: 12,
        ratePerUnit: 90,
        deduction: 200,
      );
      expect(r.gross, closeTo(1080, 1e-9));
      expect(r.net, closeTo(880, 1e-9));
      expect(r.verdict, MasterEarningsVerdict.ok);
    });

    test('kesinti hak edişi aşarsa → net 0 + deductionExceeds', () {
      final r = calc.calculate(
        unitsProcessed: 5,
        ratePerUnit: 100,
        deduction: 800,
      );
      expect(r.gross, closeTo(500, 1e-9));
      expect(r.net, 0);
      expect(r.verdict, MasterEarningsVerdict.deductionExceeds);
    });

    test('hepsi 0 → invalid (brüt hak ediş yok)', () {
      final r = calc.calculate(unitsProcessed: 0, ratePerUnit: 0);
      expect(r.bonusTotal, 0);
      expect(r.gross, 0);
      expect(r.net, 0);
      expect(r.verdict, MasterEarningsVerdict.invalid);
    });

    test('negatif → 0\'a normalize (sonuç sonlu)', () {
      final r = calc.calculate(
        unitsProcessed: -12,
        ratePerUnit: 90,
        fixedDaily: 500,
        deduction: -100,
      );
      expect(r.bonusTotal, 0);
      expect(r.gross, closeTo(500, 1e-9));
      expect(r.net, closeTo(500, 1e-9));
      expect(r.net.isFinite, isTrue);
      expect(r.verdict, MasterEarningsVerdict.ok);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        unitsProcessed: 1e9,
        ratePerUnit: 1e6,
        fixedDaily: 1e9,
        deduction: 1e6,
      );
      expect(r.bonusTotal.isFinite, isTrue);
      expect(r.gross.isFinite, isTrue);
      expect(r.net.isFinite, isTrue);
    });
  });
}
