import '../../../core/constants/app_strings.dart';
import 'business_plan.dart';
import 'pricing_config.dart';

/// Kilitli bir özelliğe basıldığında gösterilecek paywall içeriği.
///
/// Metinler [AppStrings]'ten gelir; asıl kısıt server-side'dadır (bu yalnız
/// bilgilendirme). Her factory bir ürün kararına karşılık gelir.
class FeatureLock {
  const FeatureLock({
    required this.title,
    required this.body,
    required this.requiredPlan,
    this.priceHint = '',
  });

  final String title;
  final String body;

  /// Bu özelliği açan minimum plan (rozet/etiket için).
  final BusinessPlan requiredPlan;

  /// Paket fiyat ipucu (ör. "Pro paket 299 TL/ay"). Paywall sheet'te gösterilir.
  /// Fiyatlar [PricingConfig]'ten gelir (Paket Fiyatları UI V1).
  final String priceHint;

  String get requiredPlanTag => requiredPlan == BusinessPlan.premium
      ? AppStrings.paywallPremiumTag
      : AppStrings.paywallProTag;

  static const FeatureLock branches = FeatureLock(
    title: AppStrings.paywallBranchesTitle,
    body: AppStrings.paywallBranchesBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.bakeryPremiumHint,
  );

  static const FeatureLock dealerBook = FeatureLock(
    title: AppStrings.paywallDealerBookTitle,
    body: AppStrings.paywallDealerBookBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.premiumMonthlyHint,
  );

  static const FeatureLock dealerDriverOps = FeatureLock(
    title: AppStrings.paywallDealerDriverTitle,
    body: AppStrings.paywallDealerDriverBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.bakeryPremiumHint,
  );

  static const FeatureLock debtExpense = FeatureLock(
    title: AppStrings.paywallDebtExpenseTitle,
    body: AppStrings.paywallDebtExpenseBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.premiumMonthlyHint,
  );

  /// Free reçete limiti (5) dolunca.
  static const FeatureLock recipeFree = FeatureLock(
    title: AppStrings.paywallRecipeFreeTitle,
    body: AppStrings.paywallRecipeFreeBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.premiumMonthlyHint,
  );

  /// Pro reçete limiti (50) dolunca.
  static const FeatureLock recipePro = FeatureLock(
    title: AppStrings.paywallRecipeProTitle,
    body: AppStrings.paywallRecipeProBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.bakeryPremiumHint,
  );

  static const FeatureLock calculatorPro = FeatureLock(
    title: AppStrings.paywallCalcProTitle,
    body: AppStrings.paywallCalcBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.premiumMonthlyHint,
  );

  static const FeatureLock calculatorPremium = FeatureLock(
    title: AppStrings.paywallCalcPremiumTitle,
    body: AppStrings.paywallCalcBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.bakeryPremiumHint,
  );

  static const FeatureLock reportPro = FeatureLock(
    title: AppStrings.paywallReportProTitle,
    body: AppStrings.paywallReportBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.premiumMonthlyHint,
  );

  static const FeatureLock reportPremium = FeatureLock(
    title: AppStrings.paywallReportPremiumTitle,
    body: AppStrings.paywallReportBody,
    requiredPlan: BusinessPlan.premium,
    priceHint: PricingConfig.bakeryPremiumHint,
  );

  // ── Tedarikçi / Toptancı (B2B) lock'ları ──
  // Tedarikçi paket fiyatları henüz YAYIMLANMADI → paywall'da fiyat ipucu
  // gösterilmez (499 TL gibi ortak fiyatlar tedarikçiye yansıtılmaz).
  /// Free tedarikçi ürün limitine (1) ulaştı → Premium.
  static const FeatureLock supplierProductFree = FeatureLock(
    title: AppStrings.supPaywallProductFreeTitle,
    body: AppStrings.supPaywallProductFreeBody,
    requiredPlan: BusinessPlan.premium,
  );

  /// Eski Pro tedarikçi ürün limiti → Premium.
  static const FeatureLock supplierProductPro = FeatureLock(
    title: AppStrings.supPaywallProductProTitle,
    body: AppStrings.supPaywallProductProBody,
    requiredPlan: BusinessPlan.premium,
  );

  /// Free tedarikçi kampanya açamaz → Premium.
  static const FeatureLock supplierCampaignFree = FeatureLock(
    title: AppStrings.supPaywallCampaignFreeTitle,
    body: AppStrings.supPaywallCampaignFreeBody,
    requiredPlan: BusinessPlan.premium,
  );

  /// Eski Pro tedarikçi kampanya limiti → Premium.
  static const FeatureLock supplierCampaignPro = FeatureLock(
    title: AppStrings.supPaywallCampaignProTitle,
    body: AppStrings.supPaywallCampaignProBody,
    requiredPlan: BusinessPlan.premium,
  );

  /// Free tedarikçi aylık teklif cevabı limitine (3) ulaştı → Premium.
  static const FeatureLock supplierReplyFree = FeatureLock(
    title: AppStrings.supPaywallReplyFreeTitle,
    body: AppStrings.supPaywallReplyFreeBody,
    requiredPlan: BusinessPlan.premium,
  );

  /// Eski Pro tedarikçi teklif cevabı limiti → Premium.
  static const FeatureLock supplierReplyPro = FeatureLock(
    title: AppStrings.supPaywallReplyProTitle,
    body: AppStrings.supPaywallReplyProBody,
    requiredPlan: BusinessPlan.premium,
  );
}
