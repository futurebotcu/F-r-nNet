import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/feature_lock.dart';
import 'package:firin_defter/features/subscriptions/models/pricing_config.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/paywall_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'T',
      accountType: account,
      city: 'Istanbul',
      roleBadge: 'X',
      email: 't@t.com',
    );
  }
}

void main() {
  group('PricingConfig launch Premium fallback', () {
    test('new fallback prices and yearly saving are centralized', () {
      expect(PricingConfig.premiumMonthly, 499);
      expect(PricingConfig.premiumYearly, 4990);
      expect(PricingConfig.premiumYearlyRegular, 5988);
      expect(PricingConfig.premiumYearlySavings, 998);
      expect(PricingConfig.premiumMonthlyLabel, '499 TL / ay');
      expect(PricingConfig.premiumYearlyLabel, '4.990 TL / yıl');
      expect(PricingConfig.premiumYearlySavingsLabel, '2 Ay Bizden');
    });
  });

  group('Paywall sheet launch promo copy', () {
    testWidgets('first premium gate offers free usage, not store purchase', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.free),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showPaywallSheet(context, FeatureLock.branches),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paywallPromoTitle), findsOneWidget);
      expect(find.text(AppStrings.paywallPromoCta), findsOneWidget);
      expect(find.text(AppStrings.paywallPromoBulletCard), findsOneWidget);
      expect(find.text(AppStrings.paywallPromoBulletNoRenew), findsOneWidget);
    });
  });

  group('PlansScreen launch prices', () {
    Future<void> pumpPlans(WidgetTester tester, AccountType account) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, account),
            ),
            subscriptionRepositoryProvider.overrideWithValue(
              LocalSubscriptionRepository(plan: BusinessPlan.free),
            ),
          ],
          child: const MaterialApp(home: PlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('commercial shows Free + Premium fallback price, not old Pro price', (tester) async {
      await pumpPlans(tester, AccountType.commercial);
      expect(find.byKey(const ValueKey('plan_tile_free')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_premium')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_pro')), findsNothing);
      expect(find.text('0 TL'), findsOneWidget);
      expect(find.text(PricingConfig.premiumMonthlyLabel), findsOneWidget);
      expect(find.text(AppStrings.plansLaunchTrialCta), findsOneWidget);
    });

    testWidgets('supplier uses same simplified Premium offer', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(find.byKey(const ValueKey('plan_tile_free')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_premium')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_pro')), findsNothing);
      expect(find.text(PricingConfig.premiumMonthlyLabel), findsOneWidget);
    });
  });
}
