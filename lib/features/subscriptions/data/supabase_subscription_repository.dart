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
  static const String _commercialLaunchCampaignKey = 'commercial_launch_v1';

  Future<bool> _hasSeenNotice(String campaignKey, String noticeKey) async {
    final rows = await _client
        .from('user_campaign_notices')
        .select('notice_key')
        .eq('campaign_key', campaignKey)
        .eq('notice_key', noticeKey)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> _markNoticeSeen(String campaignKey, String noticeKey) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    // ON CONFLICT DO NOTHING — tekrar açılış/cihaz değişimi idempotenttir.
    await _client.from('user_campaign_notices').upsert(
      {
        'user_id': userId,
        'campaign_key': campaignKey,
        'notice_key': noticeKey,
      },
      onConflict: 'user_id,campaign_key,notice_key',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<bool> hasSeenSupplierLaunchNotice() =>
      _hasSeenNotice(_supplierLaunchCampaignKey, _supplierLaunchPopupNoticeKey);

  @override
  Future<void> markSupplierLaunchNoticeSeen() => _markNoticeSeen(
        _supplierLaunchCampaignKey,
        _supplierLaunchPopupNoticeKey,
      );

  @override
  Future<bool> hasSeenCommercialLaunchNotice(String noticeKey) =>
      _hasSeenNotice(_commercialLaunchCampaignKey, noticeKey);

  @override
  Future<void> markCommercialLaunchNoticeSeen(String noticeKey) =>
      _markNoticeSeen(_commercialLaunchCampaignKey, noticeKey);
}
