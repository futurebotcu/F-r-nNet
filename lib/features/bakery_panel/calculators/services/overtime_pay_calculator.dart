import 'dart:math' as math;

import 'calc_safety.dart';

/// Prim durumu: tanımlı değil, hak edildi, eşik geçilemedi.
enum OvertimeBonusStatus { none, earned, missed }

/// "Mesai + Prim Hesaplayıcı" sonucu.
class OvertimePayResult {
  const OvertimePayResult({
    required this.normalPay,
    required this.overtimeHours,
    required this.overtimePay,
    required this.bonus,
    required this.total,
    required this.bonusStatus,
  });

  /// Normal mesai karşılığı ücret (TL).
  final double normalPay;

  /// Normal mesaiyi aşan saat.
  final double overtimeHours;

  /// Fazla mesai karşılığı ücret (katsayılı, TL).
  final double overtimePay;

  /// Hak edilen prim (TL); eşik geçilmediyse 0.
  final double bonus;

  /// Toplam tahmini hak ediş = normal + fazla mesai + prim.
  final double total;

  final OvertimeBonusStatus bonusStatus;
}

/// Günlük çalışma saatine göre normal ücret, fazla mesai ve üretim primini
/// hesaplar (saf Dart).
///
/// Bu tahmini bir hesaptır; resmî bordro yerine geçmez. Fazla mesai
/// katsayısı en az 1'e çekilir. Prim, eşik ve tutar birlikte girildiyse
/// hesaba katılır. NaN / Infinity üretmez; negatifler 0'a normalize edilir.
class OvertimePayCalculator {
  const OvertimePayCalculator();

  OvertimePayResult calculate({
    required double hoursWorked,
    required double normalHours,
    required double hourlyWage,
    double overtimeMultiplier = 1.5,
    double producedCount = 0,
    double bonusThreshold = 0,
    double bonusAmount = 0,
  }) {
    final hours = nonNeg(hoursWorked);
    final normal = nonNeg(normalHours);
    final wage = nonNeg(hourlyWage);
    final multiplier = atLeast(overtimeMultiplier, 1);
    final produced = nonNeg(producedCount);
    final threshold = nonNeg(bonusThreshold);
    final amount = nonNeg(bonusAmount);

    final paidNormalHours = math.min(hours, normal);
    final overtimeHours = math.max(0.0, hours - normal);
    final normalPay = paidNormalHours * wage;
    final overtimePay = overtimeHours * wage * multiplier;

    final bonusConfigured = threshold > 0 && amount > 0;
    final bonusEarned = bonusConfigured && produced >= threshold;
    final bonus = bonusEarned ? amount : 0.0;

    final OvertimeBonusStatus bonusStatus;
    if (!bonusConfigured) {
      bonusStatus = OvertimeBonusStatus.none;
    } else if (bonusEarned) {
      bonusStatus = OvertimeBonusStatus.earned;
    } else {
      bonusStatus = OvertimeBonusStatus.missed;
    }

    final total = normalPay + overtimePay + bonus;

    return OvertimePayResult(
      normalPay: finiteOrZero(normalPay),
      overtimeHours: finiteOrZero(overtimeHours),
      overtimePay: finiteOrZero(overtimePay),
      bonus: finiteOrZero(bonus),
      total: finiteOrZero(total),
      bonusStatus: bonusStatus,
    );
  }
}
