import 'package:firin_defter/features/bakery_panel/calculators/services/free_goods_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FreeGoodsCalculator();

  group('FreeGoodsCalculator', () {
    test('normal: 10 al 1 bedelsiz, çuval 1000₺', () {
      final r = calc.calculate(
        normalUnitPrice: 1000,
        purchasedCount: 10,
        freeCount: 1,
      );
      expect(r.realUnitPrice, closeTo(10000 / 11, 1e-6));
      expect(r.totalAdvantage, closeTo(1000, 1e-9));
      expect(r.discountPct, closeTo(100 / 11, 1e-6));
    });

    test('bedelsiz yok → gerçek fiyat = normal, indirim 0', () {
      final r = calc.calculate(
        normalUnitPrice: 1000,
        purchasedCount: 10,
        freeCount: 0,
      );
      expect(r.realUnitPrice, closeTo(1000, 1e-9));
      expect(r.discountPct, closeTo(0, 1e-9));
    });

    test('bölme riski: hiç ürün gelmemiş → gerçek fiyat 0 (sonsuz değil)', () {
      final r = calc.calculate(
        normalUnitPrice: 1000,
        purchasedCount: 0,
        freeCount: 0,
      );
      expect(r.realUnitPrice.isFinite, isTrue);
      expect(r.realUnitPrice, 0);
    });

    test('0 değer → 0', () {
      final r = calc.calculate(
        normalUnitPrice: 0,
        purchasedCount: 0,
        freeCount: 0,
      );
      expect(r.realUnitPrice, 0);
      expect(r.totalAdvantage, 0);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        normalUnitPrice: -1000,
        purchasedCount: -10,
        freeCount: -1,
      );
      expect(r.realUnitPrice, 0);
      expect(r.totalAdvantage, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        normalUnitPrice: 1e9,
        purchasedCount: 1e6,
        freeCount: 1e5,
      );
      expect(r.realUnitPrice.isFinite, isTrue);
      expect(r.discountPct.isFinite, isTrue);
    });
  });
}
