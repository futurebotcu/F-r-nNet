import 'package:firin_defter/features/bakery_panel/calculators/services/flat_deal_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = FlatDealCalculator();

  group('FlatDealCalculator', () {
    test('normal senaryo → silinen tutar + gerçek iskonto', () {
      final r = calc.calculate(invoiceAmount: 12750, offeredAmount: 12000);
      expect(r.savedAmount, closeTo(750, 1e-9));
      expect(r.discountPct, closeTo(5.88, 0.01));
      expect(r.verdict, FlatDealVerdict.discount);
    });

    test('teklif = fatura → noGain', () {
      final r = calc.calculate(invoiceAmount: 12750, offeredAmount: 12750);
      expect(r.savedAmount, 0);
      expect(r.discountPct, 0);
      expect(r.verdict, FlatDealVerdict.noGain);
    });

    test('teklif > fatura → noGain (kazanç yok)', () {
      final r = calc.calculate(invoiceAmount: 12000, offeredAmount: 12750);
      expect(r.savedAmount, lessThanOrEqualTo(0));
      expect(r.verdict, FlatDealVerdict.noGain);
    });

    test('fatura 0 → invalid', () {
      final r = calc.calculate(invoiceAmount: 0, offeredAmount: 12000);
      expect(r.verdict, FlatDealVerdict.invalid);
      expect(r.savedAmount, 0);
      expect(r.discountPct, 0);
    });

    test('negatif → 0\'a normalize (fatura negatif → invalid)', () {
      final r = calc.calculate(invoiceAmount: -12750, offeredAmount: -12000);
      expect(r.verdict, FlatDealVerdict.invalid);
      expect(r.savedAmount.isFinite, isTrue);
      expect(r.discountPct.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(invoiceAmount: 1e12, offeredAmount: 1);
      expect(r.savedAmount.isFinite, isTrue);
      expect(r.discountPct.isFinite, isTrue);
      expect(r.verdict, FlatDealVerdict.discount);
    });
  });
}
