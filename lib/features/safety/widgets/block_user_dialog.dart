// FırınNet UGC Safety V1 — kullanıcı engelleme onay akışı.
//
// confirm dialog → blockUser → banner. Guest → AuthRequiredSheet.
// Self-block UI'da sunulmaz; repo katmanı da reddeder (defense-in-depth).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
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
  final confirmed = await showAppConfirmDialog(
    context,
    title: AppStrings.blockConfirmTitle,
    message: AppStrings.blockConfirmBody,
    confirmLabel: AppStrings.blockConfirmCta,
    cancelLabel: AppStrings.safetyCancel,
    destructive: true,
    icon: Icons.block_rounded,
  );
  if (!confirmed || !context.mounted) return false;

  final repo = ref.read(safetyRepositoryProvider);
  try {
    final result = await repo.blockUser(userId);
    if (!context.mounted) return true;
    if (result == BlockResult.alreadyBlocked) {
      AppFeedback.info(context, AppStrings.blockAlreadyBanner);
    } else {
      AppFeedback.success(context, AppStrings.blockSuccessBanner);
    }
    return true;
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
    return false;
  } catch (_) {
    if (!context.mounted) return false;
    AppFeedback.error(context, AppStrings.polishBlockError);
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
    AppFeedback.success(context, AppStrings.unblockSuccessBanner);
  } on GuestActionRequiredException {
    if (context.mounted) await showAuthRequiredSheet(context, ref);
  } catch (_) {
    if (!context.mounted) return;
    AppFeedback.error(context, AppStrings.polishUnblockError);
  }
}
