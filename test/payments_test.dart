import 'package:firin_defter/core/constants/app_strings.dart';
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

/// RevenueCat Store Payments Foundation V1 — config + service + UI testleri.
/// Asıl ödeme/entitlement server-side (RLS smoke A-D PASS); bu client UX.
class _FixedProfile extends ProfileController {
  _FixedProfile(super.ref, AccountType? account) {
    state = account == null
        ? null
        : BakeryProfile(
            displayName: 'T',
            accountType: account,
            city: 'İstanbul',
            roleBadge: 'X',
            email: 't@t.com',
          );
  }
}

void main() {
  group('StoreProductConfig', () {
    test('product id sabitleri', () {
      expect(StoreProductConfig.bakeryPro, 'firinnet_bakery_pro_monthly');
      expect(
        StoreProductConfig.bakeryPremium,
        'firinnet_bakery_premium_monthly',
      );
      expect(StoreProductConfig.supplierPro, 'firinnet_supplier_pro_monthly');
      expect(
        StoreProductConfig.supplierPremium,
        'firinnet_supplier_premium_monthly',
      );
      expect(StoreProductConfig.listingFee, 'firinnet_listing_fee_50');
      expect(StoreProductConfig.allProductIds.length, 5);
    });

    test('commercial yalnız bakery, wholesaler yalnız supplier', () {
      final comm = StoreProductConfig.subscriptionsFor(AccountType.commercial);
      expect(
        comm.every((p) => p.accountType == AccountType.commercial),
        isTrue,
      );
      expect(comm.length, 2);
      final whole = StoreProductConfig.subscriptionsFor(AccountType.wholesaler);
      expect(
        whole.every((p) => p.accountType == AccountType.wholesaler),
        isTrue,
      );
      // Bireysel → subscription satışı yok.
      expect(
        StoreProductConfig.subscriptionsFor(AccountType.individual),
        isEmpty,
      );
    });

    test('productIdFor doğru eşleme', () {
      expect(
        StoreProductConfig.productIdFor(
          AccountType.commercial,
          BusinessPlan.pro,
        ),
        'firinnet_bakery_pro_monthly',
      );
      expect(
        StoreProductConfig.productIdFor(
          AccountType.wholesaler,
          BusinessPlan.premium,
        ),
        'firinnet_supplier_premium_monthly',
      );
      expect(
        StoreProductConfig.productIdFor(
          AccountType.individual,
          BusinessPlan.pro,
        ),
        isNull,
      );
    });

    test('priceLabel PricingConfig ile uyumlu (299/799/999/2.999/50)', () {
      final byId = {
        for (final p in StoreProductConfig.subscriptions) p.productId: p,
      };
      expect(
        byId['firinnet_bakery_pro_monthly']!.priceLabel,
        PricingConfig.bakeryProLabel,
      );
      expect(
        byId['firinnet_bakery_premium_monthly']!.priceLabel,
        PricingConfig.bakeryPremiumLabel,
      );
      expect(
        byId['firinnet_supplier_pro_monthly']!.priceLabel,
        PricingConfig.supplierProLabel,
      );
      expect(
        byId['firinnet_supplier_premium_monthly']!.priceLabel,
        PricingConfig.supplierPremiumLabel,
      );
      const listing = StoreProduct(
        productId: 'firinnet_listing_fee_50',
        accountType: null,
        plan: null,
      );
      expect(listing.priceLabel, PricingConfig.paidListingLabel);
      expect(PricingConfig.paidListingLabel, '50 TL');
    });
  });

  group('FakePaymentService', () {
    test(
      'unavailable → purchase/restore/listing unavailable, sync sayaç',
      () async {
        final s = FakePaymentService(available: false);
        expect(s.isAvailable, isFalse);
        expect(
          await s.purchasePlan(
            account: AccountType.commercial,
            plan: BusinessPlan.pro,
          ),
          PaymentResult.unavailable,
        );
        expect(await s.restorePurchases(), PaymentResult.unavailable);
        expect(
          await s.purchaseListingFee(listingKind: 'market', listingId: 'x'),
          PaymentResult.unavailable,
        );
        await s.syncEntitlements();
        expect(s.syncCalls, 1);
      },
    );

    test('available → success + sayaçlar', () async {
      final s = FakePaymentService(available: true);
      expect(
        await s.purchasePlan(
          account: AccountType.wholesaler,
          plan: BusinessPlan.premium,
        ),
        PaymentResult.success,
      );
      expect(s.purchaseCalls, 1);
      expect(s.lastPurchasedPlan, BusinessPlan.premium);
    });
  });

  Future<void> pumpActions(
    WidgetTester tester,
    AccountType? account, {
    required bool available,
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
    testWidgets('ödeme yoksa "hazırlanıyor" gösterir', (tester) async {
      await pumpActions(tester, AccountType.commercial, available: false);
      expect(
        find.byKey(const ValueKey('store_payment_preparing')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('buy_pro')), findsNothing);
    });

    testWidgets('ödeme varsa satın al + restore butonları', (tester) async {
      await pumpActions(tester, AccountType.commercial, available: true);
      expect(find.byKey(const ValueKey('buy_pro')), findsOneWidget);
      expect(find.byKey(const ValueKey('buy_premium')), findsOneWidget);
      expect(find.byKey(const ValueKey('restore_purchases')), findsOneWidget);
    });

    testWidgets('bireysel hesap → hiçbir ödeme aksiyonu yok', (tester) async {
      await pumpActions(tester, AccountType.individual, available: true);
      expect(find.byKey(const ValueKey('buy_pro')), findsNothing);
      expect(
        find.byKey(const ValueKey('store_payment_preparing')),
        findsNothing,
      );
    });

    testWidgets('satın al → success snackbar + purchase çağrısı', (
      tester,
    ) async {
      final fake = FakePaymentService(available: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, AccountType.commercial),
            ),
            paymentServiceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlanPurchaseActions(account: AccountType.commercial),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('buy_pro')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fake.purchaseCalls, 1);
      expect(fake.lastPurchasedPlan, BusinessPlan.pro);
      expect(find.text(AppStrings.storePaymentSuccess), findsOneWidget);
    });

    testWidgets('320dp + 1.3x taşma yok', (tester) async {
      await pumpActions(
        tester,
        AccountType.wholesaler,
        available: true,
        textScale: 1.3,
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ListingPaymentButton', () {
    testWidgets('ödeme yoksa tap → "hazırlanıyor", purchase çağrılmaz', (
      tester,
    ) async {
      final fake = FakePaymentService(available: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentServiceProvider.overrideWithValue(fake)],
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

    testWidgets('ödeme varsa tap → purchaseListingFee çağrılır', (
      tester,
    ) async {
      final fake = FakePaymentService(available: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentServiceProvider.overrideWithValue(fake)],
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
      await tester.pump(const Duration(milliseconds: 50));
      expect(fake.listingFeeCalls, 1);
    });
  });
}
