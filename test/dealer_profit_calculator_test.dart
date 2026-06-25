import 'package:firin_defter/features/bakery_panel/calculators/services/dealer_profit_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = DealerProfitCalculator();

  group('DealerProfitCalculator', () {
    test('normal senaryo: kârlı bayi', () {
      final r = calc.calculate(
        dailyUnits: 100,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 0,
        distributionCost: 0,
      );
      expect(r.dailyRevenue, closeTo(700, 1e-9));
      expect(r.netProfit, closeTo(200, 1e-9));
      expect(r.verdict, DealerProfitVerdict.profitable);
    });

    test('iade oranı yüksek → highReturns', () {
      final r = calc.calculate(
        dailyUnits: 100,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 20,
        distributionCost: 0,
      );
      // sold 80 → ciro 560, maliyet 500, net 60 (>0); iade %20 ≥ 15
      expect(r.netProfit, closeTo(60, 1e-9));
      expect(r.returnRatePct, closeTo(20, 1e-9));
      expect(r.verdict, DealerProfitVerdict.highReturns);
    });

    test('dağıtımla sınırda → marginal', () {
      final r = calc.calculate(
        dailyUnits: 100,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 0,
        distributionCost: 180,
      );
      // net = 700 - 500 - 180 = 20 → marj %2.86 < 8
      expect(r.netProfit, closeTo(20, 1e-9));
      expect(r.verdict, DealerProfitVerdict.marginal);
    });

    test('zarar senaryosu: dağıtım kârı yer → lossy', () {
      final r = calc.calculate(
        dailyUnits: 100,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 0,
        distributionCost: 300,
      );
      expect(r.netProfit, lessThan(0));
      expect(r.verdict, DealerProfitVerdict.lossy);
    });

    test('bölme riski: adet 0 → marj/iade oranı sonlu', () {
      final r = calc.calculate(
        dailyUnits: 0,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 0,
        distributionCost: 0,
      );
      expect(r.profitMarginPct.isFinite, isTrue);
      expect(r.returnRatePct.isFinite, isTrue);
      expect(r.profitMarginPct, 0);
    });

    test('iade verilen adedi aşamaz (clamp)', () {
      final r = calc.calculate(
        dailyUnits: 100,
        dealerSalePrice: 7,
        costPerUnit: 5,
        dailyReturns: 200,
        distributionCost: 0,
      );
      // returns → 100, sold 0, ciro 0, net = -500 → lossy
      expect(r.returnRatePct, closeTo(100, 1e-9));
      expect(r.verdict, DealerProfitVerdict.lossy);
    });

    test('negatif → 0\'a normalize', () {
      final r = calc.calculate(
        dailyUnits: -100,
        dealerSalePrice: -7,
        costPerUnit: -5,
        dailyReturns: -20,
        distributionCost: -50,
      );
      expect(r.dailyRevenue, 0);
      expect(r.netProfit, 0);
      expect(r.returnRatePct.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        dailyUnits: 1e6,
        dealerSalePrice: 1e6,
        costPerUnit: 1,
        dailyReturns: 0,
        distributionCost: 0,
      );
      expect(r.dailyRevenue.isFinite, isTrue);
      expect(r.netProfit.isFinite, isTrue);
    });
  });
}
