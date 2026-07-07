import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/business_entitlements.dart';
import '../models/business_plan.dart';
import '../providers/subscription_providers.dart';
import 'plan_badge.dart';

/// Ticari panelde gösterilen plan/trial durum kartı. Karta basınca Paketler
/// ekranı açılır. Entitlement yüklenmeden/başarısızsa hiçbir şey göstermez
/// (panel bozulmaz).
class PlanStatusCard extends ConsumerWidget {
  const PlanStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEntitlementProvider);
    final e = async.valueOrNull;
    if (e == null) return const SizedBox.shrink();

    final (title, sub) = _copy(e);
    return GestureDetector(
      key: const ValueKey('plan_status_card'),
      onTap: () => GoRouter.of(context).push(AppRoutes.plans),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
          border: e.isTrialActive
              ? Border.all(color: AppColors.brandLemon, width: 1.4)
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Icon(
                e.isTrialActive
                    ? Icons.auto_awesome_rounded
                    : Icons.workspace_premium_outlined,
                size: 20,
                color: AppColors.brandInk,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      PlanBadge(entitlements: e),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  (String, String) _copy(BusinessEntitlements e) {
    if (e.isTrialActive) {
      return (
        AppStrings.planCardTrialTitle,
        '${e.daysLeft} ${AppStrings.planCardTrialDaysLeft} · '
            '${AppStrings.planCardTrialSub}',
      );
    }
    switch (e.effectivePlan) {
      case BusinessPlan.premium:
        return (AppStrings.planCardPremiumTitle, AppStrings.planCardPremiumSub);
      case BusinessPlan.pro:
        return (AppStrings.planCardProTitle, AppStrings.planCardProSub);
      case BusinessPlan.free:
        return (AppStrings.planCardFreeTitle, AppStrings.planCardFreeSub);
    }
  }
}
