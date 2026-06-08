import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';

/// Donor (itsezlife) `user_profile_statistics.dart` pattern — 3 sayım
/// (Gönderiler / Takipçiler / Takip ediyor) tap area olarak.
/// Followers/Following tıklanınca list page push edilir.
class ProfileStatistics extends StatelessWidget {
  const ProfileStatistics({
    super.key,
    required this.userId,
    required this.postCountAsync,
    required this.countsAsync,
    required this.onTapFollowers,
    required this.onTapFollowing,
  });

  final String userId;
  final AsyncValue<int> postCountAsync;
  final AsyncValue<({int followers, int following})> countsAsync;
  final VoidCallback onTapFollowers;
  final VoidCallback onTapFollowing;

  @override
  Widget build(BuildContext context) {
    final postCount = postCountAsync.maybeWhen(data: (n) => n, orElse: () => 0);
    final followers = countsAsync.maybeWhen(
      data: (c) => c.followers,
      orElse: () => 0,
    );
    final following = countsAsync.maybeWhen(
      data: (c) => c.following,
      orElse: () => 0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      child: Container(
        // Hafif surface zemin + hairline — kaba "büyük kart" değil, sakin
        // bir sosyal istatistik şeridi.
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                value: postCount,
                label: AppStrings.profileStatPosts,
                onTap: null, // V1: post sayısı tap inert
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                value: followers,
                label: AppStrings.profileStatFollowers,
                onTap: onTapFollowers,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                value: following,
                label: AppStrings.profileStatFollowing,
                onTap: onTapFollowing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.6, height: 26, color: AppColors.borderHairline);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: AppTypography.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.meta),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: content,
    );
  }
}
