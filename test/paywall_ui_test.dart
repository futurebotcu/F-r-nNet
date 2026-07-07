import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_min_plan.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/feature_lock.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/paywall_sheet.dart';
import 'package:firin_defter/features/subscriptions/widgets/plan_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticari İşletme Paywall UI V1 — widget + kilit config + metin testleri.
BusinessEntitlements _ent(
  BusinessPlan plan, {
  bool trial = false,
  int days = 0,
}) => BusinessEntitlements(
  plan: trial ? BusinessPlan.free : plan,
  effectivePlan: trial ? BusinessPlan.premium : plan,
  isTrialActive: trial,
  daysLeft: days,
  recipeLimit: switch (trial ? BusinessPlan.premium : plan) {
    BusinessPlan.premium => -1,
    BusinessPlan.pro => 50,
    BusinessPlan.free => 5,
  },
  dealerLimit: (trial ? BusinessPlan.premium : plan) == BusinessPlan.free
      ? 0
      : -1,
  canUseBranches: trial || plan == BusinessPlan.premium,
  canUseDebtExpense:
      trial || plan == BusinessPlan.pro || plan == BusinessPlan.premium,
  canUseDealerDriverOps: trial || plan == BusinessPlan.premium,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('PlanBadge', () {
    testWidgets('free/pro/premium/trial doğru etiket', (tester) async {
      await _pump(tester, PlanBadge(entitlements: _ent(BusinessPlan.free)));
      expect(find.text(AppStrings.planFreeLabel), findsOneWidget);

      await _pump(tester, PlanBadge(entitlements: _ent(BusinessPlan.pro)));
      expect(find.text(AppStrings.planProLabel), findsOneWidget);

      await _pump(tester, PlanBadge(entitlements: _ent(BusinessPlan.premium)));
      expect(find.text(AppStrings.planPremiumLabel), findsOneWidget);

      await _pump(
        tester,
        PlanBadge(entitlements: _ent(BusinessPlan.free, trial: true, days: 21)),
      );
      expect(find.text(AppStrings.planTrialLabel), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(8),
          child: PlanBadge(entitlements: _ent(BusinessPlan.premium)),
        ),
        size: const Size(320, 600),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('LockedFeatureBadge', () {
    testWidgets('pro/premium etiket + kilit ikonu', (tester) async {
      await _pump(
        tester,
        const LockedFeatureBadge(requiredPlan: BusinessPlan.pro),
      );
      expect(find.text(AppStrings.paywallProTag), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await _pump(
        tester,
        const LockedFeatureBadge(requiredPlan: BusinessPlan.premium),
      );
      expect(find.text(AppStrings.paywallPremiumTag), findsOneWidget);
    });
  });

  group('Paywall sheet metinleri — Pro bayi anlatımı DOĞRU', () {
    test(
      'dealerBook metni "1 bayi" içermez, sınırsız/tek kullanıcı anlatır',
      () {
        final body = FeatureLock.dealerBook.body;
        final title = FeatureLock.dealerBook.title;
        expect(body.contains('1 bayi'), isFalse);
        expect(title.contains('1 bayi'), isFalse);
        expect(body.contains('tek bayi'), isFalse);
        expect(body.contains('1 aktif bayi'), isFalse);
        expect(body.contains('sınırsız'), isTrue);
        expect(body.contains('tek kullanıcı'), isTrue);
        expect(FeatureLock.dealerBook.requiredPlan, BusinessPlan.pro);
      },
    );

    test('dealerDriverOps şoförlü/ekipli operasyonu Premium anlatır', () {
      expect(FeatureLock.dealerDriverOps.title.contains('Şoför'), isTrue);
      expect(FeatureLock.dealerDriverOps.requiredPlan, BusinessPlan.premium);
    });

    test('branches Premium, debtExpense Pro', () {
      expect(FeatureLock.branches.requiredPlan, BusinessPlan.premium);
      expect(FeatureLock.debtExpense.requiredPlan, BusinessPlan.pro);
    });

    test('hiçbir paywall metni "1 bayi/tek bayi/1 aktif bayi" içermez', () {
      final all = [
        FeatureLock.branches,
        FeatureLock.dealerBook,
        FeatureLock.dealerDriverOps,
        FeatureLock.debtExpense,
        FeatureLock.recipeFree,
        FeatureLock.recipePro,
        FeatureLock.calculatorPro,
        FeatureLock.calculatorPremium,
        FeatureLock.reportPro,
        FeatureLock.reportPremium,
      ];
      for (final l in all) {
        final t = '${l.title} ${l.body}';
        expect(t.contains('1 bayi'), isFalse, reason: t);
        expect(t.contains('tek bayi'), isFalse, reason: t);
        expect(t.contains('1 aktif bayi'), isFalse, reason: t);
      }
    });
  });

  group('showPaywallSheet', () {
    testWidgets('kilit içeriğini + Paketler CTA gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showPaywallSheet(context, FeatureLock.dealerBook),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall_sheet')), findsOneWidget);
      expect(find.text(FeatureLock.dealerBook.title), findsOneWidget);
      expect(find.byKey(const ValueKey('paywall_view_plans')), findsOneWidget);
    });
  });

  group('CalculatorEntitlements config', () {
    test('tier atamaları: free/pro/premium örnekleri', () {
      expect(
        CalculatorEntitlements.minPlanFor('dough_yield'),
        CalculatorMinPlan.free,
      );
      expect(
        CalculatorEntitlements.minPlanFor('cost_profit'),
        CalculatorMinPlan.pro,
      );
      expect(
        CalculatorEntitlements.minPlanFor('master_earnings'),
        CalculatorMinPlan.premium,
      );
      // Bilinmeyen id → free.
      expect(
        CalculatorEntitlements.minPlanFor('unknown_tool'),
        CalculatorMinPlan.free,
      );
    });

    test('bireysel kullanıcıya kilit uygulanmaz (isCommercial=false)', () {
      final lock = CalculatorEntitlements.lockFor(
        toolId: 'master_earnings',
        entitlements: _ent(BusinessPlan.free),
        isCommercial: false,
      );
      expect(lock, isNull);
    });

    test(
      'free ticari: pro aracı kilitli, premium aracı kilitli, free açık',
      () {
        final e = _ent(BusinessPlan.free);
        expect(
          CalculatorEntitlements.lockFor(
            toolId: 'dough_yield',
            entitlements: e,
            isCommercial: true,
          ),
          isNull,
        );
        expect(
          CalculatorEntitlements.lockFor(
            toolId: 'cost_profit',
            entitlements: e,
            isCommercial: true,
          ),
          FeatureLock.calculatorPro,
        );
        expect(
          CalculatorEntitlements.lockFor(
            toolId: 'master_earnings',
            entitlements: e,
            isCommercial: true,
          ),
          FeatureLock.calculatorPremium,
        );
      },
    );

    test('pro ticari: pro aracı açık, premium aracı kilitli', () {
      final e = _ent(BusinessPlan.pro);
      expect(
        CalculatorEntitlements.lockFor(
          toolId: 'cost_profit',
          entitlements: e,
          isCommercial: true,
        ),
        isNull,
      );
      expect(
        CalculatorEntitlements.lockFor(
          toolId: 'labor_index',
          entitlements: e,
          isCommercial: true,
        ),
        FeatureLock.calculatorPremium,
      );
    });

    test('premium/trial ticari: tüm araçlar açık', () {
      for (final e in [
        _ent(BusinessPlan.premium),
        _ent(BusinessPlan.free, trial: true, days: 10),
      ]) {
        for (final id in ['dough_yield', 'cost_profit', 'master_earnings']) {
          expect(
            CalculatorEntitlements.lockFor(
              toolId: id,
              entitlements: e,
              isCommercial: true,
            ),
            isNull,
            reason: '$id / ${e.effectivePlan}',
          );
        }
      }
    });
  });

  group('PlansScreen', () {
    Future<void> pumpPlans(
      WidgetTester tester,
      BusinessPlan plan, {
      bool trial = false,
    }) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(
                plan: plan,
                trialActive: trial,
                trialDaysLeft: 21,
              ),
            ),
          ],
          child: const MaterialApp(home: PlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Free/Pro/Premium üç plan kartı + destek CTA', (tester) async {
      await pumpPlans(tester, BusinessPlan.free);
      expect(find.byKey(const ValueKey('plan_tile_free')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_pro')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_premium')), findsOneWidget);
      expect(find.byKey(const ValueKey('plans_support_cta')), findsOneWidget);
    });

    testWidgets('Pro plan özelliği "1 bayi" içermez, sınırsız anlatır', (
      tester,
    ) async {
      await pumpPlans(tester, BusinessPlan.free);
      expect(AppStrings.planProFeatures.contains('1 bayi'), isFalse);
      expect(AppStrings.planProFeatures.contains('sınırsız bayi'), isTrue);
    });

    testWidgets('trial aktifken deneme banner + kalan gün', (tester) async {
      await pumpPlans(tester, BusinessPlan.free, trial: true);
      expect(find.byKey(const ValueKey('plans_trial_banner')), findsOneWidget);
    });
  });

  group('Entitlement UX aynası — reçete/bayi limitleri', () {
    test('free reçete 5 limitinde eklenemez', () {
      final e = _ent(BusinessPlan.free);
      expect(e.canAddRecipe(4), isTrue);
      expect(e.canAddRecipe(5), isFalse);
    });

    test('pro reçete 50 limitinde eklenemez, bayi sınırsız', () {
      final e = _ent(BusinessPlan.pro);
      expect(e.canAddRecipe(49), isTrue);
      expect(e.canAddRecipe(50), isFalse);
      expect(e.dealerEnabled, isTrue);
      expect(e.canAddDealer(99), isTrue);
      expect(e.canUseDealerDriverOps, isFalse);
    });

    test('premium sınırsız', () {
      final e = _ent(BusinessPlan.premium);
      expect(e.canAddRecipe(9999), isTrue);
      expect(e.canUseDealerDriverOps, isTrue);
    });
  });
}
