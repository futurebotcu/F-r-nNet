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

  static const String _supplierLaunchCampaignKey = 'supplier_launch_v1';
  static const String _supplierLaunchPopupNoticeKey = 'popup_ack';

  @override
  Future<bool> hasSeenSupplierLaunchNotice() async {
    final rows = await _client
        .from('user_campaign_notices')
        .select('notice_key')
        .eq('campaign_key', _supplierLaunchCampaignKey)
        .eq('notice_key', _supplierLaunchPopupNoticeKey)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> markSupplierLaunchNoticeSeen() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    // ON CONFLICT DO NOTHING — tekrar açılış/cihaz değişimi idempotenttir.
    await _client.from('user_campaign_notices').upsert(
      {
        'user_id': userId,
        'campaign_key': _supplierLaunchCampaignKey,
        'notice_key': _supplierLaunchPopupNoticeKey,
      },
      onConflict: 'user_id,campaign_key,notice_key',
      ignoreDuplicates: true,
    );
  }
}
