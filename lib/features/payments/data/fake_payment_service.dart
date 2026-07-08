import '../../profile/models/bakery_profile.dart';
import '../../subscriptions/models/business_plan.dart';
import '../models/store_product_config.dart';
import 'payment_service.dart';

/// Test/geliştirme ödeme servisi. GERÇEK ödeme YAPMAZ; entitlement
/// uygulamaz. [available] ile UI akışları test edilir.
class FakePaymentService implements PaymentService {
  FakePaymentService({
    this.available = false,
    this.result = PaymentResult.success,
  });

  bool available;
  PaymentResult result;

  int purchaseCalls = 0;
  int restoreCalls = 0;
  int syncCalls = 0;
  int listingFeeCalls = 0;
  BusinessPlan? lastPurchasedPlan;
  String? lastUserId;

  @override
  bool get isAvailable => available;

  @override
  Future<void> initialize({required String? userId}) async {
    lastUserId = userId;
  }

  @override
  Future<void> setUser(String? userId) async {
    lastUserId = userId;
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
    purchaseCalls++;
    lastPurchasedPlan = plan;
    if (!available) return PaymentResult.unavailable;
    return result;
  }

  @override
  Future<PaymentResult> restorePurchases() async {
    restoreCalls++;
    if (!available) return PaymentResult.unavailable;
    return result;
  }

  @override
  Future<void> syncEntitlements() async {
    syncCalls++;
  }

  @override
  Future<PaymentResult> purchaseListingFee({
    required String listingKind,
    required String listingId,
  }) async {
    listingFeeCalls++;
    if (!available) return PaymentResult.unavailable;
    return result;
  }
}
