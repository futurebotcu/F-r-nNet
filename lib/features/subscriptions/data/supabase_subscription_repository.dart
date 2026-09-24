import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/business_entitlements.dart';
import 'subscription_repository.dart';

/// Supabase ücretlendirme reposu — `ensure_my_entitlement` + `my_entitlement`
/// RPC'lerini çağırır. Plan YAZMA yok (server-side/backoffice).
class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<void> ensureMyEntitlement() async {
    await _client.rpc('ensure_my_entitlement');
  }

  @override
  Future<BusinessEntitlements> myEntitlement() async {
    final rows = await _client.rpc('my_entitlement');
    if (rows is! List || rows.isEmpty) return BusinessEntitlements.free;
    return BusinessEntitlements.fromRow(
      (rows.first as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<BusinessEntitlements> activateLaunchPremiumPromo() async {
    await _client.rpc('activate_launch_premium_promo');
    final rows = await _client.rpc('my_entitlement');
    if (rows is! List || rows.isEmpty) return BusinessEntitlements.free;
    return BusinessEntitlements.fromRow(
      (rows.first as Map).cast<String, dynamic>(),
    );
  }
}
