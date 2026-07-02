import 'package:firin_defter/features/bakery_panel/calculators/services/daily_close_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = DailyCloseCalculator();

  group('DailyCloseCalculator', () {
    test('normal senaryo → gider 19800, net 5200, %20,8 kâr', () {
      final r = calc.calculate(
        revenue: 25000,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
      );
      expect(r.totalExpense, closeTo(19800, 1e-9));
      expect(r.netProfit, closeTo(5200, 1e-9));
      expect(r.profitMarginPct, closeTo(20.8, 1e-9));
      expect(r.verdict, DailyCloseVerdict.profit);
    });

    test('gider cirodan büyük → loss (net negatif kalır)', () {
      final r = calc.calculate(
        revenue: 15000,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
      );
      expect(r.netProfit, closeTo(-4800, 1e-9));
      expect(r.profitMarginPct, lessThan(0));
      expect(r.verdict, DailyCloseVerdict.loss);
    });

    test('ciro gidere eşit → breakeven', () {
      final r = calc.calculate(
        revenue: 19800,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
      );
      expect(r.netProfit, closeTo(0, 1e-9));
      expect(r.verdict, DailyCloseVerdict.breakeven);
    });

    test('ciro 0 → noRevenue (net = −gider, oran 0)', () {
      final r = calc.calculate(
        revenue: 0,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
      );
      expect(r.netProfit, closeTo(-19800, 1e-9));
      expect(r.profitMarginPct, 0);
      expect(r.verdict, DailyCloseVerdict.noRevenue);
    });

    test('kasa farkı → kasa 24000, ciro 25000 → fark −1000', () {
      final r = calc.calculate(
        revenue: 25000,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
        cashInRegister: 24000,
      );
      expect(r.hasCash, isTrue);
      expect(r.cashDiff, closeTo(-1000, 1e-9));
    });

    test('kasa 0 → hasCash false, fark 0', () {
      final r = calc.calculate(
        revenue: 25000,
        materialCost: 9000,
        staffCost: 6000,
        fixedShare: 2500,
        energyOther: 1500,
        wasteLoss: 800,
      );
      expect(r.hasCash, isFalse);
      expect(r.cashDiff, 0);
    });

    test('negatif → 0\'a normalize (sonuç sonlu)', () {
      final r = calc.calculate(
        revenue: 25000,
        materialCost: -9000,
        staffCost: -6000,
        fixedShare: -2500,
        energyOther: -1500,
        wasteLoss: -800,
        cashInRegister: -24000,
      );
      expect(r.totalExpense, 0);
      expect(r.netProfit, closeTo(25000, 1e-9));
      expect(r.hasCash, isFalse);
      expect(r.netProfit.isFinite, isTrue);
      expect(r.verdict, DailyCloseVerdict.profit);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        revenue: 1e12,
        materialCost: 1e12,
        staffCost: 1e12,
        fixedShare: 1e12,
        energyOther: 1e12,
        wasteLoss: 1e12,
        cashInRegister: 1e12,
      );
      expect(r.totalExpense.isFinite, isTrue);
      expect(r.netProfit.isFinite, isTrue);
      expect(r.profitMarginPct.isFinite, isTrue);
      expect(r.cashDiff.isFinite, isTrue);
    });
  });
}
