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
    this.promoStatus = 'not_started',
    this.promoStartedAt,
    this.promoExpiresAt,
    this.canStartPromo = true,
    this.supplierLaunchFreeActive = false,
    this.supplierLaunchFreeUntil,
    this.subscriptionPurchaseAllowed = true,
    this.freePeriodActive = false,
    this.freePeriodStartedAt,
    this.freePeriodEndsAt,
    this.freePeriodDaysLeft = 0,
    this.launchPriceUntil,
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
  final String promoStatus;
  final DateTime? promoStartedAt;
  final DateTime? promoExpiresAt;
  final bool canStartPromo;

  // ── Tedarikçi Lansman Kampanyası — server-side ortak pencere. Süre ve
  // hak kontrolü tamamen server'dadır (cihaz saatiyle uzatılamaz); client
  // bu alanları yalnız bilgilendirme UI'ı için kullanır.
  /// Kampanya şu an bu kullanıcı için aktif mi (yalnız wholesaler'da true
  /// olabilir).
  final bool supplierLaunchFreeActive;

  /// Ortak ücretsiz dönem bitişi (yalnız wholesaler'da dolu; tarih
  /// yapılandırılmadıysa null — UI hiçbir kampanya yüzeyi göstermez).
  final DateTime? supplierLaunchFreeUntil;

  /// Abonelik satın alma uygunluğu — SERVER kararı (my_entitlement).
  /// Tedarikçide kampanya süresince ve paket fiyatları yayımlanana kadar
  /// false: UI satın alma/fiyat göstermez, ödeme servisi mağaza çağrısını
  /// başlatmaz. Eski backend alanı döndürmezse true (mevcut davranış).
  final bool subscriptionPurchaseAllowed;

  // ── Ticari Lansman Modeli — kayıt bazlı OTOMATİK 1 aylık ücretsiz Premium
  // dönemi (yalnız commercial'da dolu). Süre/hak tamamen server'dadır.
  final bool freePeriodActive;
  final DateTime? freePeriodStartedAt;

  /// Ücretsiz dönemin bitiş ANI (hariç). Dolu + geçmişse dönem sona ermiştir
  /// (bitiş pop-up'ı bu durumla tetiklenir).
  final DateTime? freePeriodEndsAt;
  final int freePeriodDaysLeft;

  /// Lansman fiyatının geçerli olduğu son an (hariç) — yalnız bilgilendirme
  /// metinleri için (fiyatı mağaza belirler).
  final DateTime? launchPriceUntil;

  bool get supplierProductsUnlimited => supplierProductLimit < 0;
  bool get supplierCampaignsUnlimited => supplierCampaignLimit < 0;
  bool get supplierRepliesUnlimited => supplierMonthlyReplyLimit < 0;

  bool get isPremium => effectivePlan == BusinessPlan.premium;
  bool get canUsePremiumFeature => effectivePlan == BusinessPlan.premium;
  bool get isLaunchPromoActive =>
      promoStatus == 'active' && promoExpiresAt != null;
  int get promoDaysLeft {
    final expires = promoExpiresAt;
    if (expires == null) return daysLeft;
    final diff = expires.difference(DateTime.now().toUtc()).inDays;
    return diff < 0 ? 0 : diff;
  }
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
      promoStatus: (row['promo_status'] as String?) ??
          (((row['is_trial_active'] as bool?) ?? false)
              ? 'active'
              : 'not_started'),
      promoStartedAt: row['promo_started_at'] == null
          ? null
          : DateTime.tryParse(row['promo_started_at'] as String),
      promoExpiresAt: row['promo_expires_at'] == null
          ? null
          : DateTime.tryParse(row['promo_expires_at'] as String),
      canStartPromo: (row['can_start_promo'] as bool?) ?? true,
      supplierLaunchFreeActive:
          (row['supplier_launch_free_active'] as bool?) ?? false,
      supplierLaunchFreeUntil: row['supplier_launch_free_until'] == null
          ? null
          : DateTime.tryParse(row['supplier_launch_free_until'] as String),
      subscriptionPurchaseAllowed:
          (row['subscription_purchase_allowed'] as bool?) ?? true,
      freePeriodActive: (row['free_period_active'] as bool?) ?? false,
      freePeriodStartedAt: row['free_period_started_at'] == null
          ? null
          : DateTime.tryParse(row['free_period_started_at'] as String),
      freePeriodEndsAt: row['free_period_ends_at'] == null
          ? null
          : DateTime.tryParse(row['free_period_ends_at'] as String),
      freePeriodDaysLeft: (row['free_period_days_left'] as num?)?.toInt() ?? 0,
      launchPriceUntil: row['launch_price_until'] == null
          ? null
          : DateTime.tryParse(row['launch_price_until'] as String),
    );
  }

  /// Güvenli varsayılan (Supabase kapalı / hata / non-commercial): en kısıtlı
  /// commercial görünümü DEĞİL — free. UI fail-closed davranır (kilit gösterir).
  static const BusinessEntitlements free = BusinessEntitlements();
}
