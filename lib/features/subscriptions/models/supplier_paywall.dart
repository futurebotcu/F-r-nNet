import 'business_entitlements.dart';
import 'business_plan.dart';
import 'feature_lock.dart';

/// Tedarikçi/toptancı satış aksiyonları için paywall kararları (UX aynası).
///
/// Asıl kısıt server-side (b2b_products/campaigns/quote_replies insert
/// policy'leri + can_add_*/can_reply helper'ları). Bu yalnız UI kilidi;
/// ürün/kampanya için canlı liste sayısı, teklif cevabı için server-hesaplı
/// bool kullanılır.
class SupplierPaywall {
  const SupplierPaywall._();

  /// Ürün ekleme kilidi (mevcut ürün sayısıyla). null → ekleme açık.
  static FeatureLock? productLock(BusinessEntitlements e, int currentCount) {
    if (e.supplierProductsUnlimited || currentCount < e.supplierProductLimit) {
      return null;
    }
    return e.supplierEffectivePlan == BusinessPlan.pro
        ? FeatureLock.supplierProductPro
        : FeatureLock.supplierProductFree;
  }

  /// Kampanya ekleme kilidi (aktif kampanya sayısıyla). Free (limit 0) daima
  /// kilitli. null → açık.
  static FeatureLock? campaignLock(BusinessEntitlements e, int activeCount) {
    if (e.supplierCampaignsUnlimited) return null;
    if (e.supplierCampaignLimit == 0) return FeatureLock.supplierCampaignFree;
    if (activeCount < e.supplierCampaignLimit) return null;
    return FeatureLock.supplierCampaignPro;
  }

  /// Teklif cevabı kilidi (server-hesaplı aylık kota). null → açık.
  static FeatureLock? replyLock(BusinessEntitlements e) {
    if (e.supplierCanReplyQuote) return null;
    return e.supplierEffectivePlan == BusinessPlan.pro
        ? FeatureLock.supplierReplyPro
        : FeatureLock.supplierReplyFree;
  }
}
