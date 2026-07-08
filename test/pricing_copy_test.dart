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

/// Paket Fiyatları UI V1 — fiyat config + plan ekranı + paywall metinleri.
class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType account) {
    state = BakeryProfile(
      displayName: 'T',
      accountType: account,
      city: 'İstanbul',
      roleBadge: 'X',
      email: 't@t.com',
    );
  }
}

void main() {
  group('PricingConfig', () {
    test('sabit fiyatlar + etiketler', () {
      expect(PricingConfig.bakeryProMonthly, 299);
      expect(PricingConfig.bakeryPremiumMonthly, 799);
      expect(PricingConfig.supplierProMonthly, 999);
      expect(PricingConfig.supplierPremiumMonthly, 2999);
      expect(PricingConfig.paidListingFee, 50);
      expect(PricingConfig.bakeryProLabel, '299 TL / ay');
      expect(PricingConfig.bakeryPremiumLabel, '799 TL / ay');
      expect(PricingConfig.supplierProLabel, '999 TL / ay');
      expect(PricingConfig.supplierPremiumLabel, '2.999 TL / ay');
    });

    test('monthlyLabel audience+plan', () {
      expect(
        PricingConfig.monthlyLabel(PricingAudience.bakery, BusinessPlan.pro),
        '299 TL / ay',
      );
      expect(
        PricingConfig.monthlyLabel(
          PricingAudience.bakery,
          BusinessPlan.premium,
        ),
        '799 TL / ay',
      );
      expect(
        PricingConfig.monthlyLabel(PricingAudience.supplier, BusinessPlan.pro),
        '999 TL / ay',
      );
      expect(
        PricingConfig.monthlyLabel(
          PricingAudience.supplier,
          BusinessPlan.premium,
        ),
        '2.999 TL / ay',
      );
      expect(
        PricingConfig.monthlyLabel(PricingAudience.bakery, BusinessPlan.free),
        '0 TL',
      );
    });
  });

  group('FeatureLock priceHint', () {
    test('commercial lock\'lar bakery fiyatı taşır', () {
      expect(FeatureLock.branches.priceHint, PricingConfig.bakeryPremiumHint);
      expect(FeatureLock.dealerBook.priceHint, PricingConfig.bakeryProHint);
      expect(FeatureLock.recipePro.priceHint, PricingConfig.bakeryPremiumHint);
    });
    test('supplier lock\'lar supplier fiyatı taşır', () {
      expect(
        FeatureLock.supplierProductFree.priceHint,
        PricingConfig.supplierProHint,
      );
      expect(
        FeatureLock.supplierProductPro.priceHint,
        PricingConfig.supplierPremiumHint,
      );
      expect(
        FeatureLock.supplierReplyFree.priceHint,
        PricingConfig.supplierProHint,
      );
    });
    test('Pro bayi anlatımı korunur — "1 bayi" yok', () {
      final all = [
        FeatureLock.dealerBook,
        FeatureLock.dealerDriverOps,
        FeatureLock.branches,
      ];
      for (final l in all) {
        final t = '${l.title} ${l.body} ${l.priceHint}';
        expect(t.contains('1 bayi'), isFalse);
        expect(t.contains('tek bayi'), isFalse);
        expect(t.contains('1 aktif bayi'), isFalse);
      }
    });
  });

  Future<void> pumpSheet(WidgetTester tester, FeatureLock lock) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPaywallSheet(context, lock),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  group('Paywall sheet fiyatı', () {
    testWidgets('commercial Pro paywall 299 TL/ay', (tester) async {
      await pumpSheet(tester, FeatureLock.dealerBook);
      expect(find.text(PricingConfig.bakeryProHint), findsOneWidget);
      expect(find.text('Pro paket 299 TL/ay'), findsOneWidget);
    });
    testWidgets('commercial Premium paywall 799 TL/ay', (tester) async {
      await pumpSheet(tester, FeatureLock.branches);
      expect(find.text('Premium paket 799 TL/ay'), findsOneWidget);
    });
    testWidgets('supplier Pro paywall 999 TL/ay', (tester) async {
      await pumpSheet(tester, FeatureLock.supplierProductFree);
      expect(find.text('Pro paket 999 TL/ay'), findsOneWidget);
    });
    testWidgets('supplier Premium paywall 2.999 TL/ay', (tester) async {
      await pumpSheet(tester, FeatureLock.supplierProductPro);
      expect(find.text('Premium paket 2.999 TL/ay'), findsOneWidget);
    });
  });

  group('PlansScreen fiyatları', () {
    Future<void> pumpPlans(
      WidgetTester tester,
      AccountType account, {
      double textScale = 1.0,
      Size size = const Size(390, 3000),
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

    testWidgets('commercial: 299 + 799 + 0 TL', (tester) async {
      await pumpPlans(tester, AccountType.commercial);
      expect(find.text('299 TL / ay'), findsOneWidget);
      expect(find.text('799 TL / ay'), findsOneWidget);
      expect(find.text('0 TL'), findsOneWidget);
      expect(find.text(AppStrings.plansTrialCta), findsOneWidget);
    });

    testWidgets('supplier: 999 + 2.999 + 0 TL', (tester) async {
      await pumpPlans(tester, AccountType.wholesaler);
      expect(find.text('999 TL / ay'), findsOneWidget);
      expect(find.text('2.999 TL / ay'), findsOneWidget);
      expect(find.text('0 TL'), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      await pumpPlans(
        tester,
        AccountType.wholesaler,
        textScale: 1.3,
        size: const Size(320, 4000),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
