import '../../../../core/constants/app_strings.dart';

/// Hesaplama merkezindeki araçların gruplandığı kategoriler.
///
/// Hub ekranı araçları bu kategorilere göre bölümlere ayırır. Kategori
/// sıralaması role göre [CalculatorToolsRegistry] içinde belirlenir (en sık
/// kullanılan grup üstte). Saf gösterim verisi — matematik/UI içermez.
enum CalculatorCategory {
  dailyQuick,
  productionRecipe,
  bossCostProfit,
  supplierDeal,
}

extension CalculatorCategoryMeta on CalculatorCategory {
  /// Bölüm başlığı.
  String get title {
    switch (this) {
      case CalculatorCategory.dailyQuick:
        return AppStrings.calcCatDailyQuickTitle;
      case CalculatorCategory.productionRecipe:
        return AppStrings.calcCatProductionTitle;
      case CalculatorCategory.bossCostProfit:
        return AppStrings.calcCatBossCostTitle;
      case CalculatorCategory.supplierDeal:
        return AppStrings.calcCatSupplierTitle;
    }
  }
}
