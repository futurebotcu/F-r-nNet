import 'calc_safety.dart';

/// Reçetedeki tek bir maliyet kalemi.
///
/// Kalem iki şekilde girilebilir: miktar × birim fiyat ([quantity] ×
/// [unitPrice]) VEYA doğrudan tutar ([flatCost]). İkisi birden girilirse
/// toplanır. Negatif girişler 0'a normalize edilir.
class RecipeCostItem {
  const RecipeCostItem({
    required this.name,
    this.quantity = 0,
    this.unitPrice = 0,
    this.flatCost = 0,
  });

  /// Kalemin adı (örn. 'Un', 'Ambalaj').
  final String name;

  /// Miktar (kg/adet vb.).
  final double quantity;

  /// Birim fiyat (TL).
  final double unitPrice;

  /// Doğrudan girilen toplam tutar (TL).
  final double flatCost;

  /// Kalemin toplam maliyeti = miktar × birim fiyat + doğrudan tutar.
  double get cost => nonNeg(quantity) * nonNeg(unitPrice) + nonNeg(flatCost);
}

/// Reçete maliyeti yorumu: girdiler eksikse hesap yapılamaz, aksi hâlde ok.
enum RecipeCostVerdict { invalid, ok }

/// "Detaylı Reçete Maliyeti" sonucu.
class RecipeCostDetailResult {
  const RecipeCostDetailResult({
    required this.totalCost,
    required this.costPerUnit,
    required this.suggestedPrice,
    required this.dominantItemName,
    required this.dominantItemCost,
    required this.verdict,
  });

  /// Tüm kalemlerin toplam maliyeti (TL).
  final double totalCost;

  /// Ürün başı maliyet = toplam maliyet / üretim adedi (TL).
  final double costPerUnit;

  /// Hedef kârla önerilen satış fiyatı (TL).
  final double suggestedPrice;

  /// Maliyeti en yüksek kalemin adı (kalem yoksa boş).
  final String dominantItemName;

  /// Maliyeti en yüksek kalemin tutarı (TL).
  final double dominantItemCost;

  final RecipeCostVerdict verdict;
}

/// Malzeme kalemlerinden toplam ve ürün başı maliyeti, hedef kâra göre
/// önerilen satış fiyatını hesaplar (saf Dart).
///
/// Kâr oranı MALİYET ÜZERİNDEN uygulanır (markup): önerilen fiyat =
/// ürün başı maliyet × (1 + kâr% / 100). Üretim adedi veya toplam maliyet
/// 0 ise [RecipeCostVerdict.invalid] döner. NaN / Infinity / sıfıra bölme
/// üretmez; negatifler 0'a normalize edilir.
class RecipeCostDetailCalculator {
  const RecipeCostDetailCalculator();

  RecipeCostDetailResult calculate({
    required double productionCount,
    required List<RecipeCostItem> items,
    double targetProfitPct = 0,
  }) {
    final count = nonNeg(productionCount);

    var totalCost = 0.0;
    var dominantName = '';
    var dominantCost = 0.0;
    for (final item in items) {
      final cost = finiteOrZero(item.cost);
      totalCost += cost;
      // Eşitlikte ilk kalem baskın kalır (strict karşılaştırma).
      if (cost > dominantCost) {
        dominantCost = cost;
        dominantName = item.name;
      }
    }
    totalCost = finiteOrZero(totalCost);

    if (count <= 0 || totalCost <= 0) {
      return const RecipeCostDetailResult(
        totalCost: 0,
        costPerUnit: 0,
        suggestedPrice: 0,
        dominantItemName: '',
        dominantItemCost: 0,
        verdict: RecipeCostVerdict.invalid,
      );
    }

    final costPerUnit = safeDiv(totalCost, count);
    final suggestedPrice = costPerUnit * (1 + nonNeg(targetProfitPct) / 100);

    return RecipeCostDetailResult(
      totalCost: totalCost,
      costPerUnit: finiteOrZero(costPerUnit),
      suggestedPrice: finiteOrZero(suggestedPrice),
      dominantItemName: dominantName,
      dominantItemCost: finiteOrZero(dominantCost),
      verdict: RecipeCostVerdict.ok,
    );
  }
}
