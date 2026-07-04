import 'package:flutter/material.dart';

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
  staffShare,
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
      case CalculatorCategory.staffShare:
        return AppStrings.calcCatStaffShareTitle;
    }
  }

  /// Bölüm başlığı ikonu (premium hub başlık şeridi). Saf gösterim verisi.
  IconData get icon {
    switch (this) {
      case CalculatorCategory.dailyQuick:
        return Icons.bolt_rounded;
      case CalculatorCategory.productionRecipe:
        return Icons.bakery_dining_outlined;
      case CalculatorCategory.bossCostProfit:
        return Icons.trending_up_rounded;
      case CalculatorCategory.supplierDeal:
        return Icons.handshake_outlined;
      case CalculatorCategory.staffShare:
        return Icons.groups_outlined;
    }
  }
}
