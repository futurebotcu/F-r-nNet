import 'package:firin_defter/core/widgets/app_number_field.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/dough_water_ratio_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/morning_production_planner_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/sack_to_bread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 2 — ürün preset kataloğunun ekranları beslemesi (widget seviyesi).
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  // Dropdown'dan etikete göre seçim yapar (generic tip için predicate).
  Future<void> selectFromDropdown(
    WidgetTester tester,
    String optionText,
  ) async {
    final dropdown = find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField,
    );
    await tester.tap(dropdown.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(optionText).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Çuvaldan Kaç Ürün: Simit seçilince gramaj/su/fire varsayılanı dolar',
    (tester) async {
      await pump(tester, const SackToBreadScreen());
      // Varsayılan manuel → 500 gramaj görünür.
      expect(find.text('500'), findsOneWidget);

      await selectFromDropdown(tester, 'Simit');

      // Simit varsayılanları: gramaj 110, su kaldırma 52, fire 9.
      expect(find.text('110'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
    },
  );

  testWidgets('Çuvaldan Kaç Ürün: kullanıcı değeri elle değiştirebilir', (
    tester,
  ) async {
    await pump(tester, const SackToBreadScreen());
    await selectFromDropdown(tester, 'Poğaça');
    // Poğaça gramaj 70 dolar.
    expect(find.text('70'), findsWidgets);
    // Gramaj alanı (4. AppNumberField: çuval, çuval kg, su, gramaj, fire)
    // elle değiştirilebilir.
    final gramField = find.byType(AppNumberField).at(3);
    await tester.enterText(gramField, '123');
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets(
    'Sabah Üretim: ürün seçimi gramaj alanını doldurur + düzenlenir',
    (tester) async {
      await pump(tester, const MorningProductionPlannerScreen());
      await selectFromDropdown(tester, 'Simit');
      // Simit gramaj 110 dolar.
      expect(find.text('110'), findsOneWidget);
      // Birim gramaj alanı (1. AppNumberField) elle değiştirilebilir.
      final gramField = find.byType(AppNumberField).at(0);
      await tester.enterText(gramField, '95');
      await tester.pumpAndSettle();
      expect(find.text('95'), findsOneWidget);
    },
  );

  testWidgets('Hamur Kıvamı: Simit grubunda %52 ideal sayılır', (tester) async {
    await pump(tester, const DoughWaterRatioScreen());
    // Su alanını 26 yap (un 50 → %52).
    final waterField = find.byType(AppNumberField).at(1);
    await tester.enterText(waterField, '26');
    await tester.pumpAndSettle();
    await selectFromDropdown(tester, 'Simit');
    expect(find.text('İdeal kıvam'), findsOneWidget);
  });

  testWidgets('Hamur Kıvamı: ürün seçilmezse genel davranış korunur', (
    tester,
  ) async {
    await pump(tester, const DoughWaterRatioScreen());
    // Varsayılan 50 un / 33 su → %66 → genel eşikte (65–70) ideal.
    expect(find.text('İdeal kıvam'), findsOneWidget);
  });
}
