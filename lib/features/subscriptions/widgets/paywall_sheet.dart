import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/feature_lock.dart';

/// Kilitli bir özelliğe basıldığında açılan bilgilendirme sheet'i.
///
/// Ödeme YOK — yalnız hangi paketin açtığını anlatır + Paketler ekranına
/// yönlendirir. Asıl kısıt server-side'da.
Future<void> showPaywallSheet(BuildContext context, FeatureLock lock) {
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

class _PaywallSheetBody extends StatelessWidget {
  const _PaywallSheetBody({required this.lock});

  final FeatureLock lock;

  @override
  Widget build(BuildContext context) {
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
