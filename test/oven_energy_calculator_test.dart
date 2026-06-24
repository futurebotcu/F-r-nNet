import 'package:firin_defter/features/bakery_panel/calculators/services/oven_energy_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = OvenEnergyCalculator();

  group('OvenEnergyCalculator', () {
    test('normal: 18kW × 6h × 3.5 → 378₺, 500 adet → 0.756/adet', () {
      final r = calc.calculate(
        powerKw: 18,
        hours: 6,
        unitPrice: 3.5,
        pieces: 500,
      );
      expect(r.energyKwh, closeTo(108, 1e-9));
      expect(r.totalEnergyCost, closeTo(378, 1e-9));
      expect(r.costPerUnit, closeTo(0.756, 1e-9));
    });

    test('bölme riski: adet 0 → ürün başı 0 (sonsuz değil)', () {
      final r = calc.calculate(powerKw: 18, hours: 6, unitPrice: 3.5);
      expect(r.costPerUnit.isFinite, isTrue);
      expect(r.costPerUnit, 0);
      expect(r.totalEnergyCost, closeTo(378, 1e-9));
    });

    test('0 değer → 0', () {
      final r = calc.calculate(powerKw: 0, hours: 0, unitPrice: 0);
      expect(r.totalEnergyCost, 0);
      expect(r.energyKwh, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(powerKw: -18, hours: -6, unitPrice: -3.5);
      expect(r.totalEnergyCost, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(powerKw: 1e6, hours: 1e6, unitPrice: 1e6);
      expect(r.totalEnergyCost.isFinite, isTrue);
    });
  });
}
