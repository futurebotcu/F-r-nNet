import 'package:firin_defter/features/bakery_panel/calculators/screens/dough_yield_calculator_screen.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/calculator/dough',
  routes: [
    GoRoute(
      path: '/calculator/dough',
      builder: (_, __) => const DoughYieldCalculatorScreen(),
    ),
    GoRoute(
      path: '/recipes/new',
      builder: (_, __) =>
          const Scaffold(body: Center(child: Text('RecipeEditor — stub'))),
    ),
  ],
);

Widget _wrap() =>
    ProviderScope(child: MaterialApp.router(routerConfig: _router()));

void main() {
  // Sonuç bölümü uzun ListView'in altında kalır; testte tüm içerik render
  // olsun diye yüksek bir yüzey kullan.
  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
  }

  testWidgets('ekran açılır ve başlığı gösterir', (tester) async {
    await pumpTall(tester);
    expect(find.text(AppStrings.calcDoughYieldTitle), findsOneWidget);
  });

  testWidgets('açılışta default değerlerle sonuç hesaplanır (316 adet)', (
    tester,
  ) async {
    await pumpTall(tester);
    // initState postFrame recalculate → SONUÇ bölümü + hero "tahmini adet"
    // kartı (StatCard etiketi büyük harfe çevirir).
    expect(find.text('SONUÇ'), findsOneWidget);
    expect(find.text('Tahmini adet'.toUpperCase()), findsOneWidget);
    expect(find.text('316'), findsOneWidget);
  });

  testWidgets('Hesapla butonu sonucu yeniden üretir', (tester) async {
    await pumpTall(tester);
    // AppPrimaryButton label'ı büyük harfe çevirir → 'HESAPLA'.
    await tester.tap(find.text(AppStrings.calculate.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text('316'), findsOneWidget);
  });
}
