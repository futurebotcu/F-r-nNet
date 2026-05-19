import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../feed/screens/feed_screen.dart';
import '../providers/follow_providers.dart';
import '../providers/profile_provider.dart';
import '../widgets/follow_button.dart';

/// V1 Social S1 — Public profile sayfası (`/profile/:userId`).
///
/// Kullanıcının display_name + role badge + city + post sayısı + kendi
/// gönderileri listesi. Henüz follow/unfollow yok (S2'de gelir). Owner
/// kendi profilini açabilir (subtitle "Bu senin profilin"); başkasıysa
/// nötr görünür.
///
/// Veri kaynağı:
///   * `publicProfileProvider(userId)` — RPC `public_profile_snapshot`
///   * `userPostsProvider(userId)` — `listPostsByOwner` repo
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));
    final me = ref.watch(currentAuthUserProvider);
    final isSelf = me != null && me.id == userId;

    return PremiumScaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (p) => Text(p?.displayNameOrFallback ??
              AppStrings.publicProfileFallbackTitle),
          orElse: () => const Text(AppStrings.publicProfileTitle),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _ProfileHeader(
              userId: userId,
              profileAsync: profileAsync,
              postsCount: postsAsync.maybeWhen(
                data: (l) => l.length,
                orElse: () => null,
              ),
              isSelf: isSelf,
            ),
            const SizedBox(height: AppSpacing.m),
            const Divider(
              height: 0,
              thickness: 0.6,
              color: AppColors.borderHairline,
            ),
            postsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    AppStrings.publicProfileLoadError,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.l),
                    child: Text(
                      AppStrings.publicProfilePostsEmpty,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in posts)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageH,
                          AppSpacing.s,
                          AppSpacing.pageH,
                          0,
                        ),
                        child: PostCardWired(post: p),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.userId,
    required this.profileAsync,
    required this.postsCount,
    required this.isSelf,
  });

  final String userId;
  final AsyncValue<PublicProfile?> profileAsync;
  final int? postsCount;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followCounts = ref.watch(followCountsProvider(userId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.m,
      ),
      child: profileAsync.when(
        loading: () => const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Text(
          AppStrings.publicProfileLoadError,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        data: (p) {
          final name = p?.displayNameOrFallback ??
              AppStrings.publicProfileFallbackTitle;
          final role = p?.professionBadge;
          final city = p?.city;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.softGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role != null && role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (city != null && city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              city,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (postsCount != null)
                          _StatPill(
                            label: AppStrings.publicProfilePostsHeading(
                              postsCount!,
                            ),
                            color: AppColors.copper,
                          ),
                        // V1 Social S2 — followers + following counts.
                        followCounts.maybeWhen(
                          data: (c) => _StatPill(
                            label: AppStrings.followCountFollowers(c.followers),
                            color: AppColors.softGold,
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        followCounts.maybeWhen(
                          data: (c) => _StatPill(
                            label: AppStrings.followCountFollowing(c.following),
                            color: AppColors.softGold,
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        if (isSelf)
                          _StatPill(
                            label: AppStrings.publicProfileSelfHint,
                            color: AppColors.softGold,
                            soft: true,
                          ),
                      ],
                    ),
                    if (!isSelf) ...[
                      const SizedBox(height: AppSpacing.s),
                      // V1 Social S2 — Takip et / Takipten çık.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FollowButton(userId: userId),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.color,
    this.soft = false,
  });
  final String label;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: soft ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: soft ? 0.36 : 0.32),
          width: 0.6,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
