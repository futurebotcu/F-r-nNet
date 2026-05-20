// FırınNet — Donor-first social feed (port from
// `flutter-instagram-offline-first-clone`, MIT, see THIRD_PARTY_NOTICES.md).
//
// Donor: lib/feed/view/feed_page.dart (FeedPage + FeedView + FeedBody +
// FeedPageListView). Donor pattern: NestedScrollView + RefreshIndicator +
// CustomScrollView with stories carousel + post list. State management
// rewritten from BLoC to Riverpod; data layer rewritten from PowerSync to
// Supabase via `feedRepositoryProvider`.
//
// FırınNet farkları:
//   * BLoC `FeedBloc` yok → mevcut `feedPostsProvider` + `feedChangesProvider`.
//   * Hikaye akışı V1'de iskelet (Story create/view F5'te).
//   * AppBar FırınNet header'ı (Bildirim + Avatar + Gruplar shortcut).
//   * Composer ayrı route (`/social/composer`); donor pattern.
//   * Post kartı `SocialPostCard` (donor `PostLarge` widget tree).
//
// Eski `FeedScreen` (lib/features/feed/screens/feed_screen.dart) artık
// router'dan çağrılmaz; F-cleanup commit'inde silinir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/providers/feed_providers.dart';
import '../../notifications/widgets/notifications_header_action.dart';
import '../../profile/providers/profile_provider.dart';
import '../post/social_post_card.dart';
import '../stories/social_stories_carousel.dart';

/// FırınNet'in ana sosyal feed sayfası — donor-first.
///
/// Widget tree:
/// ```
/// PremiumScaffold
///   └ NestedScrollView
///       headerSliverBuilder → [SliverAppBar (FırınNet header)]
///       body → RefreshIndicator
///           └ ListView (Stories carousel + Post list)
/// ```
class SocialFeedPage extends ConsumerStatefulWidget {
  const SocialFeedPage({super.key});

  @override
  ConsumerState<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends ConsumerState<SocialFeedPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // V2 Social Core — donor `inview_notifier_list` muadili: ScrollController
    // listener ile bottom-threshold (300 px) altta `loadMore()` tetikler.
    // Yeni dependency eklemiyoruz; native ScrollController yeterli.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottomZone = pos.pixels >= pos.maxScrollExtent - 300;
    if (atBottomZone) {
      // No-op if already loading or hasMore=false (notifier guard).
      ref.read(feedPagedNotifierProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(feedPagedNotifierProvider.notifier).refresh();
    ref.invalidate(feedInsightsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pagedAsync = ref.watch(feedPagedNotifierProvider);
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SocialFeedHeader(),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: RefreshIndicator.adaptive(
                color: AppColors.copper,
                onRefresh: _onRefresh,
                child: pagedAsync.when(
                  loading: () => const _FeedLoading(),
                  error: (e, _) => _FeedError(onRetry: _onRefresh),
                  data: (state) => _FeedList(
                    posts: state.posts,
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    scrollController: _scrollController,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _ComposerFab(),
    );
  }
}

class _SocialFeedHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FirinNetHeader(
      title: AppStrings.feedTitle,
      subtitle: AppStrings.feedSubtitle,
      actions: [
        HeaderActionButton(
          icon: Icons.groups_2_outlined,
          tooltip: AppStrings.groupsTitle,
          onTap: () => context.go(AppRoutes.groups),
        ),
        const SizedBox(width: 8),
        const NotificationsHeaderAction(),
        const SizedBox(width: 8),
        const _ProfileAvatarAction(),
      ],
    );
  }
}

/// Header sağ ucu — kendi profiline push (donor: avatar tap → user_profile).
class _ProfileAvatarAction extends ConsumerWidget {
  const _ProfileAvatarAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : 'M';
    void onTap() {
      final user = ref.read(currentAuthUserProvider);
      if (user != null) {
        context.push('${AppRoutes.userPublicProfile}/${user.id}');
      } else {
        context.push(AppRoutes.profile);
      }
    }
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.borderHairline, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.softGold.withValues(alpha: 0.14),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağ alt köşede FAB — yeni gönderi composer'ına götürür.
class _ComposerFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => context.push(AppRoutes.socialComposer),
      backgroundColor: AppColors.copper,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: const Text(
        AppStrings.feedComposerNewPostCta,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// V1: Stories aktif değil — kullanıcı raporu: "boş story slot Instagram
/// hissi veriyor". V5 (story create + viewer aktive) gelince
/// `_kShowStories = true` yapılır.
const bool _kShowStories = false;

class _FeedList extends ConsumerWidget {
  const _FeedList({
    required this.posts,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
  });

  final List<FeedPost> posts;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (posts.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: const [
          if (_kShowStories) ...[
            SocialStoriesCarousel(),
            Divider(height: 1, color: AppColors.borderHairline),
          ],
          _FeedEmpty(),
        ],
      );
    }
    final int headerCount = _kShowStories ? 2 : 0;
    final int footerCount = isLoadingMore || !hasMore ? 1 : 0;
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(
        top: AppSpacing.s,
        bottom: AppSpacing.xxxl,
      ),
      itemCount: posts.length + headerCount + footerCount,
      itemBuilder: (_, i) {
        if (_kShowStories) {
          if (i == 0) return const SocialStoriesCarousel();
          if (i == 1) {
            return const Divider(
              height: 1,
              color: AppColors.borderHairline,
            );
          }
        }
        final postIndex = i - headerCount;
        if (postIndex < posts.length) {
          final post = posts[postIndex];
          return SocialPostCard(key: ValueKey(post.id), post: post);
        }
        // Footer: bottom indicator veya "End of feed" satırı.
        if (isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            ),
          );
        }
        // !hasMore: "Akışın sonu" mesajı sade.
        return const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.l,
          ),
          child: Center(
            child: Text(
              AppStrings.feedEndOfList,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        if (_kShowStories) SocialStoriesCarousel(),
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_kShowStories) const SocialStoriesCarousel(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.textMuted,
                  size: 36,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  AppStrings.feedLoadError,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.m),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    AppStrings.retry,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.s,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.feed_outlined,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              AppStrings.feedEmpty,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
