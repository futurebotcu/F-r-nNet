import 'package:firin_defter/features/bakery_panel/calculators/services/stock_runway_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = StockRunwayCalculator();

  group('StockRunwayCalculator', () {
    test('normal senaryo → yeterlilik + sipariş günü + güvenli', () {
      final r = calc.calculate(
        currentStock: 600,
        dailyUsage: 100,
        leadTimeDays: 2,
        safetyStockDays: 1,
      );
      expect(r.daysOfCover, closeTo(6, 1e-9));
      expect(r.orderInDays, closeTo(3, 1e-9));
      expect(r.verdict, StockRunwayVerdict.ok);
    });

    test('tüketim 0 → noUsage (hesaplanamaz, sonsuz değil)', () {
      final r = calc.calculate(
        currentStock: 600,
        dailyUsage: 0,
        leadTimeDays: 2,
        safetyStockDays: 1,
      );
      expect(r.verdict, StockRunwayVerdict.noUsage);
      expect(r.daysOfCover, 0);
      expect(r.daysOfCover.isFinite, isTrue);
    });

    test('sipariş zamanı geçti → orderNow', () {
      final r = calc.calculate(
        currentStock: 100,
        dailyUsage: 100,
        leadTimeDays: 2,
        safetyStockDays: 1,
      );
      expect(r.orderInDays, lessThanOrEqualTo(0));
      expect(r.verdict, StockRunwayVerdict.orderNow);
    });

    test('3 günden az yeterlilik → critical', () {
      final r = calc.calculate(
        currentStock: 250,
        dailyUsage: 100,
        leadTimeDays: 0,
        safetyStockDays: 0,
      );
      expect(r.daysOfCover, closeTo(2.5, 1e-9));
      expect(r.verdict, StockRunwayVerdict.critical);
    });

    test('yarın sipariş ver → orderSoon', () {
      final r = calc.calculate(
        currentStock: 400,
        dailyUsage: 100,
        leadTimeDays: 3,
        safetyStockDays: 0,
      );
      expect(r.orderInDays, closeTo(1, 1e-9));
      expect(r.verdict, StockRunwayVerdict.orderSoon);
    });

    test('negatif → 0\'a normalize (stok negatif, sonuç sonlu)', () {
      final r = calc.calculate(
        currentStock: -100,
        dailyUsage: 100,
        leadTimeDays: -2,
        safetyStockDays: -1,
      );
      expect(r.daysOfCover, 0);
      expect(r.daysOfCover.isFinite, isTrue);
      expect(r.orderInDays.isFinite, isTrue);
      expect(r.verdict, StockRunwayVerdict.orderNow);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        currentStock: 1e9,
        dailyUsage: 1,
        leadTimeDays: 1,
        safetyStockDays: 1,
      );
      expect(r.daysOfCover.isFinite, isTrue);
      expect(r.orderInDays.isFinite, isTrue);
    });
  });
}
