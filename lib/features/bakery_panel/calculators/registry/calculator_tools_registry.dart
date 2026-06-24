import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../profile/models/bakery_profile.dart';
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
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'water_ratio',
      title: AppStrings.calcWaterRatioTitle,
      description: AppStrings.calcWaterRatioSub,
      icon: Icons.water_drop_outlined,
      route: AppRoutes.calculatorWaterRatio,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'sack_bread',
      title: AppStrings.calcSackBreadTitle,
      description: AppStrings.calcSackBreadSub,
      icon: Icons.inventory_2_outlined,
      route: AppRoutes.calculatorSackBread,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'bakers_percent',
      title: AppStrings.calcBakersPercentTitle,
      description: AppStrings.calcBakersPercentSub,
      icon: Icons.percent_rounded,
      route: AppRoutes.calculatorBakersPercent,
      visibility: CalculatorRoleVisibility.producers,
    ),
    CalculatorTool(
      id: 'recipe_scale',
      title: AppStrings.calcRecipeScaleTitle,
      description: AppStrings.calcRecipeScaleSub,
      icon: Icons.unfold_more_rounded,
      route: AppRoutes.calculatorRecipeScale,
      visibility: CalculatorRoleVisibility.producers,
    ),

    // ── ÇALIŞAN modülü (yalnız bireysel/usta) ──────────────────────────────
    CalculatorTool(
      id: 'water_temp',
      title: AppStrings.calcWaterTempTitle,
      description: AppStrings.calcWaterTempSub,
      icon: Icons.thermostat_outlined,
      route: AppRoutes.calculatorWaterTemp,
      visibility: CalculatorRoleVisibility.individualOnly,
    ),

    // ── PATRON modülleri (yalnız ticari/işletme) ───────────────────────────
    CalculatorTool(
      id: 'cost_profit',
      title: AppStrings.calcCostProfitTitle,
      description: AppStrings.calcCostProfitSub,
      icon: Icons.trending_up_rounded,
      route: AppRoutes.calculatorCostProfit,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'flour_hike',
      title: AppStrings.calcFlourHikeTitle,
      description: AppStrings.calcFlourHikeSub,
      icon: Icons.show_chart_rounded,
      route: AppRoutes.calculatorFlourHike,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'oven_energy',
      title: AppStrings.calcOvenEnergyTitle,
      description: AppStrings.calcOvenEnergySub,
      icon: Icons.bolt_rounded,
      route: AppRoutes.calculatorOvenEnergy,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'free_goods',
      title: AppStrings.calcFreeGoodsTitle,
      description: AppStrings.calcFreeGoodsSub,
      icon: Icons.card_giftcard_outlined,
      route: AppRoutes.calculatorFreeGoods,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
    CalculatorTool(
      id: 'evening_discount',
      title: AppStrings.calcEveningDiscountTitle,
      description: AppStrings.calcEveningDiscountSub,
      icon: Icons.price_change_outlined,
      route: AppRoutes.calculatorEveningDiscount,
      visibility: CalculatorRoleVisibility.commercialOnly,
    ),
  ];

  /// [type] hesap türüne görünür ve etkin araçlar.
  static List<CalculatorTool> forAccount(AccountType type) {
    return all
        .where((tool) => tool.enabled && tool.isVisibleTo(type))
        .toList(growable: false);
  }
}
