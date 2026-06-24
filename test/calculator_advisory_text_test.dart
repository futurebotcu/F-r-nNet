import 'package:firin_defter/core/widgets/app_number_field.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/bakers_percentage_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/cost_profit_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/dough_water_ratio_screen.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/sack_to_bread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 1 — sonuç ekranlarına eklenen pratik uyarı/yorum katmanı testleri.
/// Metin/UX doğrulaması; hesap motorları değişmedi.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('Hamur Kıvamı: ideal oranda olumlu yorum gösterilir', (
    tester,
  ) async {
    // Varsayılan 50 un / 33 su → %66 → ideal band.
    await pump(tester, const DoughWaterRatioScreen());
    expect(
      find.text('Kıvam iyi görünüyor; teraziyi bu oranla koru.'),
      findsOneWidget,
    );
  });

  testWidgets('Çuvaldan Kaç Ürün: tahmini uyarısı gösterilir', (tester) async {
    await pump(tester, const SackToBreadScreen());
    expect(find.textContaining('Bu sonuç tahminidir'), findsOneWidget);
    expect(find.textContaining('teraziyi kontrol et'), findsOneWidget);
  });

  testWidgets('Fırıncı Yüzdesi: "un %100 kabul edilir" bilgi kutusu var', (
    tester,
  ) async {
    await pump(tester, const BakersPercentageScreen());
    expect(
      find.textContaining('un her zaman %100 kabul edilir'),
      findsOneWidget,
    );
  });

  testWidgets('Gerçek Maliyet + Kâr: zarar senaryosunda uyarı çıkar', (
    tester,
  ) async {
    await pump(tester, const CostProfitScreen());
    // Satış fiyatı alanı (8 alanın sonuncusu) maliyetin altına çekilir.
    final fields = find.byType(AppNumberField);
    await tester.enterText(fields.at(7), '1');
    await tester.tap(find.text('HESAPLA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zarar ediyorsun'), findsOneWidget);
  });
}
