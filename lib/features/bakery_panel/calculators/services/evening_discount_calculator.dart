import 'calc_safety.dart';

/// İndirim hedef modu: başabaş (zarar etme) ya da hedef minimum kâr.
enum DiscountMode { breakeven, minProfit }

/// Akşam İndirim Robotu sonucu.
class EveningDiscountResult {
  const EveningDiscountResult({
    required this.minSalePrice,
    required this.maxDiscountPct,
    required this.discountedCashIncome,
    required this.revenueDropVsNormal,
  });

  /// Zarar etmeden (veya hedef kârla) minimum satış fiyatı.
  final double minSalePrice;

  /// Normal fiyata göre uygulanabilecek maksimum indirim oranı %.
  final double maxDiscountPct;

  /// İndirimli satıştan gelecek toplam nakit.
  final double discountedCashIncome;

  /// Normal fiyata göre kaç TL düşük ciro.
  final double revenueDropVsNormal;
}

/// Elde kalan ürün için zarar etmeyen minimum fiyatı ve indirim tavanını
/// çözer (saf Dart).
///
/// [DiscountMode.breakeven] → minimum fiyat = ürün başı maliyet.
/// [DiscountMode.minProfit] → maliyet + hedef minimum kâr.
/// Negatif girişler 0'a normalize edilir; sıfıra bölme üretmez.
class EveningDiscountCalculator {
  const EveningDiscountCalculator();

  EveningDiscountResult calculate({
    required double remainingCount,
    required double costPerUnit,
    required double normalPrice,
    DiscountMode mode = DiscountMode.breakeven,
    double targetMinProfitPerUnit = 0,
  }) {
    final count = nonNeg(remainingCount);
    final cost = nonNeg(costPerUnit);
    final normal = nonNeg(normalPrice);
    final minProfit = mode == DiscountMode.minProfit
        ? nonNeg(targetMinProfitPerUnit)
        : 0.0;

    final minSalePrice = cost + minProfit;
    // Min fiyat normalin üstündeyse indirim mantıklı değil → tavan 0.
    final rawDiscountPct = safeDiv(normal - minSalePrice, normal) * 100.0;
    final maxDiscountPct = rawDiscountPct < 0 ? 0.0 : rawDiscountPct;
    final cashIncome = minSalePrice * count;
    final revenueDrop = (normal - minSalePrice) * count;

    return EveningDiscountResult(
      minSalePrice: finiteOrZero(minSalePrice),
      maxDiscountPct: finiteOrZero(maxDiscountPct),
      discountedCashIncome: finiteOrZero(cashIncome),
      revenueDropVsNormal: finiteOrZero(revenueDrop),
    );
  }
}
