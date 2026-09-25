import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/business_entitlements.dart';
import '../models/business_plan.dart';
import '../models/pricing_config.dart';
import '../providers/subscription_providers.dart';
import 'supplier_launch_gift_sheet.dart';

/// Supplier plan/status card. It mirrors server-computed limits; server RLS/RPC
/// remains the source of truth for paid feature access.
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

    // Mağazam sekmesi de kampanya penceresindeki tedarikçinin kesin uğrağı —
    // bilgilendirme pop-up'ı burada da ilk uygun oturumda tetiklenir
    // (oturum + server 'görüldü' kaydıyla çift gösterim engellenir).
    final launchUntil = e.supplierLaunchFreeUntil;
    final launchActive = e.supplierLaunchFreeActive && launchUntil != null;
    if (launchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          maybeShowSupplierLaunchGiftSheet(context, ref);
        }
      });
    }

    final (title, sub) = _copy(e);
    return GestureDetector(
      key: const ValueKey('supplier_plan_card'),
      onTap: () => GoRouter.of(context).push(AppRoutes.plans),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
          border: launchActive
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
                    launchActive
                        ? Icons.card_giftcard_rounded
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
            if (_priceHint(e).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                _priceHint(e),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandInk,
                ),
              ),
            ],
            if (launchActive) ...[
              const SizedBox(height: AppSpacing.s),
              GestureDetector(
                key: const ValueKey('supplier_launch_details_link'),
                // Kampanya açıklaması istenildiğinde yeniden açılabilir.
                onTap: () => showSupplierLaunchGiftSheet(
                  context,
                  freeUntil: launchUntil,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 14,
                      color: AppColors.brandInk,
                    ),
                    SizedBox(width: 6),
                    Text(
                      AppStrings.supplierLaunchDetailsCta,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _priceHint(BusinessEntitlements e) {
    // Tedarikçiye fiyat YALNIZ server "paketler yayımlandı + satın alma
    // uygun" derse gösterilir; kampanya döneminde ve fiyatlar
    // yayımlanmadan asla (499 TL gibi ortak fiyatlar yansıtılmaz).
    if (!e.subscriptionPurchaseAllowed) return '';
    if (e.supplierEffectivePlan == BusinessPlan.premium) return '';
    return 'Premium ${PricingConfig.premiumMonthlyLabel} / '
        '${PricingConfig.premiumYearlyLabel}';
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

  // Tedarikçi kartı YALNIZ supplierEffectivePlan'ı yansıtır: kişisel promo
  // tedarikçi haklarını açmadığı için promo kopyası burada gösterilmez.
  (String, String) _copy(BusinessEntitlements e) {
    final launchUntil = e.supplierLaunchFreeUntil;
    if (e.supplierLaunchFreeActive && launchUntil != null) {
      return (
        AppStrings.supplierLaunchPlanTitle,
        '${formatSupplierLaunchDate(launchUntil)} '
            '${AppStrings.supplierLaunchFreeUntilSuffix}',
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
        const Icon(
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
