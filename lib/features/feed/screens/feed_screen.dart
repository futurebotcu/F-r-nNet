import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/feed_post_card.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/providers/profile_provider.dart';
import '../../social_groups/models/social_group.dart';
import '../../social_groups/providers/social_group_providers.dart';
import '../../social_groups/services/group_join_result.dart';
import '../../social_groups/widgets/group_card.dart';
import '../models/feed_insight.dart';
import '../models/feed_post.dart';
import '../providers/feed_providers.dart';
import '../widgets/feed_comment_sheet.dart';
import '../widgets/feed_composer.dart';
import '../widgets/insight_card.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: _FeedHeader()),
            const SliverToBoxAdapter(child: _GroupsSection()),
            const SliverToBoxAdapter(child: FeedComposer()),
            const SliverToBoxAdapter(
              child: SectionLabel(
                title: AppStrings.feedSectionPosts,
                trailingLabel: AppStrings.feedSectionAll,
              ),
            ),
            const _FeedPostsSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

/// Feed üst başlığı — sağ üstte Gruplar tab'ına geçiren kestirme.
class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    // V1 — header search icon V1'de _noop'tu (sessiz no-op). Search
    // backend henüz yok; sessiz tıklama yerine icon hiç gösterilmiyor.
    // V2'de gerçek search açılınca buraya geri eklenir.
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
        _ProfileAvatarAction(
          onTap: () => context.push(AppRoutes.profile),
        ),
      ],
    );
  }
}

/// Header sağ ucundaki dairesel avatar — profil ekranına push ile gider.
/// Profil ana tab'dan çıkarıldığı için (V Nav-Profile-To-Jobs) en sağda durur;
/// tıklamayla `/profile` full-screen push olur.
class _ProfileAvatarAction extends ConsumerWidget {
  const _ProfileAvatarAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : 'M';
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(
        side: BorderSide(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.softGold.withValues(alpha: 0.08),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.softGold, AppColors.copperMuted],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.copper.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Sektör Grupları carousel (V Sosyal V1)

class _GroupsSection extends ConsumerWidget {
  const _GroupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularGroupsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: AppStrings.feedSectionGroups,
          trailingLabel: AppStrings.feedGroupsCtaAll,
          // Tab geçişi (push değil) — bottom nav state'i Gruplar olarak güncellenir.
          onTrailingTap: () => context.go(AppRoutes.groups),
        ),
        SizedBox(
          height: 290,
          child: popularAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Text('Gruplar: $e'),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: Text(
                    AppStrings.feedGroupsEmpty,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.s),
                itemBuilder: (_, i) => _CarouselGroupCard(group: groups[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarouselGroupCard extends ConsumerWidget {
  const _CarouselGroupCard({required this.group});
  final SocialGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(isJoinedProvider(group.id));
    return GroupCard(
      group: group,
      isJoined: joined,
      width: 280,
      compact: true,
      onTap: () => context.push('${AppRoutes.groups}/${group.id}'),
      onPrimary: () async {
        if (joined) {
          context.push('${AppRoutes.groups}/${group.id}');
          return;
        }
        // V1.3.3 — repo guarded; runGuardedMutation guest exception'ı yakalar.
        await runGuardedMutation(
          context,
          ref,
          action: () async {
            final repo = ref.read(socialGroupRepositoryProvider);
            final r = await repo.joinGroup(group.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(r.message)),
            );
            if (r == GroupJoinResult.success) {
              context.push('${AppRoutes.groups}/${group.id}');
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────── Posts + insight enjeksiyonu

class _FeedPostsSliver extends ConsumerWidget {
  const _FeedPostsSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(feedPostsProvider(null));
    final insightsAsync = ref.watch(feedInsightsProvider);

    return postsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageH,
            vertical: AppSpacing.l,
          ),
          child: _FeedEmpty(
            icon: Icons.cloud_off_rounded,
            message: AppStrings.feedErrorGeneric,
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
                vertical: AppSpacing.l,
              ),
              child: _FeedEmpty(
                icon: Icons.dynamic_feed_outlined,
                message: AppStrings.feedEmptyState,
              ),
            ),
          );
        }
        final insights = insightsAsync.maybeWhen(
          data: (list) => list,
          orElse: () => const [],
        );
        // Insight kartlarını feed içine serpiştir: 2. ve 5. postlardan sonra.
        final injected = _interleave(posts, insights);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.l,
          ),
          sliver: SliverList.separated(
            itemCount: injected.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.l),
            itemBuilder: (_, i) {
              final item = injected[i];
              if (item is FeedPost) {
                return _PostCardWired(post: item);
              }
              return InsightCard(insight: item as FeedInsight);
            },
          ),
        );
      },
    );
  }

  /// Feed kartlarını ve insight'ları sıraya yerleştirir. 2 post + 1 insight
  /// ritmiyle: insight'lar 2 ve 5. indekslerden sonra eklenir.
  List<Object> _interleave(List<FeedPost> posts, List insights) {
    final out = <Object>[];
    for (var i = 0; i < posts.length; i++) {
      out.add(posts[i]);
      if (i == 1 && insights.isNotEmpty) out.add(insights[0]);
      if (i == 4 && insights.length > 1) out.add(insights[1]);
    }
    if (insights.length > 2) out.add(insights[2]);
    return out;
  }
}

class _PostCardWired extends ConsumerWidget {
  const _PostCardWired({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(feedRepositoryProvider);
    return FeedPostCard(
      author: post.author,
      role: post.role,
      timeAgo: _timeAgo(post.createdAt),
      content: post.text,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      tags: post.tags,
      type: post.type,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      groupName: post.groupName,
      onLike: () async {
        // V1.3.2 — Beğeni kullanıcıya bağlı bir favori işlemidir.
        if (!AuthRequiredGuard.canWriteWithRef(ref)) {
          await showAuthRequiredSheet(context, ref);
          return;
        }
        final updated = await repo.toggleLike(post.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.isLiked
                ? AppStrings.feedActionLikedSnack
                : AppStrings.feedActionUnlikedSnack),
            duration: const Duration(milliseconds: 900),
          ),
        );
      },
      onSave: () async {
        // V1.3.2 — "Kaydet" (bookmark) kullanıcıya bağlı bir işlem.
        if (!AuthRequiredGuard.canWriteWithRef(ref)) {
          await showAuthRequiredSheet(context, ref);
          return;
        }
        final updated = await repo.toggleSave(post.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.isSaved
                ? AppStrings.feedActionSavedSnack
                : AppStrings.feedActionUnsavedSnack),
            duration: const Duration(milliseconds: 900),
          ),
        );
      },
      onComment: () {
        // V1 P1-B — Eski snackbar yerine gerçek yorum bottom sheet.
        FeedCommentSheet.show(context, post.id);
      },
      onShare: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.feedActionShareSnack),
            duration: Duration(milliseconds: 900),
          ),
        );
      },
      onTagTap: (tag) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.feedActionTagSnack}$tag'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      },
      onGoToGroup: post.groupId == null
          ? null
          : () => context.push('${AppRoutes.groups}/${post.groupId}'),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'şimdi';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    if (d.inDays < 2) return 'dün';
    return '${d.inDays} gün önce';
  }
}

/// Feed boş veya hata durumu için sade, profesyonel placeholder.
/// Ham exception mesajı gösterilmez; kullanıcıya net bir aksiyon önerisi.
class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(AppSpacing.l),
        border: Border.all(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.s),
            ),
            child: Icon(icon, color: AppColors.softGold, size: 22),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
