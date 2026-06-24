import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/calculators_hub_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Belirli bir hesap türünü dayatan test profil controller'ı.
/// Supabase kapalı olduğundan ProfileController constructor'ı auth'a
/// abone olmaz; state'i doğrudan sabitliyoruz.
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
    GoRoute(
      path: '/calculator/dough',
      builder: (_, __) =>
          const Scaffold(body: Center(child: Text('DoughScreen — stub'))),
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

void main() {
  testWidgets('hub açılır ve başlığı gösterir', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.individual)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calcHubTitle), findsOneWidget);
  });

  testWidgets('bireysel rolde Hamurdan Ürün aracı listelenir', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.individual)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calcDoughYieldTitle), findsOneWidget);
  });

  testWidgets('ticari rolde Hamurdan Ürün aracı listelenir', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.commercial)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calcDoughYieldTitle), findsOneWidget);
  });

  testWidgets('toptancı rolde araç yok → boş durum gösterir', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.wholesaler)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calcDoughYieldTitle), findsNothing);
    expect(find.text(AppStrings.calcHubEmpty), findsOneWidget);
  });

  testWidgets('araç kartına dokununca alt route\'a gider', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.individual)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.calcDoughYieldTitle));
    await tester.pumpAndSettle();
    expect(find.text('DoughScreen — stub'), findsOneWidget);
  });

  // Liste uzadığı için tüm kartların render olabilmesi adına yüksek yüzey.
  Future<void> pumpTall(WidgetTester tester, AccountType type) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(_profile(type)));
    await tester.pumpAndSettle();
  }

  testWidgets('patron (ticari) patron kartını görür, çalışan kartını görmez', (
    tester,
  ) async {
    await pumpTall(tester, AccountType.commercial);
    expect(find.text(AppStrings.calcCostProfitTitle), findsOneWidget);
    expect(find.text(AppStrings.calcMorningPlanTitle), findsOneWidget);
    expect(find.text(AppStrings.calcWaterTempTitle), findsNothing);
  });

  testWidgets(
    'bireysel çalışan + ortak kartları görür, patron kartını görmez',
    (tester) async {
      await pumpTall(tester, AccountType.individual);
      expect(find.text(AppStrings.calcWaterTempTitle), findsOneWidget);
      expect(find.text(AppStrings.calcMorningPlanTitle), findsOneWidget);
      expect(find.text(AppStrings.calcCostProfitTitle), findsNothing);
    },
  );
}
