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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
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
            if (promoActive) ...[
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
              price: PricingConfig.freeLabel,
              features: freeFeatures,
              plan: BusinessPlan.free,
              current: current,
              promoActive: promoActive,
            ),
            _PlanTile(
              key: const ValueKey('plan_tile_premium'),
              title: AppStrings.planPremiumLabel,
              price: PricingConfig.premiumMonthlyLabel,
              features: premiumFeatures,
              plan: BusinessPlan.premium,
              current: current,
              promoActive: promoActive,
              highlight: true,
            ),
            const SizedBox(height: AppSpacing.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlanPurchaseActions(account: account),
                  const SizedBox(height: AppSpacing.s),
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
                  if (!promoActive)
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
