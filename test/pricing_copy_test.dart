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
import 'package:intl/date_symbol_data_local.dart';

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
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('PricingConfig launch Premium fallback', () {
    test('lansman fiyatları kuruş hassasiyetiyle tek kaynaktan', () {
      expect(PricingConfig.premiumMonthlyCents, 49999);
      expect(PricingConfig.premiumYearlyCents, 499990);
      expect(PricingConfig.premiumYearlyRegularCents, 599988);
      expect(PricingConfig.premiumYearlySavingsCents, 99998);
      expect(PricingConfig.premiumMonthlyLabel, '499,99 TL / ay');
      expect(PricingConfig.premiumYearlyLabel, '4.999,90 TL / yıl');
      expect(PricingConfig.premiumYearlySavingsLabel, '2 Ay Bizden');
    });
  });

  group('Paywall sheet lansman kopyası', () {
    testWidgets(
      'kilit: promo CTA YOK; lansman fiyatı + temel özellik notu var',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionRepositoryProvider.overrideWithValue(
                LocalSubscriptionRepository(
                  plan: BusinessPlan.free,
                  launchPriceUntil:
                      DateTime.parse('2027-10-01T00:00:00+03:00'),
                ),
              ),
            ],
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
        // Eski CTA promosu kaldırıldı: ücretsiz dönem kayıt bazlı otomatik.
        expect(find.text('Ücretsiz Kullanmaya Başla'), findsNothing);
        expect(find.textContaining('3 ay'), findsNothing);
        expect(find.text(FeatureLock.branches.title), findsOneWidget);
        expect(
          find.byKey(const ValueKey('paywall_price_hint')),
          findsOneWidget,
        );
        expect(find.textContaining('499,99'), findsOneWidget);
        expect(find.text(AppStrings.paywallBasicsStayFree), findsOneWidget);
        expect(
          find.byKey(const ValueKey('paywall_launch_price_until')),
          findsOneWidget,
        );
        expect(find.text(AppStrings.paywallUpgradeCta), findsOneWidget);
      },
    );
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

    testWidgets(
      'commercial: Free "Her zaman ücretsiz" + Premium lansman fiyatı',
      (tester) async {
        await pumpPlans(tester, AccountType.commercial);
        expect(find.byKey(const ValueKey('plan_tile_free')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plan_tile_premium')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('plan_tile_pro')), findsNothing);
        expect(find.text(AppStrings.planFreeAlwaysLabel), findsOneWidget);
        expect(find.text(PricingConfig.premiumMonthlyLabel), findsOneWidget);
        expect(find.text(AppStrings.plansLaunchTrialCta), findsOneWidget);
        // Eski "3 ay" dili yok.
        expect(find.textContaining('3 ay'), findsNothing);
      },
    );

    testWidgets('supplier uses same simplified Premium offer', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(find.byKey(const ValueKey('plan_tile_free')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_premium')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_tile_pro')), findsNothing);
      expect(find.text(PricingConfig.premiumMonthlyLabel), findsOneWidget);
    });
  });
}
