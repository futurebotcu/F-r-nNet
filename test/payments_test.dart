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

/// Store'un Google formatında ('id:basePlan') identifier döndürdüğü durumu
/// taklit eder; gerçek servis gibi mapStorePrices ile eşler.
class _SuffixedPricesPaymentService extends FakePaymentService {
  _SuffixedPricesPaymentService() : super(available: true);

  @override
  Future<Map<String, StorePrice>> fetchStorePrices(
    List<String> productIds,
  ) async {
    return mapStorePrices(
      productIds,
      const [
        StorePrice(
          productId: 'firinnet_premium_monthly:monthly',
          priceLabel: '₺123,45',
        ),
        StorePrice(
          productId: 'firinnet_premium_yearly:annual',
          priceLabel: '₺1.234,56',
        ),
      ],
      preferred: StoreProductConfig.selectStoreIdentifier,
    );
  }
}

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
      expect(PricingConfig.premiumYearlySavingsCents, 99998);
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

  group('Google Play product id formatı (id:basePlan)', () {
    test('normalizeProductId suffix atar, plain/legacy dokunmaz', () {
      expect(
        StoreProductConfig.normalizeProductId('firinnet_premium_monthly:monthly'),
        StoreProductConfig.premiumMonthly,
      );
      expect(
        StoreProductConfig.normalizeProductId(StoreProductConfig.premiumYearly),
        StoreProductConfig.premiumYearly,
      );
      expect(
        StoreProductConfig.normalizeProductId(StoreProductConfig.listingFee),
        StoreProductConfig.listingFee,
      );
    });

    test('selectStoreIdentifier: birebir > beklenen base plan > herhangi', () {
      // iOS/legacy: birebir eşleşme öncelikli.
      expect(
        StoreProductConfig.selectStoreIdentifier(
          ['firinnet_premium_monthly'],
          StoreProductConfig.premiumMonthly,
        ),
        'firinnet_premium_monthly',
      );
      // Google: beklenen base plan seçilir (başka base plan varsa bile).
      expect(
        StoreProductConfig.selectStoreIdentifier(
          [
            'firinnet_premium_monthly:offer_x',
            'firinnet_premium_monthly:monthly',
          ],
          StoreProductConfig.premiumMonthly,
        ),
        'firinnet_premium_monthly:monthly',
      );
      // Beklenen base plan yoksa ürünün mevcut base planı.
      expect(
        StoreProductConfig.selectStoreIdentifier(
          ['firinnet_premium_yearly:promo'],
          StoreProductConfig.premiumYearly,
        ),
        'firinnet_premium_yearly:promo',
      );
      // Yanlış ürün asla seçilmez.
      expect(
        StoreProductConfig.selectStoreIdentifier(
          ['firinnet_premium_yearly:annual'],
          StoreProductConfig.premiumMonthly,
        ),
        isNull,
      );
    });

    test('mapStorePrices: fiyat hem id hem id:basePlan anahtarıyla bulunur',
        () {
      final prices = mapStorePrices(
        [StoreProductConfig.premiumMonthly, StoreProductConfig.premiumYearly],
        const [
          StorePrice(
            productId: 'firinnet_premium_monthly:monthly',
            priceLabel: '₺499,99',
          ),
          StorePrice(
            productId: 'firinnet_premium_yearly:annual',
            priceLabel: '₺4.999,99',
          ),
        ],
        preferred: StoreProductConfig.selectStoreIdentifier,
      );
      expect(prices[StoreProductConfig.premiumMonthly]?.priceLabel, '₺499,99');
      expect(
        prices['firinnet_premium_monthly:monthly']?.priceLabel,
        '₺499,99',
      );
      expect(
        prices[StoreProductConfig.premiumYearly]?.priceLabel,
        '₺4.999,99',
      );
      // Plain identifier dönerse (iOS/legacy) aynen çalışır.
      final plain = mapStorePrices(
        [StoreProductConfig.premiumMonthly],
        const [
          StorePrice(
            productId: 'firinnet_premium_monthly',
            priceLabel: r'$4.99',
          ),
        ],
        preferred: StoreProductConfig.selectStoreIdentifier,
      );
      expect(plain[StoreProductConfig.premiumMonthly]?.priceLabel, r'$4.99');
    });
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

    testWidgets('Play id:basePlan fiyatları butonlarda görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfile(ref, AccountType.commercial),
            ),
            currentAuthUserProvider.overrideWithValue(
              const AuthUser(id: 'u1', email: 'u@test.local'),
            ),
            paymentServiceProvider.overrideWithValue(
              _SuffixedPricesPaymentService(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlanPurchaseActions(account: AccountType.commercial),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Sentinel fiyatlar config fallback'lerinden farklı → butondaki değer
      // kesin olarak store'dan (id:basePlan eşlemesinden) gelmiştir.
      expect(find.textContaining('₺123,45'), findsOneWidget);
      expect(find.textContaining('₺1.234,56'), findsOneWidget);
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
