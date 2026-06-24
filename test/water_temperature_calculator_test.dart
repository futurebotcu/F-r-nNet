import 'package:firin_defter/features/bakery_panel/calculators/services/water_temperature_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = WaterTemperatureCalculator();

  group('WaterTemperatureCalculator', () {
    test('normal: hedef25, un22, oda24, sürtünme3 → 26°C normal', () {
      final r = calc.calculate(
        flourTempC: 22,
        roomTempC: 24,
        targetDoughTempC: 25,
        frictionFactor: 3,
      );
      expect(r.waterTempC, closeTo(26, 1e-9));
      expect(r.band, WaterTempBand.normal);
    });

    test('çok düşük → buzlu su bandı (negatif olabilir)', () {
      final r = calc.calculate(
        flourTempC: 30,
        roomTempC: 30,
        targetDoughTempC: 20,
        frictionFactor: 5,
      );
      expect(r.waterTempC, closeTo(-5, 1e-9));
      expect(r.band, WaterTempBand.iced);
    });

    test('çok yüksek → ılık su bandı', () {
      final r = calc.calculate(
        flourTempC: 0,
        roomTempC: 0,
        targetDoughTempC: 20,
      );
      expect(r.waterTempC, closeTo(60, 1e-9));
      expect(r.band, WaterTempBand.lukewarm);
    });

    test('0 değer → 0°C, sonlu', () {
      final r = calc.calculate(
        flourTempC: 0,
        roomTempC: 0,
        targetDoughTempC: 0,
      );
      expect(r.waterTempC, 0);
      expect(r.waterTempC.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        flourTempC: 1e9,
        roomTempC: 1e9,
        targetDoughTempC: 1e9,
      );
      expect(r.waterTempC.isFinite, isTrue);
    });

    test('eşikler parametreyle değiştirilebilir', () {
      const custom = WaterTemperatureCalculator(
        icedBelow: 0,
        lukewarmAbove: 50,
      );
      final r = custom.calculate(
        flourTempC: 10,
        roomTempC: 10,
        targetDoughTempC: 10,
      );
      // 10*3 - 20 = 10 → normal (custom eşiklerde)
      expect(r.band, WaterTempBand.normal);
    });
  });
}
