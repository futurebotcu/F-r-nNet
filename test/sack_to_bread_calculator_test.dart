import 'package:firin_defter/features/bakery_panel/calculators/services/sack_to_bread_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = SackToBreadCalculator();

  group('SackToBreadCalculator', () {
    test('normal: 1 çuval 50kg, %60 su, 500g, fire yok → 160 adet', () {
      final r = calc.calculate(
        sackCount: 1,
        sackKg: 50,
        waterAbsorptionPct: 60,
        breadDoughG: 500,
      );
      expect(r.totalFlourKg, 50);
      expect(r.estimatedDoughKg, closeTo(80, 1e-9));
      expect(r.netDoughKg, closeTo(80, 1e-9));
      expect(r.estimatedPieces, 160);
    });

    test('fire %3 → adet düşer', () {
      final r = calc.calculate(
        sackCount: 1,
        sackKg: 50,
        waterAbsorptionPct: 60,
        breadDoughG: 500,
        wastePct: 3,
      );
      expect(r.estimatedPieces, 155);
    });

    test('0 değer → 0 adet', () {
      final r = calc.calculate(sackCount: 0, breadDoughG: 500);
      expect(r.totalFlourKg, 0);
      expect(r.estimatedPieces, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        sackCount: -5,
        sackKg: -50,
        waterAbsorptionPct: -10,
        breadDoughG: 500,
      );
      expect(r.totalFlourKg, 0);
      expect(r.estimatedPieces, 0);
    });

    test('bölme riski: 0 gramaj → adet sonlu', () {
      final r = calc.calculate(sackCount: 1, breadDoughG: 0);
      expect(r.estimatedPieces.isFinite, isTrue);
    });

    test('çok büyük değer → sonuç sonlu', () {
      final r = calc.calculate(
        sackCount: 1e6,
        sackKg: 50,
        waterAbsorptionPct: 60,
        breadDoughG: 500,
      );
      expect(r.totalFlourKg.isFinite, isTrue);
      expect(r.estimatedPieces.isFinite, isTrue);
    });
  });
}
