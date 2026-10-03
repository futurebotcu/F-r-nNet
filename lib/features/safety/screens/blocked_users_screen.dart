// FırınNet UGC Safety V1 — "Engellediğim kullanıcılar" ekranı.
//
// Gerekçe: engellenen kullanıcının içerikleri her yerde gizlendiği için
// profiline (ve oradaki "Engeli kaldır" menüsüne) ulaşmak fiilen imkânsız
// hale geliyordu. Bu ekran Settings'ten erişilen tek toplu unblock yüzeyi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/premium/premium_list_skeleton.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/safety_providers.dart';
import '../widgets/block_user_dialog.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUserIdsProvider);
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.blockedUsersTitle),
      ),
      body: SafeArea(
        child: blockedAsync.when(
          loading: () => const PremiumListSkeleton(itemCount: 3, itemHeight: 56),
          error: (_, __) => ErrorRetryState(
            title: AppStrings.finalBlockedUsersLoadError,
            subtitle: AppStrings.finalCheckConnectionRetry,
            onRetry: () => ref.invalidate(blockedUserIdsProvider),
          ),
          data: (ids) {
            if (ids.isEmpty) {
              return const EmptyState(
                icon: Icons.block_rounded,
                title: AppStrings.blockedUsersEmptyTitle,
                subtitle: AppStrings.blockedUsersEmptyBody,
              );
            }
            final sorted = ids.toList()..sort();
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pageH),
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) => _BlockedUserRow(userId: sorted[i]),
            );
          },
        ),
      ),
    );
  }
}

class _BlockedUserRow extends ConsumerWidget {
  const _BlockedUserRow({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İsim hafif snapshot RPC'den; çözülemezse güvenli fallback.
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final name = profileAsync.maybeWhen(
          data: (p) => p?.displayName?.trim(),
          orElse: () => null,
        ) ??
        PublicProfile.fallbackName;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          FirinNetAvatar(name: name),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.authorName,
            ),
          ),
          TextButton(
            onPressed: () => unblockUser(context, ref, userId: userId),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandInk),
            child: Text(
              AppStrings.safetyActionUnblock,
              style: AppTypography.smallAction.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
