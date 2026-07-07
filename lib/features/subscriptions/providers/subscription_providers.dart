import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/local_subscription_repository.dart';
import '../data/subscription_repository.dart';
import '../data/supabase_subscription_repository.dart';
import '../models/business_entitlements.dart';

/// Ücretlendirme reposu — Supabase açıksa gerçek, değilse local (test/offline).
/// P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  if (AppConfig.supabaseEnabled && userId != null) {
    return SupabaseSubscriptionRepository(sb.Supabase.instance.client);
  }
  return LocalSubscriptionRepository();
});

/// Çağıranın etkin entitlement'ı. İlk okumada `ensure_my_entitlement` çağrılır
/// (ticari kullanıcıya trial satırı garanti edilir), ardından güvenli alanlar
/// okunur. Hata/kapalı Supabase → free (fail-closed UX).
final myEntitlementProvider = FutureProvider.autoDispose<BusinessEntitlements>((
  ref,
) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  try {
    await repo.ensureMyEntitlement();
    return await repo.myEntitlement();
  } catch (_) {
    return BusinessEntitlements.free;
  }
});
