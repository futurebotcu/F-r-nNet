import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_entitlements.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/feature_lock.dart';
import 'package:firin_defter/features/subscriptions/models/listing_fee.dart';
import 'package:firin_defter/features/subscriptions/models/supplier_paywall.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:firin_defter/features/subscriptions/screens/plans_screen.dart';
import 'package:firin_defter/features/subscriptions/widgets/supplier_plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BusinessEntitlements> _entOf(BusinessPlan plan, {bool promo = false}) =>
    LocalSubscriptionRepository(
      plan: plan,
      trialActive: promo,
      trialDaysLeft: 30,
    ).myEntitlement();

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'T',
      accountType: account,
      city: 'Istanbul',
      roleBadge: 'Tedarikci',
      email: 't@t.com',
    );
  }
}

void main() {
  group('SupplierPaywall.productLock', () {
    test('free: first product open, second product locked', () async {
      final e = await _entOf(BusinessPlan.free);
      expect(SupplierPaywall.productLock(e, 0), isNull);
      expect(
        SupplierPaywall.productLock(e, 1),
        FeatureLock.supplierProductFree,
      );
    });

    test('legacy pro: backward compatibility unlocks Premium limits', () async {
      final e = await _entOf(BusinessPlan.pro);
      expect(SupplierPaywall.productLock(e, 999), isNull);
    });

    test('premium is unlimited; personal promo does NOT unlock supplier', () async {
      expect(
        SupplierPaywall.productLock(await _entOf(BusinessPlan.premium), 999),
        isNull,
      );
      // Kampanya modeli: kişisel 3 aylık promo tedarikçi haklarını AÇMAZ
      // (ortak bitiş kişisel promoyla uzatılamaz).
      expect(
        SupplierPaywall.productLock(
          await _entOf(BusinessPlan.free, promo: true),
          1,
        ),
        FeatureLock.supplierProductFree,
      );
    });
  });

  group('SupplierPaywall.campaignLock', () {
    test(
      'free campaign creation requires Premium; legacy pro is open',
      () async {
        expect(
          SupplierPaywall.campaignLock(await _entOf(BusinessPlan.free), 0),
          FeatureLock.supplierCampaignFree,
        );
        expect(
          SupplierPaywall.campaignLock(await _entOf(BusinessPlan.pro), 0),
          isNull,
        );
      },
    );

    test('premium is unlimited', () async {
      expect(
        SupplierPaywall.campaignLock(await _entOf(BusinessPlan.premium), 50),
        isNull,
      );
    });
  });

  group('SupplierPaywall.replyLock', () {
    test('server bool controls reply gate', () async {
      final free = await _entOf(BusinessPlan.free);
      expect(SupplierPaywall.replyLock(free), isNull);

      const exhaustedFree = BusinessEntitlements(
        supplierEffectivePlan: BusinessPlan.free,
        supplierCanReplyQuote: false,
      );
      expect(
        SupplierPaywall.replyLock(exhaustedFree),
        FeatureLock.supplierReplyFree,
      );

      const exhaustedPro = BusinessEntitlements(
        supplierEffectivePlan: BusinessPlan.pro,
        supplierCanReplyQuote: false,
      );
      expect(
        SupplierPaywall.replyLock(exhaustedPro),
        FeatureLock.supplierReplyPro,
      );
    });
  });

  group('ListingFee launch period', () {
    test('market listings are free while launch flag is off', () async {
      final e = await _entOf(BusinessPlan.free);
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.wholesaler,
          entitlements: e,
        ),
        0,
      );
    });

    test('job seek remains free', () {
      expect(
        ListingFee.amountCents(
          kind: ListingKind.jobSeek,
          account: AccountType.individual,
          entitlements: null,
        ),
        0,
      );
    });
  });

  Future<void> pumpCard(
    WidgetTester tester,
    BusinessPlan plan, {
    bool promo = false,
    int products = 0,
    int campaigns = 0,
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(
            LocalSubscriptionRepository(
              plan: plan,
              trialActive: promo,
              trialDaysLeft: 21,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SupplierPlanCard(
              productCount: products,
              campaignCount: campaigns,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SupplierPlanCard', () {
    testWidgets('free: title and free quotas', (tester) async {
      await pumpCard(tester, BusinessPlan.free, products: 1);
      expect(find.byKey(const ValueKey('supplier_plan_card')), findsOneWidget);
      expect(find.text(AppStrings.supPlanFreeTitle), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);
    });

    testWidgets('premium: unlimited quotas', (tester) async {
      await pumpCard(tester, BusinessPlan.premium);
      expect(find.text(AppStrings.supPlanPremiumTitle), findsOneWidget);
      expect(find.text(AppStrings.supQuotaUnlimited), findsWidgets);
    });

    testWidgets(
      'personal promo does not change supplier card (free copy stays)',
      (tester) async {
        await pumpCard(tester, BusinessPlan.free, promo: true);
        // Kişisel promo tedarikçi kartını premium'a çevirmez.
        expect(find.text(AppStrings.planLaunchPromoTitle), findsNothing);
        expect(find.text(AppStrings.supPlanFreeTitle), findsOneWidget);
        expect(find.text(AppStrings.supQuotaUnlimited), findsNothing);
      },
    );

    testWidgets('320dp + 1.3x does not overflow', (tester) async {
      await pumpCard(
        tester,
        BusinessPlan.free,
        products: 1,
        textScale: 1.3,
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PlansScreen supplier/commercial packages', () {
    Future<void> pumpPlans(WidgetTester tester, AccountType account) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

    testWidgets('wholesaler shows simplified Free + Premium offer', (
      tester,
    ) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(find.text(AppStrings.supPlanFreeFeatures), findsOneWidget);
      expect(find.text(AppStrings.supPlanPremiumFeatures), findsOneWidget);
      expect(find.text(AppStrings.supPlanProFeatures), findsNothing);
    });

    testWidgets('commercial shows simplified Free + Premium offer', (
      tester,
    ) async {
      await pumpPlans(tester, AccountType.commercial);
      expect(find.text(AppStrings.planFreeFeatures), findsOneWidget);
      expect(find.text(AppStrings.planPremiumFeatures), findsOneWidget);
      expect(find.text(AppStrings.planProFeatures), findsNothing);
    });
  });
}
