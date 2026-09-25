import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/feature_lock.dart';
import '../providers/subscription_providers.dart';
import 'commercial_launch_sheet.dart' show formatCommercialLaunchDay;

/// Kilitli bir özelliğe basıldığında açılan bilgilendirme sheet'i.
///
/// Ödeme YOK — yalnız hangi paketin açtığını, temel özelliklerin ücretsiz
/// kaldığını ve lansman fiyatını anlatır + Paketler ekranına yönlendirir.
/// Asıl kısıt server-side'da. (Eski CTA promosu kaldırıldı: ücretsiz dönem
/// artık kayıt bazlı otomatiktir.)
Future<void> showPaywallSheet(
  BuildContext context,
  FeatureLock lock, {
  // Eski promo akışının kalıntısı — CTA promo kaldırıldığı için sheet
  // içinde kilit AÇILMAZ; parametre çağıran API'ler bozulmasın diye durur.
  VoidCallback? onUnlocked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => _PaywallSheetBody(lock: lock),
  );
}

class _PaywallSheetBody extends ConsumerWidget {
  const _PaywallSheetBody({required this.lock});

  final FeatureLock lock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(myEntitlementProvider).valueOrNull;
    final launchPriceUntil = entitlement?.launchPriceUntil;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          key: const ValueKey('paywall_sheet'),
          mainAxisSize: MainAxisSize.min,
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
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandInk,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    lock.requiredPlanTag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandLemon,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              lock.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lock.body,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (lock.priceHint.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  const Icon(
                    Icons.sell_outlined,
                    size: 15,
                    color: AppColors.brandInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    lock.priceHint,
                    key: const ValueKey('paywall_price_hint'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandInk,
                    ),
                  ),
                ],
              ),
            ],
            if (launchPriceUntil != null) ...[
              const SizedBox(height: 4),
              Text(
                '${AppStrings.paywallLaunchPricePrefix}'
                '${formatCommercialLaunchDay(launchPriceUntil)}'
                '${AppStrings.paywallLaunchPriceSuffix}',
                key: const ValueKey('paywall_launch_price_until'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    AppStrings.paywallBasicsStayFree,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('paywall_view_plans'),
                onPressed: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).push(AppRoutes.plans);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: const Text(
                  AppStrings.paywallUpgradeCta,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
