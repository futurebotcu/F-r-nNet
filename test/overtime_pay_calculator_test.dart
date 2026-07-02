import 'package:firin_defter/features/bakery_panel/calculators/services/overtime_pay_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = OvertimePayCalculator();

  group('OvertimePayCalculator', () {
    test('normal senaryo → 11 sa / 9 sa / 120 TL / 1.5', () {
      final r = calc.calculate(
        hoursWorked: 11,
        normalHours: 9,
        hourlyWage: 120,
      );
      expect(r.normalPay, closeTo(1080, 1e-9));
      expect(r.overtimeHours, closeTo(2, 1e-9));
      expect(r.overtimePay, closeTo(360, 1e-9));
      expect(r.bonus, 0);
      expect(r.total, closeTo(1440, 1e-9));
      expect(r.bonusStatus, OvertimeBonusStatus.none);
    });

    test('fazla mesai yok → yalnız normal ücret', () {
      final r = calc.calculate(hoursWorked: 8, normalHours: 9, hourlyWage: 120);
      expect(r.overtimeHours, 0);
      expect(r.overtimePay, 0);
      expect(r.normalPay, closeTo(960, 1e-9));
      expect(r.total, closeTo(960, 1e-9));
    });

    test('prim eşiği geçildi → earned + prim toplama eklenir', () {
      final r = calc.calculate(
        hoursWorked: 9,
        normalHours: 9,
        hourlyWage: 120,
        producedCount: 500,
        bonusThreshold: 400,
        bonusAmount: 250,
      );
      expect(r.bonusStatus, OvertimeBonusStatus.earned);
      expect(r.bonus, closeTo(250, 1e-9));
      expect(r.total, closeTo(9 * 120 + 250, 1e-9));
    });

    test('prim eşiği geçilmedi → missed, prim 0', () {
      final r = calc.calculate(
        hoursWorked: 9,
        normalHours: 9,
        hourlyWage: 120,
        producedCount: 300,
        bonusThreshold: 400,
        bonusAmount: 250,
      );
      expect(r.bonusStatus, OvertimeBonusStatus.missed);
      expect(r.bonus, 0);
    });

    test('prim tanımlı değil → none (eşik veya tutar 0)', () {
      final r = calc.calculate(
        hoursWorked: 9,
        normalHours: 9,
        hourlyWage: 120,
        producedCount: 500,
        bonusThreshold: 400,
        bonusAmount: 0,
      );
      expect(r.bonusStatus, OvertimeBonusStatus.none);
      expect(r.bonus, 0);
    });

    test('katsayı < 1 → 1\'e çekilir', () {
      final r = calc.calculate(
        hoursWorked: 11,
        normalHours: 9,
        hourlyWage: 120,
        overtimeMultiplier: 0.5,
      );
      expect(r.overtimePay, closeTo(2 * 120 * 1, 1e-9));
    });

    test('negatif girdiler → normalize + sonlu', () {
      final r = calc.calculate(
        hoursWorked: -11,
        normalHours: -9,
        hourlyWage: -120,
        overtimeMultiplier: -1,
        producedCount: -5,
        bonusThreshold: -10,
        bonusAmount: -100,
      );
      expect(r.normalPay, 0);
      expect(r.overtimeHours, 0);
      expect(r.overtimePay, 0);
      expect(r.bonus, 0);
      expect(r.total, 0);
      expect(r.total.isFinite, isTrue);
      expect(r.bonusStatus, OvertimeBonusStatus.none);
    });

    test('ücret 0 → tüm tutarlar 0 ve sonlu', () {
      final r = calc.calculate(hoursWorked: 11, normalHours: 9, hourlyWage: 0);
      expect(r.normalPay, 0);
      expect(r.overtimePay, 0);
      expect(r.total, 0);
      expect(r.overtimeHours, closeTo(2, 1e-9));
      expect(r.total.isFinite, isTrue);
    });
  });
}
