import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../social/post/social_post_card.dart';
import '../models/academy_bot_profile.dart';
import '../models/academy_recipe.dart';
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
            // Yalnız ana dikey liste: yatay tarif/konu şeritleri sayfalamayı
            // tetiklemez.
            if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
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
                const _RecipesStrip(),
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
                  // Sonraki sayfa hatası sessiz kaybolmaz: satır içi
                  // Tekrar dene (kaydırma otomatik yeniden denemez).
                  if (feed.error && !feed.loading)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Center(
                        child: TextButton.icon(
                          key: const ValueKey('academy_load_more_retry'),
                          onPressed: () => ref
                              .read(academyFeedProvider.notifier)
                              .loadMore(retry: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(AppStrings.academyLoadMoreError),
                        ),
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

/// Yayımlı Akademi tarifleri — yatay kart şeridi; dokununca detay
/// alt-sayfası (malzemeler gramaj+% birlikte, işlem sırası, pişirme).
/// Tarif yoksa bölüm hiç görünmez (feed akışı bozulmaz).
class _RecipesStrip extends ConsumerWidget {
  const _RecipesStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(academyRecipesProvider);
    return recipes.when(
      loading: () => const SizedBox.shrink(),
      // Hata kalıcı boşluk olmasın: kompakt Tekrar dene (provider yeniden
      // istenir). Çekip-yenile de şeridi tazeler.
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('academy_recipes_retry'),
            onPressed: () => ref.invalidate(academyRecipesProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(AppStrings.academyRecipesLoadError),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageH, 0, AppSpacing.pageH, AppSpacing.xs),
              child: Text(
                AppStrings.academyRecipesTitle,
                key: ValueKey('academy_recipes_title'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.s),
                itemBuilder: (context, i) =>
                    _RecipeCard(recipe: list[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
          ],
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final AcademyRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (recipe.ovenC != null) '${recipe.ovenC}°C',
      if (recipe.minutes != null) '${recipe.minutes} dk',
    ].join(' · ');
    return InkWell(
      key: ValueKey('academy_recipe_${recipe.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showRecipeSheet(context, recipe),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.brandLemonPale,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brandLemon, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant_menu_rounded,
                size: 18, color: AppColors.brandInk),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
            if (meta.isNotEmpty)
              Text(
                meta,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            Text(
              recipe.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showRecipeSheet(BuildContext context, AcademyRecipe recipe) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, 0, AppSpacing.pageH, AppSpacing.xxl),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const AcademyAiBadge(label: AppStrings.academyRecipeBadge),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              recipe.authorName,
              if (recipe.ovenC != null) '${recipe.ovenC}°C',
              if (recipe.minutes != null) '${recipe.minutes} dk',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          const Text(
            AppStrings.academyRecipeIngredients,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                ing.display,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.academyRecipeSteps,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              recipe.steps,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
          if (recipe.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              recipe.notes,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    ),
  );
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
