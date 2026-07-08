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

/// Tedarikçi/Toptancı Paywall UI V1 — helper + widget testleri.
/// Asıl kısıt server-side (RLS smoke 7 grup PASS); bu yalnız UX.
Future<BusinessEntitlements> _entOf(BusinessPlan plan, {bool trial = false}) =>
    LocalSubscriptionRepository(
      plan: plan,
      trialActive: trial,
      trialDaysLeft: 30,
    ).myEntitlement();

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'T',
      accountType: account,
      city: 'İstanbul',
      roleBadge: 'Tedarikçi',
      email: 't@t.com',
    );
  }
}

void main() {
  group('SupplierPaywall.productLock', () {
    test('free: 0<1 açık, 1 dolu → Pro lock', () async {
      final e = await _entOf(BusinessPlan.free);
      expect(SupplierPaywall.productLock(e, 0), isNull);
      expect(
        SupplierPaywall.productLock(e, 1),
        FeatureLock.supplierProductFree,
      );
    });
    test('pro: <5 açık, 5 dolu → Premium lock', () async {
      final e = await _entOf(BusinessPlan.pro);
      expect(SupplierPaywall.productLock(e, 4), isNull);
      expect(SupplierPaywall.productLock(e, 5), FeatureLock.supplierProductPro);
    });
    test('premium/trial: daima açık', () async {
      expect(
        SupplierPaywall.productLock(await _entOf(BusinessPlan.premium), 999),
        isNull,
      );
      final trial = await _entOf(BusinessPlan.free, trial: true);
      // Trial = Pro-like → 5 limit.
      expect(SupplierPaywall.productLock(trial, 4), isNull);
      expect(
        SupplierPaywall.productLock(trial, 5),
        FeatureLock.supplierProductPro,
      );
    });
  });

  group('SupplierPaywall.campaignLock', () {
    test('free: daima kilitli (limit 0) → Pro', () async {
      final e = await _entOf(BusinessPlan.free);
      expect(
        SupplierPaywall.campaignLock(e, 0),
        FeatureLock.supplierCampaignFree,
      );
    });
    test('pro: <3 açık, 3 dolu → Premium', () async {
      final e = await _entOf(BusinessPlan.pro);
      expect(SupplierPaywall.campaignLock(e, 2), isNull);
      expect(
        SupplierPaywall.campaignLock(e, 3),
        FeatureLock.supplierCampaignPro,
      );
    });
    test('premium: sınırsız açık', () async {
      expect(
        SupplierPaywall.campaignLock(await _entOf(BusinessPlan.premium), 50),
        isNull,
      );
    });
  });

  group('SupplierPaywall.replyLock (server bool)', () {
    test('canReply true → açık; false → plana göre lock', () async {
      final free = await _entOf(BusinessPlan.free); // canReply true default
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

  group('ListingFee — wholesaler muafiyeti', () {
    test('free wholesaler market 50 TL', () async {
      final e = await _entOf(BusinessPlan.free);
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.wholesaler,
          entitlements: e,
        ),
        5000,
      );
    });
    test('pro/premium/trial wholesaler market ücretsiz', () async {
      for (final e in [
        await _entOf(BusinessPlan.pro),
        await _entOf(BusinessPlan.premium),
        await _entOf(BusinessPlan.free, trial: true),
      ]) {
        expect(
          ListingFee.amountCents(
            kind: ListingKind.market,
            account: AccountType.wholesaler,
            entitlements: e,
          ),
          0,
          reason: e.supplierEffectivePlan.toString(),
        );
      }
    });
    test('commercial/bireysel ilan kuralları bozulmadı', () async {
      final freeComm = await _entOf(BusinessPlan.free);
      expect(
        ListingFee.amountCents(
          kind: ListingKind.market,
          account: AccountType.commercial,
          entitlements: freeComm,
        ),
        5000,
      );
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
    bool trial = false,
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
              trialActive: trial,
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
    testWidgets('free: başlık + kota (1 ürün / 0 kampanya)', (tester) async {
      await pumpCard(tester, BusinessPlan.free, products: 1);
      expect(find.byKey(const ValueKey('supplier_plan_card')), findsOneWidget);
      expect(find.text(AppStrings.supPlanFreeTitle), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget); // ürün
      expect(find.text('0 / 0'), findsOneWidget); // kampanya
    });

    testWidgets('pro: başlık + 5/3/20 kotaları', (tester) async {
      await pumpCard(tester, BusinessPlan.pro, products: 2, campaigns: 1);
      expect(find.text(AppStrings.supPlanProTitle), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('premium: sınırsız kotalar', (tester) async {
      await pumpCard(tester, BusinessPlan.premium);
      expect(find.text(AppStrings.supPlanPremiumTitle), findsOneWidget);
      expect(find.text(AppStrings.supQuotaUnlimited), findsWidgets);
    });

    testWidgets('trial: Pro-like deneme metni (Premium değil)', (tester) async {
      await pumpCard(tester, BusinessPlan.free, trial: true);
      expect(find.text(AppStrings.supPlanTrialTitle), findsOneWidget);
      // Trial'da tedarikçi limitleri Pro (5) — sınırsız DEĞİL.
      expect(find.text('0 / 5'), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      await pumpCard(
        tester,
        BusinessPlan.pro,
        products: 3,
        campaigns: 2,
        textScale: 1.3,
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PlansScreen — wholesaler tedarikçi paketleri', () {
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

    testWidgets('wholesaler tedarikçi özelliklerini gösterir', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(find.text(AppStrings.supPlanFreeFeatures), findsOneWidget);
      expect(find.text(AppStrings.supPlanProFeatures), findsOneWidget);
      expect(find.text(AppStrings.supPlanPremiumFeatures), findsOneWidget);
    });

    testWidgets('commercial metinleri bozulmaz + "1 bayi" yok', (tester) async {
      await pumpPlans(tester, AccountType.commercial);
      expect(find.text(AppStrings.planProFeatures), findsOneWidget);
      expect(AppStrings.planProFeatures.contains('1 bayi'), isFalse);
      expect(AppStrings.planProFeatures.contains('sınırsız bayi'), isTrue);
    });
  });
}
