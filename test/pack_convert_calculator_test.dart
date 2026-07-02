import 'package:firin_defter/features/bakery_panel/calculators/services/pack_convert_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = PackConvertCalculator();

  group('PackConvertCalculator', () {
    test('normal senaryo → 150 adet / 24\'lük koli', () {
      final r = calc.calculate(neededUnits: 150, unitsPerPack: 24);
      expect(r.fullPacks, 6);
      expect(r.remainderUnits, 6);
      expect(r.roundUpPacks, 7);
      expect(r.extraUnits, 18);
      expect(r.verdict, PackConvertVerdict.withRemainder);
    });

    test('tam bölünme → exact, fazla yok', () {
      final r = calc.calculate(neededUnits: 144, unitsPerPack: 24);
      expect(r.fullPacks, 6);
      expect(r.remainderUnits, 0);
      expect(r.roundUpPacks, 6);
      expect(r.extraUnits, 0);
      expect(r.verdict, PackConvertVerdict.exact);
    });

    test('koli içi adet 0 → invalid (sıfıra bölme yok)', () {
      final r = calc.calculate(neededUnits: 150, unitsPerPack: 0);
      expect(r.verdict, PackConvertVerdict.invalid);
      expect(r.fullPacks, 0);
      expect(r.remainderUnits, 0);
      expect(r.roundUpPacks, 0);
      expect(r.extraUnits, 0);
    });

    test('negatif girdiler → normalize → invalid', () {
      final r = calc.calculate(neededUnits: -150, unitsPerPack: -24);
      expect(r.verdict, PackConvertVerdict.invalid);
      expect(r.fullPacks, 0);
      expect(r.extraUnits, 0);
    });

    test('küsuratlı girdi → tam sayıya indirgenir (floor)', () {
      final r = calc.calculate(neededUnits: 150.9, unitsPerPack: 24.9);
      expect(r.fullPacks, 6);
      expect(r.remainderUnits, 6);
      expect(r.roundUpPacks, 7);
    });

    test('büyük değer → sonlu / taşma yok', () {
      final r = calc.calculate(neededUnits: 1e9, unitsPerPack: 24);
      expect(r.fullPacks, greaterThan(0));
      expect(r.extraUnits, greaterThanOrEqualTo(0));
      expect(r.roundUpPacks * 24 - (1e9).floor(), r.extraUnits);
    });
  });
}
