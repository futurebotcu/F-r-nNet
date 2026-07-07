import '../models/business_entitlements.dart';
import '../models/business_plan.dart';
import 'subscription_repository.dart';

/// In-memory ücretlendirme reposu — test ve Supabase kapalı geliştirme için.
///
/// Server `my_entitlement` türetiminin davranışsal aynası: verilen [plan] ve
/// [trialActive] durumundan effective plan + limit/feature alanlarını üretir.
class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository({
    this.plan = BusinessPlan.free,
    this.trialActive = false,
    this.trialDaysLeft = 0,
  });

  BusinessPlan plan;
  bool trialActive;
  int trialDaysLeft;
  int ensureCalls = 0;

  BusinessPlan get _effective => trialActive ? BusinessPlan.premium : plan;

  @override
  Future<void> ensureMyEntitlement() async {
    ensureCalls++;
  }

  @override
  Future<BusinessEntitlements> myEntitlement() async {
    final eff = _effective;
    return BusinessEntitlements(
      plan: plan,
      effectivePlan: eff,
      isTrialActive: trialActive,
      daysLeft: trialActive ? trialDaysLeft : 0,
      recipeLimit: switch (eff) {
        BusinessPlan.premium => -1,
        BusinessPlan.pro => 50,
        BusinessPlan.free => 5,
      },
      // Bayi sayı limiti: Free 0 (kapalı) · Pro/Premium -1 (sınırsız).
      // Pro↔Premium ayrımı şoförlü operasyonda (dealer_driver_ops), sayıda
      // DEĞİL.
      dealerLimit: switch (eff) {
        BusinessPlan.premium => -1,
        BusinessPlan.pro => -1,
        BusinessPlan.free => 0,
      },
      canUseBranches: eff == BusinessPlan.premium,
      canUseDebtExpense: eff == BusinessPlan.pro || eff == BusinessPlan.premium,
      canUseDealerDriverOps: eff == BusinessPlan.premium,
    );
  }
}
