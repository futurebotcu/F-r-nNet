import 'package:firin_defter/features/bakery_panel/calculators/services/oven_capacity_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = OvenCapacityCalculator();

  group('OvenCapacityCalculator', () {
    test('normal senaryo → tur + azami ürün + saatlik kapasite', () {
      final r = calc.calculate(
        trayCount: 8,
        piecesPerTray: 30,
        bakeMinutes: 25,
        dailyHours: 10,
        loadUnloadMinutes: 5,
      );
      expect(r.cycleMinutes, closeTo(30, 1e-9));
      expect(r.cyclesPerDay, 20);
      expect(r.maxDailyPieces, 4800);
      expect(r.hourlyCapacity, closeTo(480, 1e-9));
      expect(r.verdict, OvenCapacityVerdict.ok);
    });

    test('yükleme/boşaltma 0 → tur süresi = pişirme süresi', () {
      final r = calc.calculate(
        trayCount: 8,
        piecesPerTray: 30,
        bakeMinutes: 25,
        dailyHours: 10,
      );
      expect(r.cycleMinutes, closeTo(25, 1e-9));
      expect(r.cyclesPerDay, 24);
      expect(r.maxDailyPieces, 5760);
      expect(r.verdict, OvenCapacityVerdict.ok);
    });

    test('pişirme süresi mesaiye sığmıyor → noCycle (kapasite 0)', () {
      final r = calc.calculate(
        trayCount: 8,
        piecesPerTray: 30,
        bakeMinutes: 700,
        dailyHours: 10,
      );
      expect(r.cyclesPerDay, 0);
      expect(r.maxDailyPieces, 0);
      expect(r.hourlyCapacity, 0);
      expect(r.verdict, OvenCapacityVerdict.noCycle);
    });

    test('tepsi 0 → invalid', () {
      final r = calc.calculate(
        trayCount: 0,
        piecesPerTray: 30,
        bakeMinutes: 25,
        dailyHours: 10,
      );
      expect(r.verdict, OvenCapacityVerdict.invalid);
      expect(r.maxDailyPieces, 0);
    });

    test('negatif → 0\'a normalize (invalid, sonuç sonlu)', () {
      final r = calc.calculate(
        trayCount: -8,
        piecesPerTray: -30,
        bakeMinutes: -25,
        dailyHours: -10,
        loadUnloadMinutes: -5,
      );
      expect(r.verdict, OvenCapacityVerdict.invalid);
      expect(r.hourlyCapacity.isFinite, isTrue);
      expect(r.cycleMinutes.isFinite, isTrue);
    });

    test('çok büyük değer → sonlu', () {
      final r = calc.calculate(
        trayCount: 1e6,
        piecesPerTray: 1e6,
        bakeMinutes: 1,
        dailyHours: 1e6,
      );
      expect(r.hourlyCapacity.isFinite, isTrue);
      expect(r.cycleMinutes.isFinite, isTrue);
      expect(r.maxDailyPieces, isNonNegative);
    });
  });
}
