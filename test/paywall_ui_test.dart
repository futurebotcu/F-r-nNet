import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_min_plan.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_entitlements.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/feature_lock.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/widgets/paywall_sheet.dart';
import 'package:firin_defter/features/subscriptions/widgets/plan_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessEntitlements _ent(
  BusinessPlan plan, {
  bool promo = false,
  int days = 0,
}) =>
    BusinessEntitlements(
      plan: plan,
      effectivePlan: promo ? BusinessPlan.premium : plan,
      isTrialActive: promo,
      daysLeft: days,
      recipeLimit: promo || plan == BusinessPlan.premium ? -1 : 5,
      dealerLimit: promo || plan == BusinessPlan.premium ? -1 : 0,
      canUseBranches: promo || plan == BusinessPlan.premium,
      canUseDebtExpense: promo || plan == BusinessPlan.premium,
      canUseDealerDriverOps: promo || plan == BusinessPlan.premium,
      promoStatus: promo ? 'active' : 'not_started',
      promoExpiresAt: promo ? DateTime.now().add(Duration(days: days)) : null,
      canStartPromo: !promo,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('PlanBadge', () {
    testWidgets('free/premium/promo labels', (tester) async {
      await _pump(tester, PlanBadge(entitlements: _ent(BusinessPlan.free)));
      expect(find.text(AppStrings.planFreeLabel), findsOneWidget);

      await _pump(tester, PlanBadge(entitlements: _ent(BusinessPlan.premium)));
      expect(find.text(AppStrings.planPremiumLabel), findsOneWidget);

      await _pump(
        tester,
        PlanBadge(entitlements: _ent(BusinessPlan.free, promo: true, days: 21)),
      );
      expect(find.text(AppStrings.planLaunchPromoLabel), findsOneWidget);
    });
  });

  group('showPaywallSheet (ticari lansman modeli)', () {
    testWidgets(
      'promo CTA yok; kilit bilgisi + Paketleri incele; promo başlatılmaz',
      (tester) async {
        final repo = LocalSubscriptionRepository(plan: BusinessPlan.free);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () =>
                        showPaywallSheet(context, FeatureLock.branches),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        // Eski "Ücretsiz Kullanmaya Başla" promo akışı kaldırıldı.
        expect(find.text('Ücretsiz Kullanmaya Başla'), findsNothing);
        expect(find.text(FeatureLock.branches.title), findsOneWidget);
        expect(find.text(AppStrings.paywallBasicsStayFree), findsOneWidget);
        expect(find.text(AppStrings.paywallUpgradeCta), findsOneWidget);

        final e = await repo.myEntitlement();
        expect(e.isLaunchPromoActive, isFalse);
      },
    );
  });

  group('CalculatorEntitlements premium gate', () {
    test('free commercial gets locks, promo/premium opens all', () {
      final free = _ent(BusinessPlan.free);
      expect(
        CalculatorEntitlements.lockFor(
          toolId: 'cost_profit',
          entitlements: free,
          isCommercial: true,
        ),
        FeatureLock.calculatorPro,
      );

      for (final e in [
        _ent(BusinessPlan.premium),
        _ent(BusinessPlan.free, promo: true, days: 30),
      ]) {
        for (final id in ['dough_yield', 'cost_profit', 'master_earnings']) {
          expect(
            CalculatorEntitlements.lockFor(
              toolId: id,
              entitlements: e,
              isCommercial: true,
            ),
            isNull,
          );
        }
      }
    });

    test('unknown calculator remains free tier', () {
      expect(
        CalculatorEntitlements.minPlanFor('unknown_tool'),
        CalculatorMinPlan.free,
      );
    });
  });
}
