import 'calc_safety.dart';

/// Düz hesap pazarlığı yorumu: fatura yoksa hesap yapılamaz, teklif
/// faturanın altında değilse kazanç yok, aksi hâlde iskonto var.
enum FlatDealVerdict { invalid, noGain, discount }

/// "Düz Hesap / İskonto" sonucu.
class FlatDealResult {
  const FlatDealResult({
    required this.savedAmount,
    required this.discountPct,
    required this.verdict,
  });

  /// Faturadan silinen tutar = fatura − teklif (TL). Kazanç yoksa 0
  /// veya negatif olabilir.
  final double savedAmount;

  /// Gerçek iskonto oranı = silinen tutar / fatura × 100.
  final double discountPct;

  final FlatDealVerdict verdict;
}

/// "Düz hesap yapalım" pazarlığının gerçekte yüzde kaç iskonto olduğunu
/// hesaplar (saf Dart).
///
/// Fatura tutarı 0 ise [FlatDealVerdict.invalid] döner. NaN / Infinity /
/// sıfıra bölme üretmez; negatifler 0'a normalize edilir.
class FlatDealCalculator {
  const FlatDealCalculator();

  FlatDealResult calculate({
    required double invoiceAmount,
    required double offeredAmount,
  }) {
    final invoice = nonNeg(invoiceAmount);
    final offered = nonNeg(offeredAmount);

    if (invoice <= 0) {
      return const FlatDealResult(
        savedAmount: 0,
        discountPct: 0,
        verdict: FlatDealVerdict.invalid,
      );
    }

    final saved = invoice - offered;
    final discountPct = safeDiv(saved, invoice) * 100;

    return FlatDealResult(
      savedAmount: finiteOrZero(saved),
      discountPct: finiteOrZero(discountPct),
      verdict: saved <= 0 ? FlatDealVerdict.noGain : FlatDealVerdict.discount,
    );
  }
}
