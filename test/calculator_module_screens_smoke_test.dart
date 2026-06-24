import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/cost_profit_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/morning_production_planner_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/water_temperature_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Üç kategoriden (ortak / çalışan / patron) birer modül ekranı smoke testi:
/// açılır, postFrame hesaplama çalışır ve "Hesapla" yeniden hesaplar.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Sabah Üretim Planlayıcı (ortak) açılır + hesaplar', (
    tester,
  ) async {
    await pump(tester, const MorningProductionPlannerScreen());
    expect(find.text(AppStrings.calcMorningPlanTitle), findsOneWidget);
    expect(find.text('SONUÇ'), findsOneWidget);
    await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('SONUÇ'), findsOneWidget);
  });

  testWidgets('Hamur Suyu Sıcaklığı (çalışan) açılır + hesaplar', (
    tester,
  ) async {
    await pump(tester, const WaterTemperatureScreen());
    expect(find.text(AppStrings.calcWaterTempTitle), findsOneWidget);
    expect(find.text('SONUÇ'), findsOneWidget);
    await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('SONUÇ'), findsOneWidget);
  });

  testWidgets('Gerçek Maliyet + Kâr (patron) açılır + hesaplar', (
    tester,
  ) async {
    await pump(tester, const CostProfitScreen());
    expect(find.text(AppStrings.calcCostProfitTitle), findsOneWidget);
    expect(find.text('SONUÇ'), findsOneWidget);
    await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('SONUÇ'), findsOneWidget);
  });
}
