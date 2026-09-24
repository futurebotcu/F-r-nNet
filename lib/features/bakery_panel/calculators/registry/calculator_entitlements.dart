import '../../../subscriptions/models/business_entitlements.dart';
import '../../../subscriptions/models/feature_lock.dart';
import '../models/calculator_min_plan.dart';

/// Hesaplama araçlarının ticari plan kilidi merkezi konfigürasyonu
/// (Paywall UI V1).
///
/// Ticari kullanıcıya görünen 26 araç için tier: Free 8 · Pro +11 (19) ·
/// Premium +7 (26). Burada listelenmeyen her araç Free kabul edilir. Formül/
/// servis/registry görünürlük kararlarına DOKUNMAZ — yalnız kilit metadatası.
///
/// GÜVENLİK: hesaplamalar stateless (veri yazmaz) → server-side gate yok;
/// bu kilit yalnız UX. Bireysel/toptancı kullanıcıya kilit UYGULANMAZ (çağıran
/// hesap türü ticari değilse [calculatorLockFor] daima null döner).
class CalculatorEntitlements {
  const CalculatorEntitlements._();

  static const Set<String> _proToolIds = <String>{
    'bakers_percent',
    'recipe_scale',
    'pack_convert',
    'oven_capacity',
    'cost_profit',
    'fixed_cost',
    'price_update',
    'evening_discount',
    'waste_loss',
    'flour_hike',
    'dealer_profit',
  };

  static const Set<String> _premiumToolIds = <String>{
    'recipe_cost_detail',
    'labor_index',
    'oven_energy',
    'free_goods',
    'flat_deal',
    'master_earnings',
    'tip_split',
  };

  static CalculatorMinPlan minPlanFor(String toolId) {
    if (_premiumToolIds.contains(toolId)) return CalculatorMinPlan.premium;
    if (_proToolIds.contains(toolId)) return CalculatorMinPlan.pro;
    return CalculatorMinPlan.free;
  }

  /// Ticari kullanıcı bu aracı açamıyorsa paywall içeriği; açıksa null.
  /// [isCommercial] false ise (bireysel/toptancı) daima null (kilit yok).
  static FeatureLock? lockFor({
    required String toolId,
    required BusinessEntitlements entitlements,
    required bool isCommercial,
  }) {
    if (!isCommercial) return null;
    switch (minPlanFor(toolId)) {
      case CalculatorMinPlan.free:
        return null;
      case CalculatorMinPlan.pro:
        // Pro veya Premium (trial→premium) açar.
        return entitlements.canUsePremiumFeature
            ? null
            : FeatureLock.calculatorPro;
      case CalculatorMinPlan.premium:
        return entitlements.canUsePremiumFeature
            ? null
            : FeatureLock.calculatorPremium;
    }
  }
}
