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
  ];

  /// [type] hesap türüne görünür ve etkin araçlar.
  static List<CalculatorTool> forAccount(AccountType type) {
    return all
        .where((tool) => tool.enabled && tool.isVisibleTo(type))
        .toList(growable: false);
  }
}
