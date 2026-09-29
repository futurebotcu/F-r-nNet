import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../social/post/social_post_card.dart';
import '../models/academy_bot_profile.dart';
import '../providers/academy_providers.dart';

/// FırınNet Akademi — tüm Akademi botlarının içeriklerini tek "profil
/// benzeri" sayfada gösterir: avatar/bio + AI rozeti + konu (bot) filtreleri
/// + sayfalı liste. Mizah botu bu sayfada listelenmez (kendi profili var).
class AcademyPage extends ConsumerWidget {
  const AcademyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bots = ref.watch(academyBotsProvider);
    final feed = ref.watch(academyFeedProvider);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              ref.read(academyFeedProvider.notifier).loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(academyFeedProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                const FirinNetHeader(title: AppStrings.academyTitle),
                const _AcademyHero(),
                bots.when(
                  data: (list) => _BotFilterChips(
                    bots: list
                        .where((b) => !b.isHumor)
                        .toList(growable: false),
                    selected: feed.filterBotId,
                    onSelect: (id) => ref
                        .read(academyFeedProvider.notifier)
                        .refresh(filterBotId: id, clearFilter: id == null),
                  ),
                  loading: () => const SizedBox(height: 44),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.s),
                if (feed.error && feed.posts.isEmpty)
                  _RetryState(
                    onRetry: () =>
                        ref.read(academyFeedProvider.notifier).refresh(),
                  )
                else if (!feed.loading && feed.posts.isEmpty)
                  const _EmptyState()
                else ...[
                  for (final p in feed.posts)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH, 0, AppSpacing.pageH, AppSpacing.m),
                      child: SocialPostCard(
                        key: ValueKey('academy_post_${p.feedEntryKey}'),
                        post: p,
                      ),
                    ),
                  if (feed.loading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.l),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademyHero extends StatelessWidget {
  const _AcademyHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandLemonPale,
              border: Border.all(color: AppColors.brandLemon, width: 1.2),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.brandInk,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        AppStrings.academyTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const AcademyAiBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  AppStrings.academyBio,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI/Akademi rozeti — bot içeriği ayırt edilebilir olsun (feed + profil).
class AcademyAiBadge extends StatelessWidget {
  const AcademyAiBadge({super.key, this.label = AppStrings.academyAiBadge});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('academy_ai_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.brandLemon, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.brandInk,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BotFilterChips extends StatelessWidget {
  const _BotFilterChips({
    required this.bots,
    required this.selected,
    required this.onSelect,
  });

  final List<AcademyBotProfile> bots;
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          _chip(AppStrings.academyFilterAll, selected == null,
              () => onSelect(null)),
          for (final b in bots)
            _chip(b.topic.label, selected == b.profileId,
                () => onSelect(b.profileId)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: ChoiceChip(
        key: ValueKey('academy_chip_$label'),
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.brandInk : AppColors.textSecondary,
        ),
        selectedColor: AppColors.brandLemonPale,
        side: BorderSide(
          color: active ? AppColors.brandLemon : AppColors.borderHairline,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: const [
          Icon(Icons.menu_book_outlined,
              size: 40, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.academyEmpty,
            key: ValueKey('academy_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Text(
            AppStrings.academyLoadError,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          OutlinedButton(
            key: const ValueKey('academy_retry'),
            onPressed: onRetry,
            child: const Text(AppStrings.academyRetryCta),
          ),
        ],
      ),
    );
  }
}
