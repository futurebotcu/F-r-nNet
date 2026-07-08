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

/// Tedarikçi mağaza ekranındaki plan/trial durum kartı + ürün/kampanya/cevap
/// kota göstergeleri. Karta basınca Paketler ekranı açılır.
///
/// Kota kaynakları: ürün/kampanya CANLI liste sayısı (dışarıdan verilir);
/// aylık teklif cevabı için server-hesaplı [BusinessEntitlements] alanları.
/// Asıl kısıt server-side; bu yalnız bilgilendirme.
class SupplierPlanCard extends ConsumerWidget {
  const SupplierPlanCard({
    super.key,
    required this.productCount,
    required this.campaignCount,
  });

  final int productCount;
  final int campaignCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(myEntitlementProvider).valueOrNull;
    if (e == null) return const SizedBox.shrink();

    final (title, sub) = _copy(e);
    return GestureDetector(
      key: const ValueKey('supplier_plan_card'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        : Icons.storefront_outlined,
                    size: 20,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            // Kota satırları: full-width (dar ekran + 1.3x'te taşmaz).
            _QuotaRow(
              label: AppStrings.supQuotaProducts,
              value: _limitLabel(productCount, e.supplierProductLimit),
            ),
            const SizedBox(height: AppSpacing.xs),
            _QuotaRow(
              label: AppStrings.supQuotaCampaigns,
              value: _limitLabel(campaignCount, e.supplierCampaignLimit),
            ),
            const SizedBox(height: AppSpacing.xs),
            _QuotaRow(label: AppStrings.supQuotaReplies, value: _replyLabel(e)),
          ],
        ),
      ),
    );
  }

  static String _limitLabel(int count, int limit) {
    if (limit < 0) return AppStrings.supQuotaUnlimited;
    return '$count / $limit';
  }

  static String _replyLabel(BusinessEntitlements e) {
    if (e.supplierRepliesUnlimited) return AppStrings.supQuotaUnlimited;
    if (!e.supplierCanReplyQuote) return AppStrings.supQuotaReplyExhausted;
    return '${e.supplierMonthlyReplyLimit}';
  }

  (String, String) _copy(BusinessEntitlements e) {
    if (e.isTrialActive) {
      return (
        AppStrings.supPlanTrialTitle,
        '${e.daysLeft} gün · ${AppStrings.supPlanTrialSub}',
      );
    }
    switch (e.supplierEffectivePlan) {
      case BusinessPlan.premium:
        return (AppStrings.supPlanPremiumTitle, AppStrings.supPlanPremiumSub);
      case BusinessPlan.pro:
        return (AppStrings.supPlanProTitle, AppStrings.supPlanProSub);
      case BusinessPlan.free:
        return (AppStrings.supPlanFreeTitle, AppStrings.supPlanFreeSub);
    }
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
