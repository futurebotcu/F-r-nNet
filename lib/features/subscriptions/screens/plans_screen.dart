import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../payments/widgets/plan_purchase_actions.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/business_plan.dart';
import '../models/pricing_config.dart';
import '../providers/subscription_providers.dart';
import '../widgets/commercial_launch_sheet.dart'
    show formatCommercialLaunchDay;
import '../widgets/supplier_launch_gift_sheet.dart';

/// Commercial package screen. Store prices come from RevenueCat/Google Play;
/// config prices are fallback copy only.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(myEntitlementProvider).valueOrNull;
    final account = ref.watch(profileControllerProvider)?.accountType;
    final isWholesaler = account == AccountType.wholesaler;
    final current = isWholesaler
        ? entitlement?.supplierEffectivePlan
        : entitlement?.effectivePlan;
    final promoActive = entitlement?.isLaunchPromoActive ?? false;
    // Tedarikçi: kişisel promo modeli geçerli değil (kampanya modeli);
    // satın alma/fiyat yalnız server "uygun" derse gösterilir (yüklenene
    // kadar fail-closed).
    final purchaseAllowed = isWholesaler
        ? (entitlement?.subscriptionPurchaseAllowed ?? false)
        : true;
    final launchActive = isWholesaler &&
        (entitlement?.supplierLaunchFreeActive ?? false) &&
        entitlement?.supplierLaunchFreeUntil != null;
    final isCommercial = account == AccountType.commercial;
    // Ticari kayıt bazlı ücretsiz ay + lansman fiyat dönemi bilgisi.
    final freePeriodActive =
        isCommercial && (entitlement?.freePeriodActive ?? false);
    final launchPriceUntil =
        isCommercial ? entitlement?.launchPriceUntil : null;
    final (freeFeatures, premiumFeatures) = isWholesaler
        ? (AppStrings.supPlanFreeFeatures, AppStrings.supPlanPremiumFeatures)
        : (AppStrings.planFreeFeatures, AppStrings.planPremiumFeatures);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const FirinNetHeader(title: AppStrings.plansTitle),
            // "İlk 3 ay ücretsiz" promo dili tedarikçiye gösterilmez.
            if (!isWholesaler)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: Text(
                  AppStrings.plansLaunchSubtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            if (launchActive) ...[
              const SizedBox(height: AppSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: _SupplierLaunchBanner(
                  freeUntil: entitlement!.supplierLaunchFreeUntil!,
                ),
              ),
            ] else if (freePeriodActive &&
                entitlement?.freePeriodEndsAt != null) ...[
              const SizedBox(height: AppSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: _FreePeriodBanner(
                  daysLeft: entitlement!.freePeriodDaysLeft,
                  endsAt: entitlement.freePeriodEndsAt!,
                ),
              ),
            ] else if (promoActive && !isWholesaler) ...[
              const SizedBox(height: AppSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: _PromoBanner(
                  daysLeft:
                      entitlement?.promoDaysLeft ?? entitlement?.daysLeft ?? 0,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            _PlanTile(
              key: const ValueKey('plan_tile_free'),
              title: AppStrings.planFreeLabel,
              // Ticaride "Her zaman ücretsiz" vurgusu (temel özellikler
              // dönemden bağımsız açık kalır).
              price: isCommercial
                  ? AppStrings.planFreeAlwaysLabel
                  : PricingConfig.freeLabel,
              features: freeFeatures,
              plan: BusinessPlan.free,
              current: current,
              promoActive: promoActive,
            ),
            _PlanTile(
              key: const ValueKey('plan_tile_premium'),
              title: AppStrings.planPremiumLabel,
              // Tedarikçi fiyatı yayımlanmadan ortak 499 TL yansıtılmaz.
              price: purchaseAllowed
                  ? PricingConfig.premiumMonthlyLabel
                  : AppStrings.supplierPriceComingSoon,
              features: premiumFeatures,
              plan: BusinessPlan.premium,
              current: current,
              promoActive: promoActive,
              highlight: true,
            ),
            if (launchPriceUntil != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  '${AppStrings.paywallLaunchPricePrefix}'
                  '${formatCommercialLaunchDay(launchPriceUntil)}'
                  '${AppStrings.paywallLaunchPriceSuffix}',
                  key: const ValueKey('plans_launch_price_note'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Satın alma çağrısı yalnız server uygun derse (asıl
                  // engel ödeme servisinde de var — çift katman).
                  if (purchaseAllowed) ...[
                    PlanPurchaseActions(account: account),
                    const SizedBox(height: AppSpacing.s),
                  ],
                  FilledButton(
                    key: const ValueKey('plans_support_cta'),
                    onPressed: () =>
                        GoRouter.of(context).push(AppRoutes.settingsSupport),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.brandInk,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: const Text(
                      AppStrings.plansSupportCta,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (!promoActive && !isWholesaler)
                    Text(
                      AppStrings.plansLaunchTrialCta,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (purchaseAllowed)
                    Text(
                      AppStrings.plansStoreReady,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticari ücretsiz ay banner'ı — dönem boyunca Paketler ekranında görünür.
class _FreePeriodBanner extends StatelessWidget {
  const _FreePeriodBanner({required this.daysLeft, required this.endsAt});

  final int daysLeft;
  final DateTime endsAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plans_free_period_banner'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemon),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 18,
            color: AppColors.brandInk,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.commercialFreePeriodTitle} - $daysLeft '
                  '${AppStrings.planCardTrialDaysLeft}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${formatCommercialLaunchDay(endsAt)} '
                  '${AppStrings.commercialFreePeriodSubSuffix}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tedarikçi Lansman Kampanyası bilgisi — abonelik ekranında kampanya
/// boyunca görünür; açıklama pop-up'ı buradan yeniden açılabilir.
class _SupplierLaunchBanner extends StatelessWidget {
  const _SupplierLaunchBanner({required this.freeUntil});

  final DateTime freeUntil;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatSupplierLaunchDate(freeUntil);
    return GestureDetector(
      key: const ValueKey('plans_supplier_launch_banner'),
      onTap: () => showSupplierLaunchGiftSheet(context, freeUntil: freeUntil),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.brandLemonPale,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.brandLemon),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 18,
              color: AppColors.brandInk,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppStrings.supplierLaunchPlanTitle} — $dateLabel '
                    '${AppStrings.supplierLaunchFreeUntilSuffix}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    AppStrings.supplierLaunchDetailsCta,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plans_promo_banner'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: const Color(0xFFFCD9A0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.planLaunchPromoTitle} - $daysLeft '
                  '${AppStrings.planCardTrialDaysLeft}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  AppStrings.planLaunchPromoSub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB45309),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    super.key,
    required this.title,
    required this.price,
    required this.features,
    required this.plan,
    required this.current,
    required this.promoActive,
    this.highlight = false,
  });

  final String title;
  final String price;
  final String features;
  final BusinessPlan plan;
  final BusinessPlan? current;
  final bool promoActive;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final isCurrent = !promoActive && current == plan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xs,
        AppSpacing.pageH,
        AppSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
          border: highlight
              ? Border.all(color: AppColors.brandInk, width: 1.4)
              : (isCurrent
                    ? Border.all(color: AppColors.brandLemon, width: 1.4)
                    : null),
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandLemon,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      AppStrings.plansCurrentBadge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              price,
              key: ValueKey('plan_price_${plan.name}'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.brandInk,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              features,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
