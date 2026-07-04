import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_tools_registry.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/calculators_hub_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Premium hub yenilemesi: "Bugün lazım olur" kısayolları, 2 kolonlu
/// ızgara, 320dp dar ekran ve route bütünlüğü. Formül/motor/visibility
/// değişmediğini registry seviyesinde de sabitler.
class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, BakeryProfile? profile) {
    state = profile;
  }
}

/// Registry'deki TÜM araç route'ları için stub sayfa üreten router —
/// kart dokunuşunun aracın mevcut route'una gittiğini kanıtlar.
GoRouter _router() => GoRouter(
  initialLocation: '/calculator',
  routes: [
    GoRoute(
      path: '/calculator',
      builder: (_, __) => const CalculatorsHubScreen(),
    ),
    for (final tool in CalculatorToolsRegistry.all)
      GoRoute(
        path: tool.route,
        builder: (_, __) =>
            Scaffold(body: Center(child: Text('stub:${tool.id}'))),
      ),
  ],
);

Widget _wrap(BakeryProfile? profile) {
  return ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith(
        (ref) => _FixedProfileController(ref, profile),
      ),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  );
}

BakeryProfile _profile(AccountType type) => BakeryProfile(
  displayName: 'Test',
  accountType: type,
  city: 'İstanbul',
  roleBadge: 'Usta',
  email: 't@t.com',
);

Future<void> _pump(
  WidgetTester tester,
  AccountType type, {
  Size size = const Size(1200, 4000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(_profile(type)));
  await tester.pumpAndSettle();
}

void main() {
  group('featuredForAccount — registry', () {
    test('patron kısayolları: kapanış/maliyet/stok/sabah/fiyat/bayi', () {
      final ids = CalculatorToolsRegistry.featuredForAccount(
        AccountType.commercial,
      ).map((t) => t.id).toList();
      expect(ids, [
        'daily_close',
        'cost_profit',
        'stock_runway',
        'morning_plan',
        'price_update',
        'dealer_profit',
      ]);
    });

    test('bireysel kısayolları: hamur/kıvam/stok/tepsi/mayalanma/mesai', () {
      final ids = CalculatorToolsRegistry.featuredForAccount(
        AccountType.individual,
      ).map((t) => t.id).toList();
      expect(ids, [
        'dough_yield',
        'water_ratio',
        'stock_runway',
        'batch_value',
        'fermentation_time',
        'overtime_pay',
      ]);
    });

    test('toptancıda kısayol yok', () {
      expect(
        CalculatorToolsRegistry.featuredForAccount(AccountType.wholesaler),
        isEmpty,
      );
    });

    test(
      'kısayollar rol görünürlüğünün alt kümesidir (visibility bozulmaz)',
      () {
        for (final type in AccountType.values) {
          final visibleIds = CalculatorToolsRegistry.forAccount(
            type,
          ).map((t) => t.id).toSet();
          for (final tool in CalculatorToolsRegistry.featuredForAccount(type)) {
            expect(visibleIds, contains(tool.id));
          }
        }
      },
    );
  });

  group('premium hub — widget', () {
    testWidgets('patron: "Bugün lazım olur" başlığı ve 6 kısayol kartı', (
      tester,
    ) async {
      await _pump(tester, AccountType.commercial);
      expect(find.text(AppStrings.calcHubFeaturedTitle), findsOneWidget);
      for (final id in [
        'daily_close',
        'cost_profit',
        'stock_runway',
        'morning_plan',
        'price_update',
        'dealer_profit',
      ]) {
        expect(find.byKey(ValueKey('featured_$id')), findsOneWidget);
      }
    });

    testWidgets('bireysel: 6 kısayol kartı doğru araçları gösterir', (
      tester,
    ) async {
      await _pump(tester, AccountType.individual);
      expect(find.text(AppStrings.calcHubFeaturedTitle), findsOneWidget);
      for (final id in [
        'dough_yield',
        'water_ratio',
        'stock_runway',
        'batch_value',
        'fermentation_time',
        'overtime_pay',
      ]) {
        expect(find.byKey(ValueKey('featured_$id')), findsOneWidget);
      }
      // Patron kısayolu bireyselde görünmez.
      expect(find.byKey(const ValueKey('featured_daily_close')), findsNothing);
    });

    testWidgets('toptancı: kısayol bölümü yok, boş durum korunur', (
      tester,
    ) async {
      await _pump(tester, AccountType.wholesaler);
      expect(find.text(AppStrings.calcHubFeaturedTitle), findsNothing);
      expect(find.text(AppStrings.calcHubEmpty), findsOneWidget);
    });

    testWidgets('kategori başlığında araç sayacı görünür', (tester) async {
      await _pump(tester, AccountType.commercial);
      final daily = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      ).first;
      expect(
        find.text('${daily.tools.length} ${AppStrings.calcHubToolCountSuffix}'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('kısayol kartı dokunuşu aracın mevcut route\'una gider', (
      tester,
    ) async {
      await _pump(tester, AccountType.commercial);
      await tester.tap(find.byKey(const ValueKey('featured_stock_runway')));
      await tester.pumpAndSettle();
      expect(find.text('stub:stock_runway'), findsOneWidget);
    });

    testWidgets('kategori kartı dokunuşu aracın mevcut route\'una gider', (
      tester,
    ) async {
      await _pump(tester, AccountType.individual);
      await tester.tap(find.byKey(const ValueKey('tool_dough_yield')));
      await tester.pumpAndSettle();
      expect(find.text('stub:dough_yield'), findsOneWidget);
    });

    testWidgets('patron hub 320dp genişlikte taşma yapmaz (29 araç)', (
      tester,
    ) async {
      // Tüm kartların build olması için çok uzun yüzey; RenderFlex taşması
      // testte hata fırlatırdı — geçiyorsa 2 kolon 320dp'de güvenli.
      await _pump(tester, AccountType.commercial, size: const Size(320, 8000));
      expect(find.text(AppStrings.calcHubFeaturedTitle), findsOneWidget);
      expect(find.text(AppStrings.calcCatStaffShareTitle), findsOneWidget);
    });

    testWidgets('bireysel hub 320dp genişlikte taşma yapmaz', (tester) async {
      await _pump(tester, AccountType.individual, size: const Size(320, 6000));
      expect(find.text(AppStrings.calcHubFeaturedTitle), findsOneWidget);
      expect(find.text(AppStrings.calcCatProductionTitle), findsOneWidget);
    });
  });
}
