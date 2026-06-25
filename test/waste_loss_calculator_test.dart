import 'package:firin_defter/features/bakery_panel/calculators/services/waste_loss_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = WasteLossCalculator();

  group('WasteLossCalculator', () {
    test('normal senaryo: fire oranı yüksek → high + zarar doğru', () {
      final r = calc.calculate(
        producedCount: 1000,
        soldCount: 850,
        wasteCount: 150,
        costPerUnit: 5,
        salePrice: 7.5,
      );
      expect(r.wasteRatePct, closeTo(15, 1e-9));
      expect(r.costLoss, closeTo(750, 1e-9));
      expect(r.missedSaleValue, closeTo(1125, 1e-9));
      expect(r.verdict, WasteLossVerdict.high);
    });

    test('orta fire → moderate', () {
      final r = calc.calculate(
        producedCount: 1000,
        soldCount: 920,
        wasteCount: 80,
        costPerUnit: 5,
        salePrice: 7.5,
      );
      expect(r.wasteRatePct, closeTo(8, 1e-9));
      expect(r.verdict, WasteLossVerdict.moderate);
    });

    test('düşük fire → low', () {
      final r = calc.calculate(
        producedCount: 1000,
        soldCount: 970,
        wasteCount: 30,
        costPerUnit: 5,
        salePrice: 7.5,
      );
      expect(r.wasteRatePct, closeTo(3, 1e-9));
      expect(r.verdict, WasteLossVerdict.low);
    });

    test('bölme riski: üretilen 0 → oran sonlu (0)', () {
      final r = calc.calculate(
        producedCount: 0,
        soldCount: 0,
        wasteCount: 0,
        costPerUnit: 5,
        salePrice: 7.5,
      );
      expect(r.wasteRatePct.isFinite, isTrue);
      expect(r.wasteRatePct, 0);
      expect(r.verdict, WasteLossVerdict.low);
    });

    test('fire üretileni aşamaz (clamp)', () {
      final r = calc.calculate(
        producedCount: 1000,
        soldCount: 0,
        wasteCount: 2000,
        costPerUnit: 5,
        salePrice: 7.5,
      );
      expect(r.wasteCount, closeTo(1000, 1e-9));
      expect(r.wasteRatePct, closeTo(100, 1e-9));
      expect(r.verdict, WasteLossVerdict.high);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        producedCount: -1000,
        soldCount: -900,
        wasteCount: -100,
        costPerUnit: -5,
        salePrice: -7.5,
      );
      expect(r.wasteCount, 0);
      expect(r.costLoss, 0);
      expect(r.missedSaleValue, 0);
      expect(r.wasteRatePct.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        producedCount: 1e9,
        soldCount: 0,
        wasteCount: 1e9,
        costPerUnit: 1e6,
        salePrice: 1e6,
      );
      expect(r.costLoss.isFinite, isTrue);
      expect(r.missedSaleValue.isFinite, isTrue);
    });
  });
}
