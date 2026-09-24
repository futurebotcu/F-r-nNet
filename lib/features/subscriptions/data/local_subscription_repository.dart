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
    this.canStartPromo = true,
    this.supplierLaunchFreeUntil,
  });

  BusinessPlan plan;
  bool trialActive;
  int trialDaysLeft;
  bool canStartPromo;

  /// Tedarikçi Lansman Kampanyası aynası: dolu + gelecekte ise kampanya
  /// aktif sayılır (server ortak penceresinin local karşılığı).
  DateTime? supplierLaunchFreeUntil;
  int ensureCalls = 0;

  bool get _supplierLaunchActive {
    final until = supplierLaunchFreeUntil;
    return until != null && DateTime.now().toUtc().isBefore(until.toUtc());
  }

  BusinessPlan get _effective =>
      trialActive || plan == BusinessPlan.pro ? BusinessPlan.premium : plan;

  @override
  Future<void> ensureMyEntitlement() async {
    ensureCalls++;
  }

  @override
  Future<BusinessEntitlements> myEntitlement() async {
    final eff = _effective;
    // Tedarikçi etkin planı: kampanya aktifse premium (server aynası).
    final supEff = _supplierLaunchActive ? BusinessPlan.premium : eff;
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
      canUseDebtExpense: eff == BusinessPlan.premium,
      canUseDealerDriverOps: eff == BusinessPlan.premium,
      supplierEffectivePlan: supEff,
      supplierProductLimit: switch (supEff) {
        BusinessPlan.premium => -1,
        BusinessPlan.pro => 1,
        BusinessPlan.free => 1,
      },
      supplierCampaignLimit: switch (supEff) {
        BusinessPlan.premium => -1,
        BusinessPlan.pro => 0,
        BusinessPlan.free => 0,
      },
      supplierMonthlyReplyLimit: switch (supEff) {
        BusinessPlan.premium => -1,
        BusinessPlan.pro => 3,
        BusinessPlan.free => 3,
      },
      supplierCanAddProduct: true,
      supplierCanAddCampaign: supEff == BusinessPlan.premium,
      supplierCanReplyQuote: true,
      supplierListingFeeExempt: supEff == BusinessPlan.premium,
      promoStatus: trialActive ? 'active' : 'not_started',
      promoStartedAt: trialActive ? DateTime.now().toUtc() : null,
      promoExpiresAt: trialActive
          ? DateTime.now().toUtc().add(Duration(days: trialDaysLeft))
          : null,
      canStartPromo: canStartPromo,
      supplierLaunchFreeActive: _supplierLaunchActive,
      supplierLaunchFreeUntil: supplierLaunchFreeUntil,
    );
  }

  @override
  Future<BusinessEntitlements> activateLaunchPremiumPromo() async {
    if (canStartPromo) {
      trialActive = true;
      trialDaysLeft = 92;
      canStartPromo = false;
    }
    return myEntitlement();
  }

  bool supplierLaunchNoticeSeen = false;

  @override
  Future<bool> hasSeenSupplierLaunchNotice() async => supplierLaunchNoticeSeen;

  @override
  Future<void> markSupplierLaunchNoticeSeen() async {
    supplierLaunchNoticeSeen = true;
  }
}
