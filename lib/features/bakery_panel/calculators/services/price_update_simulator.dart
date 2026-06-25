import 'calc_safety.dart';

/// Fiyat güncelleme yorumu.
enum PriceUpdateVerdict { comfortable, marginEroded, sellingAtLoss }

/// "Fiyat Güncelleme Simülatörü" sonucu.
class PriceUpdateResult {
  const PriceUpdateResult({
    required this.newUnitCost,
    required this.currentMarginPct,
    required this.suggestedPrice,
    required this.priceDiff,
    required this.verdict,
  });

  /// Ana maliyet artışına göre ölçeklenmiş yeni tahmini ürün maliyeti.
  final double newUnitCost;

  /// Mevcut satış fiyatıyla, yeni maliyete göre kâr oranı % (negatif = zarar).
  final double currentMarginPct;

  /// Hedef kâr oranı için önerilen satış fiyatı.
  final double suggestedPrice;

  /// Önerilen − mevcut satış fiyatı farkı (negatif olabilir).
  final double priceDiff;

  final PriceUpdateVerdict verdict;
}

/// Un/malzeme (ana maliyet) zammına göre ürün fiyatının ne kadar
/// güncellenmesi gerektiğini hesaplar (saf Dart).
///
/// Yeni ürün maliyeti, ana maliyetteki orana göre ölçeklenir
/// (yeniMaliyet = mevcutMaliyet × yeniAna / eskiAna). Eski ana maliyet 0/eksi
/// ise oran 1 kabul edilir (maliyet değişmemiş sayılır). Hedef kâr önerilen
/// fiyat için %95'e kırpılır (sıfıra/negatife bölme engeli).
/// NaN / Infinity üretmez.
class PriceUpdateSimulator {
  const PriceUpdateSimulator({this.maxTargetMarginPct = 95});

  /// Önerilen fiyat hesabında hedef kâr oranı üst sınırı.
  final double maxTargetMarginPct;

  PriceUpdateResult calculate({
    required double currentUnitCost,
    required double oldMainCost,
    required double newMainCost,
    required double currentSalePrice,
    required double targetMarginPct,
  }) {
    final currentCost = nonNeg(currentUnitCost);
    final oldMain = nonNeg(oldMainCost);
    final newMain = nonNeg(newMainCost);
    final price = nonNeg(currentSalePrice);
    final target = nonNeg(
      targetMarginPct,
    ).clamp(0, maxTargetMarginPct).toDouble();

    // Ana maliyet bilinmiyorsa oran 1 (maliyet değişmemiş kabul).
    final ratio = oldMain <= 0 ? 1.0 : safeDiv(newMain, oldMain);
    final newUnitCost = currentCost * ratio;

    final currentMarginPct = safeDiv(price - newUnitCost, price) * 100.0;
    // satışFiyatı = maliyet / (1 − hedefKâr/100)
    final suggestedPrice = safeDiv(newUnitCost, 1.0 - target / 100.0);
    final priceDiff = suggestedPrice - price;

    final PriceUpdateVerdict verdict;
    if (price < newUnitCost) {
      verdict = PriceUpdateVerdict.sellingAtLoss;
    } else if (currentMarginPct < target) {
      verdict = PriceUpdateVerdict.marginEroded;
    } else {
      verdict = PriceUpdateVerdict.comfortable;
    }

    return PriceUpdateResult(
      newUnitCost: finiteOrZero(newUnitCost),
      currentMarginPct: finiteOrZero(currentMarginPct),
      suggestedPrice: finiteOrZero(suggestedPrice),
      priceDiff: finiteOrZero(priceDiff),
      verdict: verdict,
    );
  }
}
