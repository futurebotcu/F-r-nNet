import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/daily_close_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/fermentation_time_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/flat_deal_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/labor_index_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/master_earnings_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/oven_capacity_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/overtime_pay_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/pack_convert_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/recipe_cost_detail_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/tip_split_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/weight_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final tamamlama paketi — 11 yeni modül ekranı smoke testi.
///
/// Her ekran: açılır, postFrame ilk hesap çalışır (SONUÇ görünür), "Hesapla"
/// yeniden hesaplar; ayrıca 320px dar ekranda overflow/exception üretmez.
void main() {
  // (ekran, başlık) çiftleri — yeni final modülleri.
  final screens = <(Widget, String)>[
    (const WeightChangeScreen(), AppStrings.calcWeightChangeTitle),
    (const PackConvertScreen(), AppStrings.calcPackConvertTitle),
    (const FermentationTimeScreen(), AppStrings.calcFermentationTitle),
    (const OvertimePayScreen(), AppStrings.calcOvertimePayTitle),
    (const RecipeCostDetailScreen(), AppStrings.calcRecipeCostDetailTitle),
    (const FlatDealScreen(), AppStrings.calcFlatDealTitle),
    (const OvenCapacityScreen(), AppStrings.calcOvenCapacityTitle),
    (const LaborIndexScreen(), AppStrings.calcLaborIndexTitle),
    (const MasterEarningsScreen(), AppStrings.calcMasterEarningsTitle),
    (const TipSplitScreen(), AppStrings.calcTipSplitTitle),
    (const DailyCloseScreen(), AppStrings.calcDailyCloseTitle),
  ];

  Future<void> pump(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  for (final (screen, title) in screens) {
    testWidgets('$title açılır + hesaplar', (tester) async {
      await pump(tester, screen, const Size(1200, 3600));
      expect(find.text(title), findsOneWidget);
      expect(find.text('SONUÇ'), findsOneWidget);
      await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text('SONUÇ'), findsOneWidget);
    });

    testWidgets('$title 320px dar ekranda taşma yapmaz', (tester) async {
      await pump(tester, screen, const Size(320, 3600));
      expect(tester.takeException(), isNull);
      expect(find.text('SONUÇ'), findsOneWidget);
    });
  }
}
