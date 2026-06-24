import 'calc_safety.dart';

/// Bedelsiz Kampanya Çözücü sonucu.
class FreeGoodsResult {
  const FreeGoodsResult({
    required this.realUnitPrice,
    required this.totalAdvantage,
    required this.discountPct,
  });

  /// Bedelsizlerle birlikte gerçek birim (çuval) fiyatı.
  final double realUnitPrice;

  /// Toplam avantaj = bedelsiz adet × normal fiyat.
  final double totalAdvantage;

  /// Yüzdesel indirim (gerçek fiyatın normal fiyata göre düşüşü).
  final double discountPct;
}

/// "X al Y bedelsiz" kampanyasının gerçek birim fiyatını çözer (saf Dart).
///
/// gerçek fiyat = normal × satın alınan / (satın alınan + bedelsiz).
/// Toplam gelen adet 0 ise güvenli bölme 0 döndürür; sonsuz değer üretmez.
class FreeGoodsCalculator {
  const FreeGoodsCalculator();

  FreeGoodsResult calculate({
    required double normalUnitPrice,
    required double purchasedCount,
    required double freeCount,
  }) {
    final normal = nonNeg(normalUnitPrice);
    final purchased = nonNeg(purchasedCount);
    final free = nonNeg(freeCount);
    final totalReceived = purchased + free;

    final realUnitPrice = safeDiv(normal * purchased, totalReceived);
    final totalAdvantage = normal * free;
    final discountPct = safeDiv(normal - realUnitPrice, normal) * 100.0;

    return FreeGoodsResult(
      realUnitPrice: finiteOrZero(realUnitPrice),
      totalAdvantage: finiteOrZero(totalAdvantage),
      discountPct: finiteOrZero(discountPct),
    );
  }
}
