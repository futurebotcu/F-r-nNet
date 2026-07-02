import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../profile/models/bakery_profile.dart';
import '../models/calculator_category.dart';
import '../models/calculator_role_visibility.dart';
import '../models/calculator_tool.dart';

/// Hesaplama araçlarının tek kayıt noktası.
///
/// Yeni bir modül eklemek için yapılması gerekenler:
///   1. `services/` altına saf hesap servisi,
///   2. `screens/` altına ekran,
///   3. `app_router.dart`'a route (`/calculator/...`),
///   4. buraya bir [CalculatorTool] entry,
///   5. test.
/// Başka hiçbir yeri değiştirmeye gerek yoktur. Rol görünürlüğü
/// [CalculatorTool.visibility] ile burada yönetilir (UI'da hard-code yok).
class CalculatorToolsRegistry {
  const CalculatorToolsRegistry._();

  /// Tüm tanımlı araçlar (rol filtresi uygulanmamış ham liste).
  static const List<CalculatorTool> all = <CalculatorTool>[
    CalculatorTool(
      id: 'dough_yield',
      title: AppStrings.calcDoughYieldTitle,
      description: AppStrings.calcDoughYieldSub,
      icon: Icons.bakery_dining_outlined,
      route: AppRoutes.calculatorDough,
      category: CalculatorCategory.dailyQuick,
      // Bugünkü davranış: hamur hesabı ticari + bireysel tarafta görünür
      // (toptancı dashboard'ında hesaplama kartı yok). Rol kararları ileride
      // değişebilir; değişiklik tek nokta olarak burada yapılır.
      visibility: CalculatorRoleVisibility.producers,
    ),

    // ── ORTAK modüller (ticari + bireysel; toptancıya kapalı) ──────────────
    CalculatorTool(
      id: 'morning_plan',
      title: AppStrings.calcMorningPlanTitle,
      description: AppStrings.calcMorningPlanSub,
      icon: Icons.wb_sunny_outlined,
      route: AppRoutes.calculatorMorningPlan,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'water_ratio',
      title: AppStrings.calcWaterRatioTitle,
      description: AppStrings.calcWaterRatioSub,
      icon: Icons.water_drop_outlined,
      route: AppRoutes.calculatorWaterRatio,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'sack_bread',
      title: AppStrings.calcSackBreadTitle,
      description: AppStrings.calcSackBreadSub,
      icon: Icons.inventory_2_outlined,
      route: AppRoutes.calculatorSackBread,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'bakers_percent',
      title: AppStrings.calcBakersPercentTitle,
      description: AppStrings.calcBakersPercentSub,
      icon: Icons.percent_rounded,
      route: AppRoutes.calculatorBakersPercent,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'recipe_scale',
      title: AppStrings.calcRecipeScaleTitle,
      description: AppStrings.calcRecipeScaleSub,
      icon: Icons.unfold_more_rounded,
      route: AppRoutes.calculatorRecipeScale,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'stock_runway',
      title: AppStrings.calcStockRunwayTitle,
      description: AppStrings.calcStockRunwaySub,
      icon: Icons.inventory_outlined,
      route: AppRoutes.calculatorStockRunway,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'batch_value',
      title: AppStrings.calcBatchValueTitle,
      description: AppStrings.calcBatchValueSub,
      icon: Icons.dashboard_customize_outlined,
      route: AppRoutes.calculatorBatchValue,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'weight_change',
      title: AppStrings.calcWeightChangeTitle,
      description: AppStrings.calcWeightChangeSub,
      icon: Icons.monitor_weight_outlined,
      route: AppRoutes.calculatorWeightChange,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'pack_convert',
      title: AppStrings.calcPackConvertTitle,
      description: AppStrings.calcPackConvertSub,
      icon: Icons.all_inbox_outlined,
      route: AppRoutes.calculatorPackConvert,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.producers,
    ),

    // ── ÇALIŞAN modülleri (yalnız bireysel/usta) ───────────────────────────
    CalculatorTool(
      id: 'water_temp',
      title: AppStrings.calcWaterTempTitle,
      description: AppStrings.calcWaterTempSub,
      icon: Icons.thermostat_outlined,
      route: AppRoutes.calculatorWaterTemp,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.individualOnly,
    ),
    CalculatorTool(
      id: 'fermentation_time',
      title: AppStrings.calcFermentationTitle,
      description: AppStrings.calcFermentationSub,
      icon: Icons.hourglass_bottom_rounded,
      route: AppRoutes.calculatorFermentation,
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.individualOnly,
    ),
    CalculatorTool(
      id: 'overtime_pay',
      title: AppStrings.calcOvertimePayTitle,
      description: AppStrings.calcOvertimePaySub,
      icon: Icons.more_time_rounded,
      route: AppRoutes.calculatorOvertimePay,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.individualOnly,
    ),

    // ── PATRON modülleri (yalnız ticari/işletme) ───────────────────────────
    CalculatorTool(
      id: 'cost_profit',
      title: AppStrings.calcCostProfitTitle,
      description: AppStrings.calcCostProfitSub,
      icon: Icons.trending_up_rounded,
      route: AppRoutes.calculatorCostProfit,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'flour_hike',
      title: AppStrings.calcFlourHikeTitle,
      description: AppStrings.calcFlourHikeSub,
      icon: Icons.show_chart_rounded,
      route: AppRoutes.calculatorFlourHike,
      category: CalculatorCategory.supplierDeal,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'oven_energy',
      title: AppStrings.calcOvenEnergyTitle,
      description: AppStrings.calcOvenEnergySub,
      icon: Icons.bolt_rounded,
      route: AppRoutes.calculatorOvenEnergy,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'free_goods',
      title: AppStrings.calcFreeGoodsTitle,
      description: AppStrings.calcFreeGoodsSub,
      icon: Icons.card_giftcard_outlined,
      route: AppRoutes.calculatorFreeGoods,
      category: CalculatorCategory.supplierDeal,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'evening_discount',
      title: AppStrings.calcEveningDiscountTitle,
      description: AppStrings.calcEveningDiscountSub,
      icon: Icons.price_change_outlined,
      route: AppRoutes.calculatorEveningDiscount,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'price_update',
      title: AppStrings.calcPriceUpdateTitle,
      description: AppStrings.calcPriceUpdateSub,
      icon: Icons.published_with_changes_rounded,
      route: AppRoutes.calculatorPriceUpdate,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'fixed_cost',
      title: AppStrings.calcFixedCostTitle,
      description: AppStrings.calcFixedCostSub,
      icon: Icons.store_outlined,
      route: AppRoutes.calculatorFixedCost,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'waste_loss',
      title: AppStrings.calcWasteLossTitle,
      description: AppStrings.calcWasteLossSub,
      icon: Icons.delete_outline_rounded,
      route: AppRoutes.calculatorWasteLoss,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'dealer_profit',
      title: AppStrings.calcDealerProfitTitle,
      description: AppStrings.calcDealerProfitSub,
      icon: Icons.storefront_outlined,
      route: AppRoutes.calculatorDealerProfit,
      category: CalculatorCategory.supplierDeal,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    // Final tamamlama paketi — patron modülleri.
    CalculatorTool(
      id: 'daily_close',
      title: AppStrings.calcDailyCloseTitle,
      description: AppStrings.calcDailyCloseSub,
      icon: Icons.point_of_sale_outlined,
      route: AppRoutes.calculatorDailyClose,
      // Gün sonu rutini: patron görünümünde "Günlük Hızlı Hesaplar" grubunda
      // stok/tepsiyle birlikte üstte dursun.
      category: CalculatorCategory.dailyQuick,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'oven_capacity',
      title: AppStrings.calcOvenCapacityTitle,
      description: AppStrings.calcOvenCapacitySub,
      icon: Icons.speed_rounded,
      route: AppRoutes.calculatorOvenCapacity,
      category: CalculatorCategory.productionRecipe,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'recipe_cost_detail',
      title: AppStrings.calcRecipeCostDetailTitle,
      description: AppStrings.calcRecipeCostDetailSub,
      icon: Icons.receipt_long_outlined,
      route: AppRoutes.calculatorRecipeCostDetail,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'labor_index',
      title: AppStrings.calcLaborIndexTitle,
      description: AppStrings.calcLaborIndexSub,
      icon: Icons.engineering_outlined,
      route: AppRoutes.calculatorLaborIndex,
      category: CalculatorCategory.bossCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'flat_deal',
      title: AppStrings.calcFlatDealTitle,
      description: AppStrings.calcFlatDealSub,
      icon: Icons.handshake_outlined,
      route: AppRoutes.calculatorFlatDeal,
      category: CalculatorCategory.supplierDeal,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'master_earnings',
      title: AppStrings.calcMasterEarningsTitle,
      description: AppStrings.calcMasterEarningsSub,
      icon: Icons.workspace_premium_outlined,
      route: AppRoutes.calculatorMasterEarnings,
      category: CalculatorCategory.staffShare,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'tip_split',
      title: AppStrings.calcTipSplitTitle,
      description: AppStrings.calcTipSplitSub,
      icon: Icons.groups_outlined,
      route: AppRoutes.calculatorTipSplit,
      category: CalculatorCategory.staffShare,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
  ];

  /// [type] hesap türüne görünür ve etkin araçlar (registry ham sırasında).
  static List<CalculatorTool> forAccount(AccountType type) {
    return all
        .where((tool) => tool.enabled && tool.isVisibleTo(type))
        .toList(growable: false);
  }

  /// Hub'ta gösterilecek kategori sırası. En sık kullanılan grup üstte;
  /// sıralama role göre değişir (bireysel günlük hesaplarla, patron üretim/
  /// maliyetle başlar). Tek karar noktası buradadır.
  static List<CalculatorCategory> _categoryOrder(AccountType type) {
    switch (type) {
      case AccountType.individual:
        // Usta/çalışan: önce hamur & günlük hesaplar, sonra üretim.
        // (Patron/personel grupları bireyselde boş kalır ve atlanır.)
        return const [
          CalculatorCategory.dailyQuick,
          CalculatorCategory.productionRecipe,
          CalculatorCategory.bossCostProfit,
          CalculatorCategory.supplierDeal,
          CalculatorCategory.staffShare,
        ];
      case AccountType.commercial:
        // Patron: önce her gün bakılan günlük hızlı hesaplar (stok/tepsi/
        // kapanış), hemen ardından para kararları (maliyet/kâr), sonra üretim
        // planı, tedarikçi pazarlığı ve personel paylaşımı. Görünürlük/route
        // değişmez; yalnız bölüm sırası — patron "para"ya daha hızlı ulaşır.
        return const [
          CalculatorCategory.dailyQuick,
          CalculatorCategory.bossCostProfit,
          CalculatorCategory.productionRecipe,
          CalculatorCategory.supplierDeal,
          CalculatorCategory.staffShare,
        ];
      case AccountType.wholesaler:
        return const [];
    }
  }

  /// [type] için kategoriye göre gruplanmış, rol-sıralı araç bölümleri.
  /// Boş kategori atlanır. Bölüm içi sıra registry ham sırasıdır (en sık
  /// kullanılan üstte). Hub ekranı bunu doğrudan çizer.
  static List<CalculatorToolGroup> groupedForAccount(AccountType type) {
    final visible = forAccount(type);
    final groups = <CalculatorToolGroup>[];
    for (final category in _categoryOrder(type)) {
      final tools = visible
          .where((tool) => tool.category == category)
          .toList(growable: false);
      if (tools.isNotEmpty) {
        groups.add(CalculatorToolGroup(category: category, tools: tools));
      }
    }
    return groups;
  }
}

/// Hub'ta tek bir kategori bölümü: başlık (kategori) + o role görünür araçlar.
class CalculatorToolGroup {
  const CalculatorToolGroup({required this.category, required this.tools});

  final CalculatorCategory category;
  final List<CalculatorTool> tools;
}
