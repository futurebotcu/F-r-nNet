import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';
import '../models/store_product_config.dart';
import 'payment_service.dart';

/// RevenueCat tabanlı store ödeme servisi (App Store IAP + Play Billing).
///
/// Yalnız RevenueCat public key mevcutsa etkin. Entitlement client'ta
/// UYGULANMAZ — purchase sonrası backend edge (revenuecat-sync-my-entitlements /
/// revenuecat-confirm-listing-payment) doğrular ve uygular. Client sadece
/// satın alma akışını tetikler + sync çağırır.
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
    final config = PurchasesConfiguration(_platformKey)..appUserID = userId;
    await Purchases.configure(config);
    _configured = true;
  }

  @override
  Future<void> setUser(String? userId) async {
    if (!isAvailable || !_configured) return;
    if (userId == null) {
      await Purchases.logOut();
    } else {
      await Purchases.logIn(userId);
    }
  }

  @override
  Future<List<BusinessPlan>> availablePlans(AccountType? account) async {
    return StoreProductConfig.subscriptionsFor(
      account,
    ).map((p) => p.plan!).toList(growable: false);
  }

  @override
  Future<PaymentResult> purchasePlan({
    required AccountType account,
    required BusinessPlan plan,
  }) async {
    if (!isAvailable) return PaymentResult.unavailable;
    final productId = StoreProductConfig.productIdFor(account, plan);
    if (productId == null) return PaymentResult.error;
    final result = await _purchaseProductId(productId);
    if (result == PaymentResult.success) {
      await syncEntitlements();
    }
    return result;
  }

  @override
  Future<PaymentResult> restorePurchases() async {
    if (!isAvailable) return PaymentResult.unavailable;
    try {
      await Purchases.restorePurchases();
      await syncEntitlements();
      return PaymentResult.success;
    } catch (_) {
      return PaymentResult.error;
    }
  }

  @override
  Future<void> syncEntitlements() async {
    try {
      await _db.functions.invoke('revenuecat-sync-my-entitlements');
    } catch (_) {
      // Sessiz — entitlement provider ayrıca yeniden okunur.
    }
  }

  @override
  Future<PaymentResult> purchaseListingFee({
    required String listingKind,
    required String listingId,
  }) async {
    if (!isAvailable) return PaymentResult.unavailable;
    // 1) Sunucuda ödeme niyeti (owner + pending doğrular).
    final intentRows = await _db.rpc(
      'create_listing_payment_intent',
      params: {'p_listing_kind': listingKind, 'p_listing_id': listingId},
    );
    final intent = (intentRows is List && intentRows.isNotEmpty)
        ? (intentRows.first as Map).cast<String, dynamic>()
        : null;
    if (intent == null) return PaymentResult.error;
    final intentId = intent['intent_id'] as String?;
    // 2) Consumable purchase.
    final result = await _purchaseProductId(StoreProductConfig.listingFee);
    if (result != PaymentResult.success || intentId == null) return result;
    // 3) Backend doğrulama + ilan public (edge, RevenueCat REST).
    try {
      await _db.functions.invoke(
        'revenuecat-confirm-listing-payment',
        body: {'intent_id': intentId},
      );
    } catch (_) {
      // Doğrulama beklemede — webhook idempotent geçebilir.
      return PaymentResult.pending;
    }
    return PaymentResult.success;
  }

  Future<PaymentResult> _purchaseProductId(String productId) async {
    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) return PaymentResult.error;
      await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      return PaymentResult.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PaymentResult.cancelled;
      }
      return PaymentResult.error;
    } catch (_) {
      return PaymentResult.error;
    }
  }
}
