import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/business_entitlements.dart';
import '../models/business_plan.dart';

/// Kullanıcının etkin planını gösteren küçük pill. Trial aktifse "Deneme".
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.entitlements});

  final BusinessEntitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _style(entitlements);
    return Container(
      key: const ValueKey('plan_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  static (String, Color, Color) _style(BusinessEntitlements e) {
    // Ticari lansman ücretsiz ayı (kayıt bazlı otomatik dönem).
    if (e.freePeriodActive) {
      return (
        AppStrings.commercialFreePeriodBadge,
        const Color(0xFFFFF7E6),
        const Color(0xFFB45309),
      );
    }
    if (e.isLaunchPromoActive) {
      return (
        AppStrings.planLaunchPromoLabel,
        const Color(0xFFFFF7E6),
        const Color(0xFFB45309),
      );
    }
    switch (e.effectivePlan) {
      case BusinessPlan.premium:
        return (
          AppStrings.planPremiumLabel,
          AppColors.brandInk,
          AppColors.brandLemon,
        );
      case BusinessPlan.pro:
        return (
          AppStrings.planProLabel,
          AppColors.brandLemon,
          AppColors.brandInk,
        );
      case BusinessPlan.free:
        return (
          AppStrings.planFreeLabel,
          AppColors.surfaceVariant,
          AppColors.textSecondary,
        );
    }
  }
}

/// Kilitli özellik üzerindeki küçük "Pro"/"Premium" rozeti + kilit ikonu.
class LockedFeatureBadge extends StatelessWidget {
  const LockedFeatureBadge({super.key, required this.requiredPlan});

  final BusinessPlan requiredPlan;

  @override
  Widget build(BuildContext context) {
    final isPremium = requiredPlan == BusinessPlan.premium;
    final label = isPremium
        ? AppStrings.paywallPremiumTag
        : AppStrings.paywallProTag;
    final bg = isPremium ? AppColors.brandInk : AppColors.brandLemon;
    final fg = isPremium ? AppColors.brandLemon : AppColors.brandInk;
    return Container(
      key: const ValueKey('locked_feature_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
