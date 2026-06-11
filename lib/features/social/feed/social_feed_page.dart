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
//   * AppBar FırınNet header'ı (Bildirim + Avatar).
//   * Composer ayrı route (`/social/composer`); donor pattern.
//   * Post kartı `SocialPostCard` (donor `PostLarge` widget tree).
//
// V2 Commit 4 cleanup — eski FeedScreen tamamen silindi; bu page
// donor-first sosyal akışın tek girişi.

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
import '../../safety/providers/safety_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../composer/inline_composer_card.dart';
import '../post/social_post_card.dart';
import '../stories/social_stories_carousel.dart';
import 'feed_segment_provider.dart';

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
      // Sprint 2A: segment'e göre doğru notifier'a loadMore.
      final segment = ref.read(feedSegmentProvider);
      if (segment == 0) {
        ref.read(feedPagedNotifierProvider.notifier).loadMore();
      } else {
        ref.read(feedFollowingPagedNotifierProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _onRefresh() async {
    // Sprint 2A: segment'e göre doğru notifier'a refresh.
    final segment = ref.read(feedSegmentProvider);
    if (segment == 0) {
      await ref.read(feedPagedNotifierProvider.notifier).refresh();
    } else {
      await ref.read(feedFollowingPagedNotifierProvider.notifier).refresh();
    }
    ref.invalidate(feedInsightsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final segment = ref.watch(feedSegmentProvider);
    final pagedAsync = segment == 0
        ? ref.watch(feedPagedNotifierProvider)
        : ref.watch(feedFollowingPagedNotifierProvider);
    // UGC Safety V1 — engellenen kullanıcıların postları render'da gizlenir.
    // Render-level filter bilinçli tercih: sayfalama offset'i RAW listeden
    // hesaplanmaya devam eder (duplicate/atlama riski yok). Çok engellide
    // sayfa görünür içeriği kısalabilir — server-side not.in P1 notu.
    final blocked = ref.watch(blockedUserIdsSyncProvider);
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SocialFeedHeader(),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: RefreshIndicator.adaptive(
                color: AppColors.brandLemonPressed,
                onRefresh: _onRefresh,
                child: pagedAsync.when(
                  loading: () => const _FeedLoading(),
                  error: (e, _) => _FeedError(onRetry: _onRefresh),
                  data: (state) => _FeedList(
                    posts: blocked.isEmpty
                        ? state.posts
                        : state.posts
                            .where((p) => !blocked.contains(p.ownerId))
                            .toList(),
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    scrollController: _scrollController,
                    segment: segment,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        const NotificationsHeaderAction(),
        const SizedBox(width: 4),
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
          height: 30,
          width: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandLemonPale,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.brandInk,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// V2 Social Core Commit 2 — Stories aktif. Carousel kendisi içeride
/// "aktif story yok + guest" durumunda boş render eder (SizedBox.shrink),
/// böylece ekran şişirme yok.
const bool _kShowStories = true;

class _FeedList extends ConsumerWidget {
  const _FeedList({
    required this.posts,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.segment,
  });

  final List<FeedPost> posts;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;

  /// Social UI Polish Sprint 2A — `0` = Genel Akış, `1` = Takip Edilenler.
  /// Empty state davranışı segment'e göre değişir.
  final int segment;

  /// Sosyal feed header sequence (Polish v1 + v2A birleşik):
  /// stories + segment chip row + InlineComposerCard.
  static List<Widget> _headers() {
    // Feed Premium Sprint — çizgi yoğunluğu azaltıldı: bölümler arası
    // ayrım artık boşluk + kart gölgesiyle yapılıyor (ERP çizgi hissi yok).
    // Stories altında tek ince ayraç kalır; segment ve composer kendi
    // kapsül/gölge kimlikleriyle nefes alır.
    return <Widget>[
      if (_kShowStories) const SocialStoriesCarousel(),
      if (_kShowStories)
        const Divider(height: 1, color: AppColors.borderHairline),
      const _FeedSegment(),
      const InlineComposerCard(),
      const SizedBox(height: AppSpacing.s),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = _headers();
    if (posts.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          ...headers,
          if (segment == 1) const _FollowingEmpty() else const _FeedEmpty(),
        ],
      );
    }
    final int headerCount = headers.length;
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
        if (i < headerCount) return headers[i];
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
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
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

/// Feed Premium Sprint — modern segmented control.
/// "Genel Akış" / "Takip Edilenler" arasında geçiş; seçili segment
/// yellow accent kapsul + koyu metin, kayan indicator hissi.
/// State kaynağı korunur: `feedSegmentProvider` (0 = Genel, 1 = Takip).
class _FeedSegment extends ConsumerWidget {
  const _FeedSegment();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(feedSegmentProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        6,
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        child: Row(
          children: [
            _SegmentTab(
              label: AppStrings.feedSegmentAll,
              icon: Icons.dynamic_feed_rounded,
              selected: segment == 0,
              onTap: () => ref.read(feedSegmentProvider.notifier).state = 0,
            ),
            _SegmentTab(
              label: AppStrings.feedSegmentFollowing,
              icon: Icons.people_alt_rounded,
              selected: segment == 1,
              onTap: () => ref.read(feedSegmentProvider.notifier).state = 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLemonPale : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.brandInk : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.brandInk : AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Social UI Polish Sprint 2A — "Takip Edilenler" segmenti boş durumu.
/// 3 alt-durum: guest / auth ama 0 follow / follow var ama post yok.
class _FollowingEmpty extends ConsumerWidget {
  const _FollowingEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final idsAsync = ref.watch(currentFollowingIdsProvider);

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyState(
          title: AppStrings.feedFollowingEmptyGuest,
          icon: Icons.lock_outline_rounded,
          actionLabel: AppStrings.feedFollowingBackToAll,
          onAction: () => ref.read(feedSegmentProvider.notifier).state = 0,
          compact: true,
        ),
      );
    }

    // Auth ama follow set'i boş — sadece data gelmişse karar veriyoruz.
    // idsAsync hâlâ loading ise boş post listesini empty state'le karşılama;
    // _FeedList build'i sadece posts.isEmpty olduğunda bizi çağırıyor.
    final ids = idsAsync.asData?.value ?? const <String>{};
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyState(
          title: AppStrings.feedFollowingEmptyNoFollows,
          subtitle: AppStrings.feedFollowingEmptyNoFollowsHint,
          icon: Icons.person_add_alt_1_outlined,
          actionLabel: AppStrings.feedFollowingBackToAll,
          onAction: () => ref.read(feedSegmentProvider.notifier).state = 0,
          compact: true,
        ),
      );
    }

    // Follow var ama post yok.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: EmptyState(
        title: AppStrings.feedFollowingEmptyNoPosts,
        icon: Icons.feed_outlined,
        actionLabel: AppStrings.feedFollowingBackToAll,
        onAction: () => ref.read(feedSegmentProvider.notifier).state = 0,
        compact: true,
      ),
    );
  }
}
