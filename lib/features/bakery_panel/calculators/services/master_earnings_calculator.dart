import 'calc_safety.dart';

/// Usta hak ediş yorumu.
///
/// Öncelik sırası: brüt hak ediş yoksa hesap yapılamaz → kesinti hak edişi
/// aşıyor → hak ediş hazır.
enum MasterEarningsVerdict { invalid, deductionExceeds, ok }

/// "Usta Hak Ediş Hesabı" sonucu.
class MasterEarningsResult {
  const MasterEarningsResult({
    required this.bonusTotal,
    required this.gross,
    required this.net,
    required this.verdict,
  });

  /// Prim toplamı = işlenen çuval/parti × birim prim.
  final double bonusTotal;

  /// Brüt hak ediş = prim toplamı + sabit günlük ücret.
  final double gross;

  /// Net hak ediş = brüt − kesinti/avans (negatifse 0'a kırpılır).
  final double net;

  final MasterEarningsVerdict verdict;
}

/// Çuval ya da parti başı prim alan ustanın vardiyalık hak edişini
/// hesaplar (saf Dart).
///
/// Brüt hak ediş 0 ise sonuç tanımsızdır; [MasterEarningsVerdict.invalid]
/// döner. Kesinti brütü aşarsa net 0'a kırpılır ve
/// [MasterEarningsVerdict.deductionExceeds] döner.
/// NaN / Infinity üretmez; negatifler 0'a normalize edilir.
class MasterEarningsCalculator {
  const MasterEarningsCalculator();

  MasterEarningsResult calculate({
    required double unitsProcessed,
    required double ratePerUnit,
    double fixedDaily = 0,
    double deduction = 0,
  }) {
    final units = nonNeg(unitsProcessed);
    final rate = nonNeg(ratePerUnit);
    final fixed = nonNeg(fixedDaily);
    final cut = nonNeg(deduction);

    final bonusTotal = units * rate;
    final gross = bonusTotal + fixed;

    if (gross <= 0) {
      return const MasterEarningsResult(
        bonusTotal: 0,
        gross: 0,
        net: 0,
        verdict: MasterEarningsVerdict.invalid,
      );
    }

    final rawNet = gross - cut;
    final MasterEarningsVerdict verdict;
    final double net;
    if (rawNet < 0) {
      verdict = MasterEarningsVerdict.deductionExceeds;
      net = 0;
    } else {
      verdict = MasterEarningsVerdict.ok;
      net = rawNet;
    }

    return MasterEarningsResult(
      bonusTotal: finiteOrZero(bonusTotal),
      gross: finiteOrZero(gross),
      net: finiteOrZero(net),
      verdict: verdict,
    );
  }
}
