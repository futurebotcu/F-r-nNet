import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/follow_providers.dart';
import '../../profile/widgets/follow_button.dart';
import '../post/social_post_card.dart';
import '../providers/social_providers.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_statistics.dart';

/// FırınNet Social — Public profile page (donor-first rebuild).
///
/// Donor (itsezlife) `user_profile_page.dart` pattern'ı: header +
/// statistics tap area (followers/following clickable) + post list/grid.
/// Bizde V1: list (donor grid daha ileri faz). Public_profile_snapshot
/// RPC ile fallback safe — veri yoksa "FırınNet Kullanıcısı" gösterir,
/// boş ekran olmaz.
///
/// Route: `/u/:userId` (eski yeri public_profile_screen tarafından da
/// alınıyordu; F2 ile bu page yerini alır, app_router yönlendirir).
class SocialProfilePage extends ConsumerWidget {
  const SocialProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(socialProfileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));
    final countsAsync = ref.watch(followCountsProvider(userId));
    final postCountAsync = ref.watch(socialProfilePostCountProvider(userId));
    final me = ref.watch(currentAuthUserProvider);
    final isSelf = me != null && me.id == userId;

    return PremiumScaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (p) => Text(p.displayNameOrFallback),
          orElse: () => const Text(AppStrings.publicProfileTitle),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialProfileProvider(userId));
            ref.invalidate(userPostsProvider(userId));
            ref.invalidate(followCountsProvider(userId));
            ref.invalidate(socialProfilePostCountProvider(userId));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              ProfileHeader(profileAsync: profileAsync, isSelf: isSelf),
              const SizedBox(height: AppSpacing.m),
              ProfileStatistics(
                userId: userId,
                postCountAsync: postCountAsync,
                countsAsync: countsAsync,
                onTapFollowers: () => context.push(
                  '${AppRoutes.userPublicProfile}/$userId/followers',
                ),
                onTapFollowing: () => context.push(
                  '${AppRoutes.userPublicProfile}/$userId/following',
                ),
              ),
              if (!isSelf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.m,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FollowButton(userId: userId),
                  ),
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
                      child: Center(
                        child: Text(
                          AppStrings.publicProfilePostsEmpty,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  // V2 Commit 3.6 — Profile post list eski PostCardWired
                  // (sadece image render eder) yerine SocialPostCard
                  // kullanır. SocialPostCard image + video birlikte
                  // destekler; aynı widget feed ile profile'da tutarlı
                  // davranır (kullanıcı raporu: video feed'de görünüyor
                  // ama profile'da görünmüyordu).
                  return Column(
                    children: [
                      for (final p in posts)
                        SocialPostCard(key: ValueKey(p.id), post: p),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
