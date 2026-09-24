import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../data/fake_payment_service.dart';
import '../data/payment_service.dart';
import '../data/revenuecat_payment_service.dart';

/// Payment service. With RevenueCat public SDK keys configured, this exposes the
/// real store implementation; otherwise UI shows "preparing" and fake purchases
/// are never allowed. The provider intentionally does not depend on auth user so
/// the same RevenueCat SDK instance receives login/logout transitions.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  if (AppConfig.storePaymentsEnabled) {
    return RevenueCatPaymentService(sb.Supabase.instance.client);
  }
  return FakePaymentService();
});
