import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../social/post/social_post_card.dart';
import '../../social/widgets/social_skeletons.dart';
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
            onRefresh: () => ref.read(academyFeedProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                const FirinNetHeader(title: AppStrings.academyTitle),
                const _AcademyHero(),
                const _RecipesStrip(),
                bots.when(
                  data: (list) => _BotFilterChips(
                    bots: list.where((b) => !b.isHumor).toList(growable: false),
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
                else if (feed.loading && feed.posts.isEmpty)
                  // İlk yükleme: tek başına küçük çark yerine gönderi
                  // kartı iskeleti (sonraki sayfa satır-içi küçük gösterge).
                  const Column(
                    key: ValueKey('academy_skeleton'),
                    children: [
                      FeedSkeletonCard(),
                      FeedSkeletonCard(withMedia: true),
                    ],
                  )
                else if (!feed.loading && feed.posts.isEmpty)
                  const _EmptyState()
                else ...[
                  // Kart kendi yatay marjını (pageH) taşır; ekstra padding
                  // kartı akıştakinden dar gösteriyordu.
                  for (final p in feed.posts)
                    SocialPostCard(
                      key: ValueKey('academy_post_${p.feedEntryKey}'),
                      post: p,
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
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.m,
      ),
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
          // Başlık zaten üst header'da: burada tekrar edilmez, yalnız AI
          // rozeti + kısa tanıtım.
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AcademyAiBadge(),
                SizedBox(height: 6),
                Text(AppStrings.academyBio, style: AppTypography.body),
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
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.brandLemon, width: 1),
      ),
      // Ortak rozet rolü (mürekkep metin; limon yalnız zemin/kenar).
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.badge.copyWith(letterSpacing: 0.2),
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
          _chip(
            AppStrings.academyFilterAll,
            selected == null,
            () => onSelect(null),
          ),
          for (final b in bots)
            _chip(
              b.topic.label,
              selected == b.profileId,
              () => onSelect(b.profileId),
            ),
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
        labelStyle: AppTypography.chipLabel.copyWith(
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
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.xs,
              ),
              child: Text(
                AppStrings.academyRecipesTitle,
                key: ValueKey('academy_recipes_title'),
                style: AppTypography.sectionTitle,
              ),
            ),
            SizedBox(
              // Sabit 118px büyük yazıda taşıyordu: yükseklik metin
              // ölçeğiyle (font boyutu bazında — Android 14 non-linear)
              // hesaplanır.
              height: _RecipeCard.heightFor(MediaQuery.textScalerOf(context)),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.s),
                itemBuilder: (context, i) => _RecipeCard(recipe: list[i]),
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

  /// Kart yüksekliği: padding + ikon + 2 satır başlık + meta + yazar.
  static double heightFor(TextScaler scaler) {
    final text =
        scaler.scale(13.5) * 1.25 * 2 +
        scaler.scale(11.5) * 1.3 +
        scaler.scale(11) * 1.3;
    return (AppSpacing.m * 2 + 18 + 6 + text + 8).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (recipe.ovenC != null) '${recipe.ovenC}°C',
      if (recipe.minutes != null) '${recipe.minutes} dk',
    ].join(' · ');
    return InkWell(
      key: ValueKey('academy_recipe_${recipe.id}'),
      borderRadius: BorderRadius.circular(AppRadius.m),
      onTap: () => _showRecipeSheet(context, recipe),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.brandLemonPale,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.brandLemon, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 18,
              color: AppColors.brandInk,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // Kart başlığı rolü; şerit yüksekliği (heightFor) 13.5/1.25
                // ölçüsüyle hesaplanır.
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 13.5,
                  height: 1.25,
                ),
              ),
            ),
            if (meta.isNotEmpty)
              Text(
                meta,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            Text(
              recipe.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
          AppSpacing.pageH,
          0,
          AppSpacing.pageH,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(recipe.title, style: AppTypography.detailTitle),
              ),
              const AcademyAiBadge(label: AppStrings.academyRecipeBadge),
              IconButton(
                key: const ValueKey('academy_recipe_close'),
                tooltip: AppStrings.closeTooltip,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              recipe.authorName,
              if (recipe.ovenC != null) '${recipe.ovenC}°C',
              if (recipe.minutes != null) '${recipe.minutes} dk',
            ].join(' · '),
            style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.m),
          const Text(
            AppStrings.academyRecipeIngredients,
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                ing.display,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.academyRecipeSteps,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              recipe.steps,
              style: AppTypography.bodyMedium.copyWith(height: 1.55),
            ),
          ],
          if (recipe.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(recipe.notes, style: AppTypography.body),
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
    // Uygulama geneli boş durum dili (mini-app hissi yok).
    return const EmptyState(
      key: ValueKey('academy_empty'),
      compact: true,
      icon: Icons.menu_book_outlined,
      title: AppStrings.academyEmptyTitle,
      subtitle: AppStrings.academyEmpty,
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Uygulama geneli hata dili: ErrorRetryState görünümü (ikon kutusu +
    // başlık + açıklama) ve aynı biçimde birincil "Tekrar dene" butonu.
    return Column(
      children: [
        const ErrorRetryState(
          compact: true,
          title: AppStrings.academyLoadErrorTitle,
          subtitle: AppStrings.academyLoadError,
        ),
        FilledButton.icon(
          key: const ValueKey('academy_retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(AppStrings.academyRetryCta),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.copper,
            foregroundColor: AppColors.brandInk,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            textStyle: AppTypography.buttonLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}
