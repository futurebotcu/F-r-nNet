import 'calc_safety.dart';

/// Prim / bahşiş dağıtım yorumu.
///
/// Öncelik sırası: tutar ya da yüzde yoksa hesap yapılamaz → yüzdeler 100
/// ediyor (dağıtım tam) → yüzdeler 100 etmiyor (kalan tutar açıkta).
enum TipSplitVerdict { invalid, ok, pctMismatch }

/// "Prim / Bahşiş Bölüştürücü" sonucu.
class TipSplitResult {
  const TipSplitResult({
    required this.productionShare,
    required this.counterShare,
    required this.apprenticeShare,
    required this.remainder,
    required this.sumPct,
    required this.verdict,
  });

  /// İmalat grubunun payı = toplam × imalat yüzdesi / 100.
  final double productionShare;

  /// Tezgâh grubunun payı = toplam × tezgâh yüzdesi / 100.
  final double counterShare;

  /// Çırak/diğer grubunun payı = toplam × çırak yüzdesi / 100.
  final double apprenticeShare;

  /// Kalan/yuvarlama = toplam − üç payın toplamı (yüzdeler 100 etmiyorsa
  /// açıkta kalan tutar; negatif de olabilir).
  final double remainder;

  /// Girilen pay yüzdelerinin toplamı.
  final double sumPct;

  final TipSplitVerdict verdict;
}

/// Gün sonu prim veya bahşişi imalat, tezgâh ve çırak grupları arasında
/// yüzdelere göre bölüştürür (saf Dart).
///
/// Toplam tutar ya da yüzde toplamı 0 ise [TipSplitVerdict.invalid] döner.
/// Yüzdeler 100 etmiyorsa paylar yine hesaplanır ama kalan tutar açıkta
/// kalır; [TipSplitVerdict.pctMismatch] döner.
/// NaN / Infinity üretmez; negatifler 0'a normalize edilir.
class TipSplitCalculator {
  const TipSplitCalculator();

  TipSplitResult calculate({
    required double totalAmount,
    required double productionPct,
    required double counterPct,
    required double apprenticePct,
  }) {
    final total = nonNeg(totalAmount);
    final production = nonNeg(productionPct);
    final counter = nonNeg(counterPct);
    final apprentice = nonNeg(apprenticePct);

    final sumPct = production + counter + apprentice;

    if (total <= 0 || sumPct <= 0) {
      return const TipSplitResult(
        productionShare: 0,
        counterShare: 0,
        apprenticeShare: 0,
        remainder: 0,
        sumPct: 0,
        verdict: TipSplitVerdict.invalid,
      );
    }

    final productionShare = total * production / 100;
    final counterShare = total * counter / 100;
    final apprenticeShare = total * apprentice / 100;
    final remainder =
        total - (productionShare + counterShare + apprenticeShare);

    final verdict = (sumPct - 100).abs() < 0.01
        ? TipSplitVerdict.ok
        : TipSplitVerdict.pctMismatch;

    return TipSplitResult(
      productionShare: finiteOrZero(productionShare),
      counterShare: finiteOrZero(counterShare),
      apprenticeShare: finiteOrZero(apprenticeShare),
      remainder: finiteOrZero(remainder),
      sumPct: finiteOrZero(sumPct),
      verdict: verdict,
    );
  }
}
