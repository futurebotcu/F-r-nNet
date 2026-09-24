import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';
import '../models/store_product_config.dart';
import 'payment_service.dart';

/// RevenueCat tabanli store odeme servisi (App Store IAP + Play Billing).
///
/// Entitlement client'ta uygulanmaz. Satin alma/restore sonrasi backend Edge
/// Function RevenueCat REST ile dogrular ve user_entitlements kaynagini gunceller.
class RevenueCatPaymentService implements PaymentService {
  RevenueCatPaymentService(this._db);

  final sb.SupabaseClient _db;
  bool _configured = false;

  String get _platformKey => Platform.isIOS
      ? AppConfig.revenueCatIosApiKey
      : AppConfig.revenueCatAndroidApiKey;

  @override
  bool get isAvailable => _platformKey.isNotEmpty;

  @override
  Future<void> initialize({required String? userId}) async {
    if (!isAvailable) return;
    if (_configured) {
      await setUser(userId);
      return;
    }
    final config = rc.PurchasesConfiguration(_platformKey)..appUserID = userId;
    await rc.Purchases.configure(config);
    _configured = true;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('RevenueCat requires an authenticated user');
    }
    await initialize(userId: userId);
  }

  @override
  Future<void> setUser(String? userId) async {
    if (!isAvailable || !_configured) return;
    if (userId == null) {
      await rc.Purchases.logOut();
    } else {
      await rc.Purchases.logIn(userId);
    }
  }

  @override
  Future<List<BusinessPlan>> availablePlans(AccountType? account) async {
    return StoreProductConfig.subscriptionsFor(
      account,
    ).map((p) => p.plan!).toSet().toList(growable: false);
  }

  @override
  Future<PaymentResult> purchasePlan({
    required AccountType account,
    required BusinessPlan plan,
  }) async {
    if (!isAvailable) return PaymentResult.unavailable;
    final productId = StoreProductConfig.productIdFor(account, plan);
    if (productId == null) return PaymentResult.error;
    return purchaseProduct(productId: productId);
  }

  @override
  Future<PaymentResult> purchaseProduct({required String productId}) async {
    if (!isAvailable) return PaymentResult.unavailable;
    final result = await _purchaseProductId(productId);
    if (result == PaymentResult.success) {
      try {
        await syncEntitlements();
      } catch (_) {
        return PaymentResult.pending;
      }
    }
    return result;
  }

  @override
  Future<PaymentResult> restorePurchases() async {
    if (!isAvailable) return PaymentResult.unavailable;
    try {
      await _ensureConfigured();
      await rc.Purchases.restorePurchases();
      await syncEntitlements();
      return PaymentResult.success;
    } catch (_) {
      return PaymentResult.error;
    }
  }

  @override
  Future<void> syncEntitlements() async {
    final res = await _db.functions.invoke('revenuecat-sync-my-entitlements');
    final data = res.data;
    if (data is Map && data['ok'] == false) {
      throw StateError('entitlement sync failed');
    }
  }

  @override
  Future<PaymentResult> purchaseListingFee({
    required String listingKind,
    required String listingId,
  }) async {
    if (!isAvailable) return PaymentResult.unavailable;
    final intentRows = await _db.rpc(
      'create_listing_payment_intent',
      params: {'p_listing_kind': listingKind, 'p_listing_id': listingId},
    );
    final intent = (intentRows is List && intentRows.isNotEmpty)
        ? (intentRows.first as Map).cast<String, dynamic>()
        : null;
    if (intent == null) return PaymentResult.error;
    final intentId = intent['intent_id'] as String?;
    if (intentId == null) return PaymentResult.error;

    // Network failure sonrasi tekrar butona basilirse once mevcut purchase'i
    // confirm etmeyi deneriz; basarisizsa yeni store purchase baslar.
    final recovery = await _confirmListingPayment(intentId);
    if (recovery == PaymentResult.success) return PaymentResult.success;

    final result = await _purchaseProductId(StoreProductConfig.listingFee);
    if (result != PaymentResult.success) return result;
    return _confirmListingPayment(intentId);
  }

  Future<PaymentResult> _purchaseProductId(String productId) async {
    try {
      await _ensureConfigured();
      final products = await rc.Purchases.getProducts([productId]);
      if (products.isEmpty) return PaymentResult.error;
      await rc.Purchases.purchase(
        rc.PurchaseParams.storeProduct(products.first),
      );
      return PaymentResult.success;
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        return PaymentResult.cancelled;
      }
      return PaymentResult.error;
    } catch (_) {
      return PaymentResult.error;
    }
  }

  Future<PaymentResult> _confirmListingPayment(String intentId) async {
    try {
      final res = await _db.functions.invoke(
        'revenuecat-confirm-listing-payment',
        body: {'intent_id': intentId},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) return PaymentResult.success;
      return PaymentResult.pending;
    } catch (_) {
      return PaymentResult.pending;
    }
  }

  @override
  Future<Map<String, StorePrice>> fetchStorePrices(
    List<String> productIds,
  ) async {
    if (!isAvailable || productIds.isEmpty) return const <String, StorePrice>{};
    await _ensureConfigured();
    final products = await rc.Purchases.getProducts(productIds);
    return <String, StorePrice>{
      for (final p in products)
        p.identifier: StorePrice(
          productId: p.identifier,
          priceLabel: p.priceString,
        ),
    };
  }
}
