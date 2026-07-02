import 'calc_safety.dart';

/// Koli çevirisinin durumu: tam bölünüyor mu, tekli kalıyor mu?
enum PackConvertVerdict { invalid, exact, withRemainder }

/// "Koli / Paket Dönüştürücü" sonucu.
class PackConvertResult {
  const PackConvertResult({
    required this.fullPacks,
    required this.remainderUnits,
    required this.roundUpPacks,
    required this.extraUnits,
    required this.verdict,
  });

  /// İstenen adedi karşılayan tam koli sayısı.
  final int fullPacks;

  /// Tam kolilerden sonra açıkta kalan tekli adet.
  final int remainderUnits;

  /// Yukarı yuvarlanırsa alınacak koli sayısı.
  final int roundUpPacks;

  /// Yukarı yuvarlamada elde kalacak fazla adet.
  final int extraUnits;

  final PackConvertVerdict verdict;
}

/// İstenen adedi koli/paket sayısına çevirir (saf Dart).
///
/// Adet veya koli içi adet 0 ise çevirme yapılamaz;
/// [PackConvertVerdict.invalid] döner. Küsuratlı girdiler tam sayıya
/// indirgenir; negatifler 0'a normalize edilir. NaN / Infinity üretmez.
class PackConvertCalculator {
  const PackConvertCalculator();

  PackConvertResult calculate({
    required double neededUnits,
    required double unitsPerPack,
  }) {
    final needed = nonNeg(neededUnits).floor();
    final perPack = nonNeg(unitsPerPack).floor();

    if (perPack <= 0 || needed <= 0) {
      return const PackConvertResult(
        fullPacks: 0,
        remainderUnits: 0,
        roundUpPacks: 0,
        extraUnits: 0,
        verdict: PackConvertVerdict.invalid,
      );
    }

    final fullPacks = needed ~/ perPack;
    final remainderUnits = needed % perPack;
    final roundUpPacks = remainderUnits > 0 ? fullPacks + 1 : fullPacks;
    final extraUnits = roundUpPacks * perPack - needed;

    return PackConvertResult(
      fullPacks: fullPacks,
      remainderUnits: remainderUnits,
      roundUpPacks: roundUpPacks,
      extraUnits: extraUnits,
      verdict: remainderUnits > 0
          ? PackConvertVerdict.withRemainder
          : PackConvertVerdict.exact,
    );
  }
}
