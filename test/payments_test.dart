import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/payments/data/fake_payment_service.dart';
import 'package:firin_defter/features/payments/data/payment_service.dart';
import 'package:firin_defter/features/payments/models/store_product_config.dart';
import 'package:firin_defter/features/payments/providers/payment_providers.dart';
import 'package:firin_defter/features/payments/widgets/listing_payment_button.dart';
import 'package:firin_defter/features/payments/widgets/plan_purchase_actions.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/models/pricing_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType? account) {
    state = account == null
        ? null
        : BakeryProfile(
            displayName: 'T',
            accountType: account,
            city: 'Istanbul',
            roleBadge: 'X',
            email: 't@t.com',
          );
  }
}

void main() {
  group('StoreProductConfig', () {
    test('new premium ids plus legacy ids are present', () {
      expect(StoreProductConfig.premiumMonthly, 'firinnet_premium_monthly');
      expect(StoreProductConfig.premiumYearly, 'firinnet_premium_yearly');
      expect(StoreProductConfig.bakeryPro, 'firinnet_bakery_pro_monthly');
      expect(StoreProductConfig.supplierPro, 'firinnet_supplier_pro_monthly');
      expect(StoreProductConfig.listingFee, 'firinnet_listing_fee_50');
      expect(StoreProductConfig.allProductIds.length, 7);
    });

    test('business accounts buy only monthly/yearly Premium', () {
      for (final account in [AccountType.commercial, AccountType.wholesaler]) {
        expect(
          StoreProductConfig.subscriptionsFor(account).map((p) => p.productId),
          [StoreProductConfig.premiumMonthly, StoreProductConfig.premiumYearly],
        );
        expect(
          StoreProductConfig.productIdFor(account, BusinessPlan.premium),
          StoreProductConfig.premiumMonthly,
        );
        expect(
          StoreProductConfig.productIdFor(account, BusinessPlan.pro),
          isNull,
        );
      }
      expect(
        StoreProductConfig.subscriptionsFor(AccountType.individual),
        isEmpty,
      );
    });

    test('fallback price labels match launch Premium model', () {
      final byId = {
        for (final p in StoreProductConfig.subscriptions) p.productId: p,
      };
      expect(
        byId[StoreProductConfig.premiumMonthly]!.priceLabel,
        PricingConfig.premiumMonthlyLabel,
      );
      expect(
        byId[StoreProductConfig.premiumYearly]!.priceLabel,
        PricingConfig.premiumYearlyLabel,
      );
      expect(PricingConfig.premiumYearlySavings, 998);
    });

    test(
      'legacy Pro products are treated as Premium for restore/webhook parity',
      () {
        final byId = {
          for (final p in StoreProductConfig.subscriptions) p.productId: p,
        };
        expect(byId[StoreProductConfig.bakeryPro]!.legacy, isTrue);
        expect(byId[StoreProductConfig.bakeryPro]!.plan, BusinessPlan.premium);
        expect(byId[StoreProductConfig.supplierPro]!.legacy, isTrue);
        expect(
          byId[StoreProductConfig.supplierPro]!.plan,
          BusinessPlan.premium,
        );
      },
    );
  });

  group('FakePaymentService', () {
    test('purchaseProduct records product id', () async {
      final s = FakePaymentService(available: true);
      expect(
        await s.purchaseProduct(productId: StoreProductConfig.premiumMonthly),
        PaymentResult.success,
      );
      expect(s.purchaseCalls, 1);
      expect(s.lastPurchasedProductId, StoreProductConfig.premiumMonthly);
    });

    test('unavailable purchase/restore/listing fail closed', () async {
      final s = FakePaymentService(available: false);
      expect(
        await s.purchaseProduct(productId: StoreProductConfig.premiumMonthly),
        PaymentResult.unavailable,
      );
      expect(await s.restorePurchases(), PaymentResult.unavailable);
      expect(
        await s.purchaseListingFee(listingKind: 'market', listingId: 'x'),
        PaymentResult.unavailable,
      );
    });
  });

  Future<void> pumpActions(
    WidgetTester tester,
    AccountType? account, {
    required bool available,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(
            (ref) => _FixedProfile(ref, account),
          ),
          paymentServiceProvider.overrideWithValue(
            FakePaymentService(available: available),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: PlanPurchaseActions(account: account)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PlanPurchaseActions', () {
    testWidgets('payments disabled shows preparing only', (tester) async {
      await pumpActions(tester, AccountType.commercial, available: false);
      expect(
        find.byKey(const ValueKey('store_payment_preparing')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('buy_premium_monthly')), findsNothing);
    });

    testWidgets('payments enabled shows monthly/yearly + restore', (
      tester,
    ) async {
      await pumpActions(tester, AccountType.commercial, available: true);
      expect(find.byKey(const ValueKey('buy_premium_monthly')), findsOneWidget);
      expect(find.byKey(const ValueKey('buy_premium_yearly')), findsOneWidget);
      expect(find.byKey(const ValueKey('restore_purchases')), findsOneWidget);
      expect(
        find.textContaining(PricingConfig.premiumMonthlyLabel),
        findsOneWidget,
      );
      expect(
        find.textContaining(AppStrings.storePurchaseYearlySavings),
        findsOneWidget,
      );
    });

    testWidgets('individual account has no purchase actions', (tester) async {
      await pumpActions(tester, AccountType.individual, available: true);
      expect(find.byKey(const ValueKey('buy_premium_monthly')), findsNothing);
    });
  });

  group('ListingPaymentButton', () {
    testWidgets('unavailable listing payment does not call store purchase', (
      tester,
    ) async {
      final fake = FakePaymentService(available: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWithValue(
              const AuthUser(id: 'u1', email: 'u@test.local'),
            ),
            paymentServiceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ListingPaymentButton(
                listingKind: 'market',
                listingId: 'lid',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('listing_pay_button')));
      await tester.pump();
      expect(fake.listingFeeCalls, 0);
      expect(find.text(AppStrings.storePaymentPreparing), findsOneWidget);
    });
  });
}
