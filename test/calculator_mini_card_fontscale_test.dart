import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_tools_registry.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/calculators_hub_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Büyük sistem yazı ölçeği (1.3x) cilası: ızgara satır yüksekliği yazı
/// ölçeğiyle kontrollü büyür; 2 satıra saran mini kart başlığının ikinci
/// satırı alttan kırpılmaz. 1.0x görünüm (142) birebir korunur.
class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, BakeryProfile? profile) {
    state = profile;
  }
}

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
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(_wrap(_profile(type)));
  await tester.pumpAndSettle();
}

double _gridExtent(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.mainAxisExtent!;
}

void main() {
  testWidgets('1.0x: ızgara yüksekliği birebir eski değer (142)', (
    tester,
  ) async {
    await _pump(tester, AccountType.commercial, size: const Size(1200, 4000));
    expect(_gridExtent(tester), 142.0);
  });

  testWidgets('1.3x: ızgara yüksekliği kontrollü büyür', (tester) async {
    await _pump(
      tester,
      AccountType.commercial,
      size: const Size(1200, 5000),
      textScale: 1.3,
    );
    final extent = _gridExtent(tester);
    expect(extent, greaterThan(142.0));
    expect(extent, lessThanOrEqualTo(220.0));
  });

  testWidgets(
    'patron 320dp + 1.3x: taşma yok, 2 satırlık başlık kırpılmadan sığar',
    (tester) async {
      // RenderFlex taşması testte hata fırlatır; ayrıca 2 satıra saran
      // başlığın tam ölçekli yüksekliği (2 × 13.5 × 1.2 × 1.3 ≈ 42px)
      // aldığını doğrula — kırpılan/kısılan başlık bundan kısa kalırdı.
      await _pump(
        tester,
        AccountType.commercial,
        size: const Size(320, 9000),
        textScale: 1.3,
      );
      final titleSize = tester.getSize(
        find.text(AppStrings.calcDailyCloseTitle).first,
      );
      expect(titleSize.height, greaterThanOrEqualTo(40.0));
    },
  );

  testWidgets('bireysel 320dp + 1.3x: taşma yok, kısayollar yerinde', (
    tester,
  ) async {
    await _pump(
      tester,
      AccountType.individual,
      size: const Size(320, 7000),
      textScale: 1.3,
    );
    expect(find.text(AppStrings.calcHubFeaturedTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey('featured_fermentation_time')),
      findsOneWidget,
    );
    final titleSize = tester.getSize(
      find.text(AppStrings.calcFermentationTitle).first,
    );
    expect(titleSize.height, greaterThanOrEqualTo(40.0));
  });

  testWidgets('toptancı 1.3x: boş durum korunur', (tester) async {
    await _pump(
      tester,
      AccountType.wholesaler,
      size: const Size(320, 2000),
      textScale: 1.3,
    );
    expect(find.text(AppStrings.calcHubFeaturedTitle), findsNothing);
    expect(find.text(AppStrings.calcHubEmpty), findsOneWidget);
  });
}
