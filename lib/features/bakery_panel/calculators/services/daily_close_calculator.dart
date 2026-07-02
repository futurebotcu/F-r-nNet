import 'calc_safety.dart';

/// Günlük kapanış yorumu.
///
/// Öncelik sırası: ciro yoksa hesap yapılamaz → başa baş → zarar → kâr.
enum DailyCloseVerdict { noRevenue, loss, breakeven, profit }

/// "Günlük Kapanış (Kâr / Zarar)" sonucu.
class DailyCloseResult {
  const DailyCloseResult({
    required this.totalExpense,
    required this.netProfit,
    required this.profitMarginPct,
    required this.hasCash,
    required this.cashDiff,
    required this.verdict,
  });

  /// Beş gider kaleminin toplamı (malzeme + personel + sabit pay +
  /// enerji/diğer + bayat/fire).
  final double totalExpense;

  /// Tahmini net kâr = ciro − gider toplamı (negatifse zarar göstergesidir,
  /// 0'a kırpılmaz).
  final double netProfit;

  /// Kâr oranı = net kâr / ciro × 100 (ciro yoksa 0).
  final double profitMarginPct;

  /// Kasadaki para girildi mi (> 0)?
  final bool hasCash;

  /// Kasa farkı = kasadaki para − ciro (kasa girilmediyse 0).
  final double cashDiff;

  final DailyCloseVerdict verdict;
}

/// Akşam kapanışta günün kaba kâr/zarar durumunu hesaplar (saf Dart).
///
/// Kayıt tutmaz; yalnız girilen ciro ve gider kalemlerinden tahmini net
/// kârı çıkarır. Ciro 0 ise [DailyCloseVerdict.noRevenue] döner.
/// NaN / Infinity / sıfıra bölme üretmez; negatifler 0'a normalize edilir.
class DailyCloseCalculator {
  const DailyCloseCalculator();

  DailyCloseResult calculate({
    required double revenue,
    required double materialCost,
    required double staffCost,
    required double fixedShare,
    required double energyOther,
    required double wasteLoss,
    double cashInRegister = 0,
  }) {
    final rev = nonNeg(revenue);
    final material = nonNeg(materialCost);
    final staff = nonNeg(staffCost);
    final fixed = nonNeg(fixedShare);
    final energy = nonNeg(energyOther);
    final waste = nonNeg(wasteLoss);
    final cash = nonNeg(cashInRegister);

    final totalExpense = material + staff + fixed + energy + waste;
    final hasCash = cash > 0;
    final cashDiff = hasCash ? cash - rev : 0.0;

    if (rev <= 0) {
      return DailyCloseResult(
        totalExpense: finiteOrZero(totalExpense),
        netProfit: finiteOrZero(-totalExpense),
        profitMarginPct: 0,
        hasCash: hasCash,
        cashDiff: finiteOrZero(cashDiff),
        verdict: DailyCloseVerdict.noRevenue,
      );
    }

    final netProfit = finiteOrZero(rev - totalExpense);
    final profitMarginPct = safeDiv(netProfit, rev) * 100;

    final DailyCloseVerdict verdict;
    if (netProfit.abs() < 0.005) {
      verdict = DailyCloseVerdict.breakeven;
    } else if (netProfit < 0) {
      verdict = DailyCloseVerdict.loss;
    } else {
      verdict = DailyCloseVerdict.profit;
    }

    return DailyCloseResult(
      totalExpense: finiteOrZero(totalExpense),
      netProfit: netProfit,
      profitMarginPct: finiteOrZero(profitMarginPct),
      hasCash: hasCash,
      cashDiff: finiteOrZero(cashDiff),
      verdict: verdict,
    );
  }
}
