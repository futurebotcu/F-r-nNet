import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/recipe_record.dart';
import '../providers/bakery_providers.dart';
import 'recipe_visibility_badge.dart';

/// Reçetelerim ekranı.
///
/// - Kullanıcının kendi kayıtlı reçetelerini gösterir (RLS owner-only).
/// - Kart üzerinden Detay ve hızlı Paylaş aksiyonları.
/// - Empty state: "Henüz reçete kaydı yok" + "İlk reçeteni ekle".
class RecipesListScreen extends ConsumerWidget {
  const RecipesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipesListProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Reçetelerim'),
        actions: [
          IconButton(
            tooltip: 'Yeni reçete',
            onPressed: () => context.push(AppRoutes.recipeNew),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          // Perf: reçete kaydedilince liste eski içeriğini korur, spinner
          // flash yok; spinner yalnız ilk yüklemede.
          skipLoadingOnReload: true,
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          error: (e, _) => _ErrorBox(message: '$e'),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(recipesListProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.l,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.s),
                itemBuilder: (_, i) => _RecipeCard(recipe: items[i]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.recipeNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni reçete'),
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.surface,
      ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('d MMM yyyy', 'tr_TR');
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      onTap: () => context.push('${AppRoutes.recipes}/${recipe.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  border: Border.all(
                    color: AppColors.copper.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.softGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.displayTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.displaySubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        recipe.displaySubtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    df.format(recipe.createdAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  VisibilityBadge(visibility: recipe.visibility),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniChip(
                icon: Icons.grass_outlined,
                label:
                    'Un ${NumberFormatter.decimal(recipe.quantities.flourKg)} kg',
              ),
              _MiniChip(
                icon: Icons.scale_outlined,
                label:
                    'Gramaj ${NumberFormatter.decimal(recipe.quantities.pieceWeightG)} gr',
              ),
              _MiniChip(
                icon: Icons.bakery_dining_outlined,
                label:
                    '${NumberFormatter.integer(recipe.result.estimatedPieces)} adet',
                accent: AppColors.softGold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('${AppRoutes.recipes}/${recipe.id}'),
                  icon: const Icon(Icons.read_more_rounded, size: 16),
                  label: const Text('Detay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.softGold,
                    side: BorderSide(
                      color: AppColors.copper.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(context, ref),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Paylaş'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final builder = ref.read(recipeShareTextBuilderProvider);
    final text = builder.build(recipe);
    await Share.share(text, subject: 'FırınNet — Reçete');
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, this.accent});
  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        // Faz 2 Pass 4 — metin çipi için pill (999) fazla yuvarlaktı; soft m.
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xl,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.softGold,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Text(
                  'Henüz reçete kaydı yok',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ürün, malzeme ve yapılış bilgisini birlikte kaydet; '
                  'gerektiğinde hesaplı şekilde tek dokunuşla paylaş.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          AppPrimaryButton(
            label: 'İlk reçeteni ekle',
            icon: Icons.add_rounded,
            onPressed: () => context.push(AppRoutes.recipeNew),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Text(
        'Reçeteler okunamadı: $message',
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}
