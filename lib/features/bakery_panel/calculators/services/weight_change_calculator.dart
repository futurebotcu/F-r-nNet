import 'calc_safety.dart';

/// Gramaj değişiminin yönü.
///
/// Gramaj düşerse aynı hamurdan daha çok adet çıkar; artarsa daha az.
enum WeightChangeVerdict { invalid, morePieces, fewerPieces, same }

/// "Gramaj Değişimi" sonucu.
class WeightChangeResult {
  const WeightChangeResult({
    required this.oldCount,
    required this.newCount,
    required this.pieceDiff,
    required this.pctChangePct,
    required this.revenueDiff,
    required this.hasRevenue,
    required this.verdict,
  });

  /// Eski gramajla hamurdan çıkan adet.
  final int oldCount;

  /// Yeni gramajla hamurdan çıkan adet.
  final int newCount;

  /// Adet farkı (yeni − eski); artışta pozitif, azalışta negatif.
  final int pieceDiff;

  /// Adet değişiminin eski adede oranı (yüzde puan).
  final double pctChangePct;

  /// Satış fiyatı girildiyse tahmini ciro farkı (adet farkı × fiyat).
  final double revenueDiff;

  /// Satış fiyatı girildi mi (ciro satırı gösterilsin mi)?
  final bool hasRevenue;

  final WeightChangeVerdict verdict;
}

/// Aynı hamur miktarında gramaj değişince adet ve tahmini cironun nasıl
/// etkilendiğini hesaplar (saf Dart).
///
/// Hamur veya gramajlardan biri 0 ise hesap yapılamaz;
/// [WeightChangeVerdict.invalid] döner. NaN / Infinity / sıfıra bölme
/// üretmez; negatifler 0'a normalize edilir.
class WeightChangeCalculator {
  const WeightChangeCalculator();

  WeightChangeResult calculate({
    required double totalDoughKg,
    required double oldGramsPerPiece,
    required double newGramsPerPiece,
    double salePrice = 0,
  }) {
    final doughKg = nonNeg(totalDoughKg);
    final oldGrams = nonNeg(oldGramsPerPiece);
    final newGrams = nonNeg(newGramsPerPiece);
    final price = nonNeg(salePrice);

    if (doughKg <= 0 || oldGrams <= 0 || newGrams <= 0) {
      return const WeightChangeResult(
        oldCount: 0,
        newCount: 0,
        pieceDiff: 0,
        pctChangePct: 0,
        revenueDiff: 0,
        hasRevenue: false,
        verdict: WeightChangeVerdict.invalid,
      );
    }

    final doughGrams = doughKg * 1000;
    final oldCount = safeDiv(doughGrams, oldGrams).floor();
    final newCount = safeDiv(doughGrams, newGrams).floor();
    final pieceDiff = newCount - oldCount;
    final pctChangePct =
        safeDiv(pieceDiff.toDouble(), oldCount.toDouble()) * 100;

    final hasRevenue = price > 0;
    final revenueDiff = pieceDiff * price;

    final WeightChangeVerdict verdict;
    if (newGrams < oldGrams) {
      verdict = WeightChangeVerdict.morePieces;
    } else if (newGrams > oldGrams) {
      verdict = WeightChangeVerdict.fewerPieces;
    } else {
      verdict = WeightChangeVerdict.same;
    }

    return WeightChangeResult(
      oldCount: oldCount,
      newCount: newCount,
      pieceDiff: pieceDiff,
      pctChangePct: finiteOrZero(pctChangePct),
      revenueDiff: finiteOrZero(revenueDiff),
      hasRevenue: hasRevenue,
      verdict: verdict,
    );
  }
}
