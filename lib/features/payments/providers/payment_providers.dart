import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/fake_payment_service.dart';
import '../data/payment_service.dart';
import '../data/revenuecat_payment_service.dart';

/// Ödeme servisi — RevenueCat public key + Supabase oturumu varsa gerçek,
/// yoksa Fake (isAvailable=false → UI "hazırlanıyor" gösterir, sahte purchase
/// YAPILMAZ). Yalnız userId izlenir (token refresh servisi resetlemesin).
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  if (AppConfig.storePaymentsEnabled && userId != null) {
    return RevenueCatPaymentService(sb.Supabase.instance.client);
  }
  return FakePaymentService();
});
