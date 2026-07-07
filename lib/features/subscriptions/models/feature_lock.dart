import '../../../core/constants/app_strings.dart';
import 'business_plan.dart';

/// Kilitli bir özelliğe basıldığında gösterilecek paywall içeriği.
///
/// Metinler [AppStrings]'ten gelir; asıl kısıt server-side'dadır (bu yalnız
/// bilgilendirme). Her factory bir ürün kararına karşılık gelir.
class FeatureLock {
  const FeatureLock({
    required this.title,
    required this.body,
    required this.requiredPlan,
  });

  final String title;
  final String body;

  /// Bu özelliği açan minimum plan (rozet/etiket için).
  final BusinessPlan requiredPlan;

  String get requiredPlanTag => requiredPlan == BusinessPlan.premium
      ? AppStrings.paywallPremiumTag
      : AppStrings.paywallProTag;

  static const FeatureLock branches = FeatureLock(
    title: AppStrings.paywallBranchesTitle,
    body: AppStrings.paywallBranchesBody,
    requiredPlan: BusinessPlan.premium,
  );

  static const FeatureLock dealerBook = FeatureLock(
    title: AppStrings.paywallDealerBookTitle,
    body: AppStrings.paywallDealerBookBody,
    requiredPlan: BusinessPlan.pro,
  );

  static const FeatureLock dealerDriverOps = FeatureLock(
    title: AppStrings.paywallDealerDriverTitle,
    body: AppStrings.paywallDealerDriverBody,
    requiredPlan: BusinessPlan.premium,
  );

  static const FeatureLock debtExpense = FeatureLock(
    title: AppStrings.paywallDebtExpenseTitle,
    body: AppStrings.paywallDebtExpenseBody,
    requiredPlan: BusinessPlan.pro,
  );

  /// Free reçete limiti (5) dolunca.
  static const FeatureLock recipeFree = FeatureLock(
    title: AppStrings.paywallRecipeFreeTitle,
    body: AppStrings.paywallRecipeFreeBody,
    requiredPlan: BusinessPlan.pro,
  );

  /// Pro reçete limiti (50) dolunca.
  static const FeatureLock recipePro = FeatureLock(
    title: AppStrings.paywallRecipeProTitle,
    body: AppStrings.paywallRecipeProBody,
    requiredPlan: BusinessPlan.premium,
  );

  static const FeatureLock calculatorPro = FeatureLock(
    title: AppStrings.paywallCalcProTitle,
    body: AppStrings.paywallCalcBody,
    requiredPlan: BusinessPlan.pro,
  );

  static const FeatureLock calculatorPremium = FeatureLock(
    title: AppStrings.paywallCalcPremiumTitle,
    body: AppStrings.paywallCalcBody,
    requiredPlan: BusinessPlan.premium,
  );

  static const FeatureLock reportPro = FeatureLock(
    title: AppStrings.paywallReportProTitle,
    body: AppStrings.paywallReportBody,
    requiredPlan: BusinessPlan.pro,
  );

  static const FeatureLock reportPremium = FeatureLock(
    title: AppStrings.paywallReportPremiumTitle,
    body: AppStrings.paywallReportBody,
    requiredPlan: BusinessPlan.premium,
  );
}
