import 'package:firin_defter/features/bakery_panel/calculators/services/flour_price_hike_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FlourPriceHikeCalculator();

  group('FlourPriceHikeCalculator', () {
    test('normal: 1000→1150, 8 çuval/gün → günlük 1200, aylık 36000', () {
      final r = calc.calculate(
        oldSackPrice: 1000,
        newSackPrice: 1150,
        dailySacks: 8,
      );
      expect(r.perSackDiff, closeTo(150, 1e-9));
      expect(r.dailyExtraCost, closeTo(1200, 1e-9));
      expect(r.monthlyExtraCost, closeTo(36000, 1e-9));
    });

    test('fiyat düşerse fark negatif (tasarruf)', () {
      final r = calc.calculate(
        oldSackPrice: 1200,
        newSackPrice: 1000,
        dailySacks: 5,
      );
      expect(r.perSackDiff, closeTo(-200, 1e-9));
      expect(r.dailyExtraCost, closeTo(-1000, 1e-9));
    });

    test('0 değer → 0', () {
      final r = calc.calculate(oldSackPrice: 0, newSackPrice: 0, dailySacks: 0);
      expect(r.dailyExtraCost, 0);
      expect(r.monthlyExtraCost, 0);
    });

    test('negatif fiyat → 0\'a normalize', () {
      final r = calc.calculate(
        oldSackPrice: -1000,
        newSackPrice: -1150,
        dailySacks: -8,
      );
      expect(r.dailyExtraCost, 0);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        oldSackPrice: 1e9,
        newSackPrice: 2e9,
        dailySacks: 1e6,
      );
      expect(r.dailyExtraCost.isFinite, isTrue);
      expect(r.monthlyExtraCost.isFinite, isTrue);
    });
  });
}
