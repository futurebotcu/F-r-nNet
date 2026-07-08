import 'package:flutter/foundation.dart';

import 'business_plan.dart';

/// Çağıran kullanıcının etkin ücretlendirme durumu — `my_entitlement()` RPC'sinin
/// güvenli alanlarının Dart karşılığı.
///
/// GÜVENLİK NOTU: Bu client-side görünümdür; asıl kısıtlar server-side RLS/RPC
/// gate'lerindedir (branches_insert, can_add_dealer, can_add_recipe,
/// has_business_feature). Client bu değerleri yalnız UX (kilit rozeti, "kalan
/// gün", limit sayacı) için kullanır — bunlara güvenerek güvenlik kararı
/// verilmez.
@immutable
class BusinessEntitlements {
  const BusinessEntitlements({
    this.plan = BusinessPlan.free,
    this.effectivePlan = BusinessPlan.free,
    this.isTrialActive = false,
    this.trialEndsAt,
    this.daysLeft = 0,
    this.recipeLimit = 5,
    this.dealerLimit = 0,
    this.canUseBranches = false,
    this.canUseDebtExpense = false,
    this.canUseDealerDriverOps = false,
    // Tedarikçi/toptancı (B2B) alanları — yalnız wholesaler için anlamlı;
    // diğer hesaplarda güvenli free defaultları.
    this.supplierEffectivePlan = BusinessPlan.free,
    this.supplierProductLimit = 1,
    this.supplierCampaignLimit = 0,
    this.supplierMonthlyReplyLimit = 3,
    this.supplierCanAddProduct = true,
    this.supplierCanAddCampaign = false,
    this.supplierCanReplyQuote = true,
    this.supplierListingFeeExempt = false,
  });

  /// Gerçek plan (trial'dan bağımsız).
  final BusinessPlan plan;

  /// Etkin plan — trial aktifse premium.
  final BusinessPlan effectivePlan;
  final bool isTrialActive;
  final DateTime? trialEndsAt;
  final int daysLeft;

  /// -1 = sınırsız.
  final int recipeLimit;

  /// -1 = sınırsız.
  final int dealerLimit;

  final bool canUseBranches;
  final bool canUseDebtExpense;
  final bool canUseDealerDriverOps;

  // ── Tedarikçi/toptancı (B2B) — server my_entitlement supplier_* alanları.
  // Tedarikçi trial = Pro-benzeri (Premium değil); asıl kısıt server-side.
  /// Tedarikçi etkin planı (trial→pro).
  final BusinessPlan supplierEffectivePlan;

  /// -1 = sınırsız.
  final int supplierProductLimit;

  /// -1 = sınırsız.
  final int supplierCampaignLimit;

  /// -1 = sınırsız.
  final int supplierMonthlyReplyLimit;
  final bool supplierCanAddProduct;
  final bool supplierCanAddCampaign;
  final bool supplierCanReplyQuote;

  /// Tedarikçi Pro/Premium/trial → ilan yayın ücreti muaf.
  final bool supplierListingFeeExempt;

  bool get supplierProductsUnlimited => supplierProductLimit < 0;
  bool get supplierCampaignsUnlimited => supplierCampaignLimit < 0;
  bool get supplierRepliesUnlimited => supplierMonthlyReplyLimit < 0;

  bool get isPremium => effectivePlan == BusinessPlan.premium;
  bool get isPro => effectivePlan == BusinessPlan.pro;
  bool get isFree => effectivePlan == BusinessPlan.free;
  bool get recipesUnlimited => recipeLimit < 0;
  bool get dealersUnlimited => dealerLimit < 0;

  /// Bayi Defteri açık mı? Free kapalı (dealer_limit 0); Pro/Premium açık
  /// (sınırsız). Pro↔Premium ayrımı [canUseDealerDriverOps]'tadır.
  bool get dealerEnabled => dealersUnlimited || dealerLimit > 0;

  /// UX aynası (asıl karar server'da): verilen mevcut sayıyla yeni ekleme
  /// yapılabilir mi? -1 sınırsız → daima true.
  bool canAddRecipe(int current) => recipesUnlimited || current < recipeLimit;
  bool canAddDealer(int currentActive) =>
      dealersUnlimited || currentActive < dealerLimit;

  factory BusinessEntitlements.fromRow(Map<String, dynamic> row) {
    return BusinessEntitlements(
      plan: BusinessPlanMeta.fromKey(row['plan'] as String?),
      effectivePlan: BusinessPlanMeta.fromKey(row['effective_plan'] as String?),
      isTrialActive: (row['is_trial_active'] as bool?) ?? false,
      trialEndsAt: row['trial_ends_at'] == null
          ? null
          : DateTime.tryParse(row['trial_ends_at'] as String),
      daysLeft: (row['days_left'] as num?)?.toInt() ?? 0,
      recipeLimit: (row['recipe_limit'] as num?)?.toInt() ?? 5,
      dealerLimit: (row['dealer_limit'] as num?)?.toInt() ?? 0,
      canUseBranches: (row['can_use_branches'] as bool?) ?? false,
      canUseDebtExpense: (row['can_use_debt_expense'] as bool?) ?? false,
      canUseDealerDriverOps:
          (row['can_use_dealer_driver_ops'] as bool?) ?? false,
      supplierEffectivePlan: BusinessPlanMeta.fromKey(
        row['supplier_effective_plan'] as String?,
      ),
      supplierProductLimit:
          (row['supplier_product_limit'] as num?)?.toInt() ?? 1,
      supplierCampaignLimit:
          (row['supplier_campaign_limit'] as num?)?.toInt() ?? 0,
      supplierMonthlyReplyLimit:
          (row['supplier_monthly_reply_limit'] as num?)?.toInt() ?? 3,
      supplierCanAddProduct: (row['supplier_can_add_product'] as bool?) ?? true,
      supplierCanAddCampaign:
          (row['supplier_can_add_campaign'] as bool?) ?? false,
      supplierCanReplyQuote: (row['supplier_can_reply_quote'] as bool?) ?? true,
      supplierListingFeeExempt:
          (row['supplier_listing_fee_exempt'] as bool?) ?? false,
    );
  }

  /// Güvenli varsayılan (Supabase kapalı / hata / non-commercial): en kısıtlı
  /// commercial görünümü DEĞİL — free. UI fail-closed davranır (kilit gösterir).
  static const BusinessEntitlements free = BusinessEntitlements();
}
