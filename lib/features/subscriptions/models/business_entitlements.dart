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

  bool get isPremium => effectivePlan == BusinessPlan.premium;
  bool get isPro => effectivePlan == BusinessPlan.pro;
  bool get isFree => effectivePlan == BusinessPlan.free;
  bool get recipesUnlimited => recipeLimit < 0;
  bool get dealersUnlimited => dealerLimit < 0;

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
    );
  }

  /// Güvenli varsayılan (Supabase kapalı / hata / non-commercial): en kısıtlı
  /// commercial görünümü DEĞİL — free. UI fail-closed davranır (kilit gösterir).
  static const BusinessEntitlements free = BusinessEntitlements();
}
