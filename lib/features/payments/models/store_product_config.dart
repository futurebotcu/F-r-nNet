import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';
import '../../subscriptions/models/pricing_config.dart';

/// Store subscription/consumable ürün tanımları — TEK KAYNAK (server
/// store_product_mapping ile birebir). Ödeme UI'ı bu config'ten okur.
class StoreProduct {
  const StoreProduct({
    required this.productId,
    required this.accountType,
    required this.plan,
    this.billingPeriod = StoreBillingPeriod.monthly,
    this.legacy = false,
  });

  final String productId;

  /// Bu ürünün hedef hesabı (subscription için). Listing fee'de null.
  final AccountType? accountType;

  /// Subscription planı. Listing fee'de null.
  final BusinessPlan? plan;
  final StoreBillingPeriod billingPeriod;
  final bool legacy;

  /// Görüntü fiyatı (PricingConfig'ten — dağınık hard-code yok).
  String get priceLabel {
    if (plan == BusinessPlan.premium) {
      return PricingConfig.premiumLabel(
        yearly: billingPeriod == StoreBillingPeriod.yearly,
      );
    }
    if (accountType == AccountType.wholesaler) {
      return PricingConfig.monthlyLabel(PricingAudience.supplier, plan!);
    }
    if (accountType == AccountType.commercial) {
      return PricingConfig.monthlyLabel(PricingAudience.bakery, plan!);
    }
    return PricingConfig.paidListingLabel;
  }
}

enum StoreBillingPeriod { monthly, yearly }

class StoreProductConfig {
  const StoreProductConfig._();

  static const String premiumMonthly = 'firinnet_premium_monthly';
  static const String premiumYearly = 'firinnet_premium_yearly';
  static const String bakeryPro = 'firinnet_bakery_pro_monthly';
  static const String bakeryPremium = 'firinnet_bakery_premium_monthly';
  static const String supplierPro = 'firinnet_supplier_pro_monthly';
  static const String supplierPremium = 'firinnet_supplier_premium_monthly';
  static const String listingFee = 'firinnet_listing_fee_50';

  static const List<StoreProduct> subscriptions = <StoreProduct>[
    StoreProduct(
      productId: premiumMonthly,
      accountType: null,
      plan: BusinessPlan.premium,
    ),
    StoreProduct(
      productId: premiumYearly,
      accountType: null,
      plan: BusinessPlan.premium,
      billingPeriod: StoreBillingPeriod.yearly,
    ),
    StoreProduct(
      productId: bakeryPro,
      accountType: AccountType.commercial,
      plan: BusinessPlan.premium,
      legacy: true,
    ),
    StoreProduct(
      productId: bakeryPremium,
      accountType: AccountType.commercial,
      plan: BusinessPlan.premium,
      legacy: true,
    ),
    StoreProduct(
      productId: supplierPro,
      accountType: AccountType.wholesaler,
      plan: BusinessPlan.premium,
      legacy: true,
    ),
    StoreProduct(
      productId: supplierPremium,
      accountType: AccountType.wholesaler,
      plan: BusinessPlan.premium,
      legacy: true,
    ),
  ];

  static const List<String> allProductIds = <String>[
    premiumMonthly,
    premiumYearly,
    bakeryPro,
    bakeryPremium,
    supplierPro,
    supplierPremium,
    listingFee,
  ];

  /// [account] için satın alınabilir subscription ürünleri. Ticari→bakery,
  /// toptancı→supplier, bireysel→boş (subscription satışı yok).
  static List<StoreProduct> subscriptionsFor(AccountType? account) {
    if (account == AccountType.commercial ||
        account == AccountType.wholesaler) {
      return subscriptions
          .where((p) => !p.legacy && p.plan == BusinessPlan.premium)
          .toList(growable: false);
    }
    return const <StoreProduct>[];
  }

  /// [account] + [plan] için ürün id (satın alma tetikleyicisi).
  static String? productIdFor(AccountType? account, BusinessPlan plan) {
    for (final p in subscriptionsFor(account)) {
      if (p.plan == plan) return p.productId;
    }
    return null;
  }

  static List<String> premiumProductIdsFor(AccountType? account) =>
      subscriptionsFor(account).map((p) => p.productId).toList(growable: false);
}
