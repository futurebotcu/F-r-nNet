import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/batch_value_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/dealer_profit_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/fixed_cost_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/price_update_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/stock_runway_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/waste_loss_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 3 — yeni modül ekranları smoke testi: açılır, postFrame hesaplama
/// çalışır (SONUÇ görünür) ve "Hesapla" yeniden hesaplar.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> expectOpensAndCalculates(
    WidgetTester tester,
    Widget screen,
    String title,
  ) async {
    await pump(tester, screen);
    expect(find.text(title), findsOneWidget);
    expect(find.text('SONUÇ'), findsOneWidget);
    await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('SONUÇ'), findsOneWidget);
  }

  testWidgets('Stok Bu Hafta Biter mi? (ortak) açılır + hesaplar', (
    tester,
  ) async {
    await expectOpensAndCalculates(
      tester,
      const StockRunwayScreen(),
      AppStrings.calcStockRunwayTitle,
    );
  });

  testWidgets('Tepsi / Parti Değeri (ortak) açılır + hesaplar', (tester) async {
    await expectOpensAndCalculates(
      tester,
      const BatchValueScreen(),
      AppStrings.calcBatchValueTitle,
    );
  });

  testWidgets('Fiyat Güncelleme Simülatörü (patron) açılır + hesaplar', (
    tester,
  ) async {
    await expectOpensAndCalculates(
      tester,
      const PriceUpdateScreen(),
      AppStrings.calcPriceUpdateTitle,
    );
  });

  testWidgets('Bayi Kârlılık Ölçeği (patron) açılır + hesaplar', (
    tester,
  ) async {
    await expectOpensAndCalculates(
      tester,
      const DealerProfitScreen(),
      AppStrings.calcDealerProfitTitle,
    );
  });

  testWidgets('Dükkan Boşta Kaça Çalışıyor? (patron) açılır + hesaplar', (
    tester,
  ) async {
    await expectOpensAndCalculates(
      tester,
      const FixedCostScreen(),
      AppStrings.calcFixedCostTitle,
    );
  });

  testWidgets('Günlük Fire / Bayat Zarar (patron) açılır + hesaplar', (
    tester,
  ) async {
    await expectOpensAndCalculates(
      tester,
      const WasteLossScreen(),
      AppStrings.calcWasteLossTitle,
    );
  });
}
