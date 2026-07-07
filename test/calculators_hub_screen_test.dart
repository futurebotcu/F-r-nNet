import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/screens/calculators_hub_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
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
  // Liste uzadığı için tüm kartların render olabilmesi adına yüksek yüzey.
  Future<void> pumpTall(WidgetTester tester, AccountType type) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(_profile(type)));
    await tester.pumpAndSettle();
  }

  testWidgets('hub açılır ve başlığı gösterir', (tester) async {
    await tester.pumpWidget(_wrap(_profile(AccountType.individual)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calcHubTitle), findsOneWidget);
  });

  testWidgets('bireysel rolde Hamurdan Ürün aracı listelenir', (tester) async {
    // Premium hub: araç hem "Bugün lazım olur" kısayolunda hem kendi
    // kategorisinde görünebilir; en az bir kart yeterli.
    await pumpTall(tester, AccountType.individual);
    expect(find.text(AppStrings.calcDoughYieldTitle), findsAtLeastNWidgets(1));
  });

  testWidgets('ticari rolde Hamurdan Ürün aracı listelenir', (tester) async {
    // Ticari tarafta Günlük Hızlı bölümü en üstte; yine de tüm kartların
    // render olabilmesi için yüksek yüzey kullan.
    await pumpTall(tester, AccountType.commercial);
    expect(find.text(AppStrings.calcDoughYieldTitle), findsAtLeastNWidgets(1));
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
    // Araç kısayol + kategori kartı olarak iki kez görünebilir; ikisi de
    // aynı route'a gider — ilkine dokunmak yeterli.
    await tester.tap(find.text(AppStrings.calcDoughYieldTitle).first);
    await tester.pumpAndSettle();
    expect(find.text('DoughScreen — stub'), findsOneWidget);
  });

  testWidgets('patron (ticari) patron kartını görür, çalışan kartını görmez', (
    tester,
  ) async {
    await pumpTall(tester, AccountType.commercial);
    expect(find.text(AppStrings.calcCostProfitTitle), findsAtLeastNWidgets(1));
    expect(find.text(AppStrings.calcMorningPlanTitle), findsAtLeastNWidgets(1));
    expect(find.text(AppStrings.calcWaterTempTitle), findsNothing);
  });

  testWidgets(
    'bireysel çalışan + ortak kartları görür, patron kartını görmez',
    (tester) async {
      await pumpTall(tester, AccountType.individual);
      expect(find.text(AppStrings.calcWaterTempTitle), findsAtLeastNWidgets(1));
      expect(
        find.text(AppStrings.calcMorningPlanTitle),
        findsAtLeastNWidgets(1),
      );
      expect(find.text(AppStrings.calcCostProfitTitle), findsNothing);
    },
  );

  testWidgets('kategori bölüm başlıkları gösterilir', (tester) async {
    await pumpTall(tester, AccountType.commercial);
    expect(find.text(AppStrings.calcCatDailyQuickTitle), findsOneWidget);
    expect(find.text(AppStrings.calcCatProductionTitle), findsOneWidget);
    expect(find.text(AppStrings.calcCatBossCostTitle), findsOneWidget);
    expect(find.text(AppStrings.calcCatSupplierTitle), findsOneWidget);
  });

  testWidgets('kartta Offline rozeti yok, üstte tek offline notu var', (
    tester,
  ) async {
    await pumpTall(tester, AccountType.individual);
    // Cila: rozet karttan kaldırıldı; offline bilgisi yalnız üst notta.
    expect(find.text(AppStrings.calcOfflineBadge), findsNothing);
    expect(find.text(AppStrings.calcHubOfflineNote), findsOneWidget);
  });

  testWidgets(
    'patron sıralaması: Günlük Hızlı → Maliyet/Kâr → Üretim → Tedarikçi',
    (tester) async {
      await pumpTall(tester, AccountType.commercial);
      final daily = tester
          .getTopLeft(find.text(AppStrings.calcCatDailyQuickTitle))
          .dy;
      final bossCost = tester
          .getTopLeft(find.text(AppStrings.calcCatBossCostTitle))
          .dy;
      final production = tester
          .getTopLeft(find.text(AppStrings.calcCatProductionTitle))
          .dy;
      final supplier = tester
          .getTopLeft(find.text(AppStrings.calcCatSupplierTitle))
          .dy;
      expect(daily, lessThan(bossCost));
      expect(bossCost, lessThan(production));
      expect(production, lessThan(supplier));
    },
  );

  testWidgets('bireysel sıralaması: Günlük Hızlı, Üretim\'in üstünde', (
    tester,
  ) async {
    await pumpTall(tester, AccountType.individual);
    final daily = tester
        .getTopLeft(find.text(AppStrings.calcCatDailyQuickTitle))
        .dy;
    final production = tester
        .getTopLeft(find.text(AppStrings.calcCatProductionTitle))
        .dy;
    expect(daily, lessThan(production));
  });

  // ── Paywall UI V1 — ticari plan kilitleri ──
  GoRouter routerWithCostProfit() => GoRouter(
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
      GoRoute(
        path: '/calculator/cost-profit',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('CostProfit — stub'))),
      ),
      GoRoute(
        path: '/plans',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Plans — stub'))),
      ),
    ],
  );

  Future<void> pumpCommercialPlan(
    WidgetTester tester,
    BusinessPlan plan,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(
            (ref) =>
                _FixedProfileController(ref, _profile(AccountType.commercial)),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            LocalSubscriptionRepository(plan: plan),
          ),
        ],
        child: MaterialApp.router(routerConfig: routerWithCostProfit()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('free ticari: Pro aracı (Maliyet/Kâr) tıklanınca paywall', (
    tester,
  ) async {
    await pumpCommercialPlan(tester, BusinessPlan.free);
    // Kilit rozeti "Pro" görünür (en az bir kart).
    expect(find.text(AppStrings.paywallProTag), findsAtLeastNWidgets(1));
    await tester.tap(find.text(AppStrings.calcCostProfitTitle).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paywall_sheet')), findsOneWidget);
    // Navigasyon OLMADI (stub ekranı yok).
    expect(find.text('CostProfit — stub'), findsNothing);
  });

  testWidgets('free ticari: Free aracı (Hamurdan Ürün) normal açılır', (
    tester,
  ) async {
    await pumpCommercialPlan(tester, BusinessPlan.free);
    await tester.tap(find.text(AppStrings.calcDoughYieldTitle).first);
    await tester.pumpAndSettle();
    expect(find.text('DoughScreen — stub'), findsOneWidget);
  });

  testWidgets('premium ticari: Pro aracı kilitsiz, normal açılır', (
    tester,
  ) async {
    await pumpCommercialPlan(tester, BusinessPlan.premium);
    // Kilit rozeti yok.
    expect(find.text(AppStrings.paywallProTag), findsNothing);
    expect(find.text(AppStrings.paywallPremiumTag), findsNothing);
    await tester.tap(find.text(AppStrings.calcCostProfitTitle).first);
    await tester.pumpAndSettle();
    expect(find.text('CostProfit — stub'), findsOneWidget);
  });
}
