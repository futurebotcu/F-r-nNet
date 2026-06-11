// FırınNet UGC Safety V1 — kullanıcı engelleme onay akışı.
//
// confirm dialog → blockUser → banner. Guest → AuthRequiredSheet.
// Self-block UI'da sunulmaz; repo katmanı da reddeder (defense-in-depth).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/report_models.dart';
import '../providers/safety_providers.dart';

/// Engelleme akışını başlatır. Onaylanıp tamamlanırsa `true` döner.
Future<bool> confirmAndBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) async {
  if (!AuthRequiredGuard.canWriteWithRef(ref)) {
    await showAuthRequiredSheet(context, ref);
    return false;
  }
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.elevatedCard,
      title: const Text(AppStrings.blockConfirmTitle),
      content: const Text(
        AppStrings.blockConfirmBody,
        style: TextStyle(height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(AppStrings.safetyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.surface,
          ),
          child: const Text(AppStrings.blockConfirmCta),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final repo = ref.read(safetyRepositoryProvider);
  try {
    final result = await repo.blockUser(userId);
    if (!context.mounted) return true;
    PremiumTopBannerController.show(
      context,
      message: result == BlockResult.alreadyBlocked
          ? AppStrings.blockAlreadyBanner
          : AppStrings.blockSuccessBanner,
      tone: PremiumTopBannerTone.success,
    );
    return true;
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
    return false;
  } catch (_) {
    if (!context.mounted) return false;
    PremiumTopBannerController.show(
      context,
      message: AppStrings.safetyErrorBanner,
      tone: PremiumTopBannerTone.danger,
    );
    return false;
  }
}

/// Engeli kaldırır (onay istemez — geri alınabilir aksiyon).
Future<void> unblockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) async {
  final repo = ref.read(safetyRepositoryProvider);
  try {
    await repo.unblockUser(userId);
    if (!context.mounted) return;
    PremiumTopBannerController.show(
      context,
      message: AppStrings.unblockSuccessBanner,
      tone: PremiumTopBannerTone.info,
    );
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
  } catch (_) {
    if (!context.mounted) return;
    PremiumTopBannerController.show(
      context,
      message: AppStrings.safetyErrorBanner,
      tone: PremiumTopBannerTone.danger,
    );
  }
}
