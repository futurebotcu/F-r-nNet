import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/post_type.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/recipe_metadata.dart';
import '../models/recipe_record.dart';
import '../providers/bakery_providers.dart';
import 'recipe_visibility_badge.dart';

/// Tek bir reçetenin detay ekranı.
///
/// - Ürün adı + başlık
/// - Hesap sonuçları (6 kart, mevcut RecipeCalculator çıktısıyla aynı)
/// - Malzemeler ve adımlar listesi
/// - Pişirme/mayalanma bilgisi
/// - Notlar
/// - Foto placeholder (V1; gerçek upload sonraki faz)
/// - "Paylaş" butonu → bottom sheet (Feed / Grup / WhatsApp)
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // List provider'ı dinleyerek silmelerde geri dönüş.
    final async = ref.watch(recipesListProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Reçete'),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('${AppRoutes.recipes}/$recipeId/edit'),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          // Perf: reçete düzenlenince detay eski içeriğini korur, spinner
          // flash yok.
          skipLoadingOnReload: true,
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          error: (e, _) => ErrorRetryState(
            title: 'Reçete açılamadı',
            onRetry: () => ref.invalidate(recipesListProvider),
          ),
          data: (items) {
            final recipe = items.where((r) => r.id == recipeId).firstOrNull;
            if (recipe == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    'Reçete bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return _Body(recipe: recipe);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reçeteyi sil'),
        content: const Text(
          'Bu reçete kalıcı olarak silinecek. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    // V1.3.2 — Sil owner-only kalıcı işlem; guest engellenir.
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(recipeRepositoryProvider);
    await repo.delete(recipeId);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reçete silindi.')));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('d MMMM yyyy', 'tr_TR');
    final meta = recipe.metadata;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        0,
        AppSpacing.pageH,
        AppSpacing.xxl + 40,
      ),
      children: [
        _Header(recipe: recipe, df: df),
        const SizedBox(height: AppSpacing.l),
        const _SectionTitle('Hesap sonucu'),
        const SizedBox(height: AppSpacing.s),
        _ResultGrid(recipe: recipe),
        if (meta.description?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionTitle('Açıklama'),
          const SizedBox(height: AppSpacing.s),
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(
              meta.description!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
        if (meta.ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionTitle('Malzemeler'),
          const SizedBox(height: AppSpacing.s),
          _IngredientList(items: meta.ingredients),
        ],
        if (meta.steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionTitle('Yapılışı'),
          const SizedBox(height: AppSpacing.s),
          _StepList(items: meta.steps),
        ],
        if (!meta.bake.isEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionTitle('Pişirme & mayalanma'),
          const SizedBox(height: AppSpacing.s),
          _BakeInfoCard(bake: meta.bake),
        ],
        if (meta.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionTitle('Not'),
          const SizedBox(height: AppSpacing.s),
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            warm: true,
            child: Text(
              meta.notes!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.l),
        const _SectionTitle('Görsel / Video'),
        const SizedBox(height: AppSpacing.s),
        const _MediaPlaceholder(),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: () => _openShareSheet(context, ref, recipe),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Reçeteyi Paylaş'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.brandInk,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openShareSheet(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final builder = ref.read(recipeShareTextBuilderProvider);
    final text = builder.build(recipe);

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) {
        return _ShareSheet(text: text, recipeTitle: recipe.displayTitle);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.recipe, required this.df});
  final Recipe recipe;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recipe.productName.isNotEmpty)
                      Text(
                        recipe.productName.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      recipe.displayTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Text(
                'Oluşturulma · ${df.format(recipe.createdAt)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              VisibilityBadge(visibility: recipe.visibility),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: AppSpacing.s),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final r = recipe.result;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.water_drop_outlined,
                label: 'Su',
                value: '${NumberFormatter.decimal(r.waterLiters)} L',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.science_outlined,
                label: 'Maya',
                value: '${NumberFormatter.decimal(r.yeastKg)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.grain_outlined,
                label: 'Tuz',
                value: '${NumberFormatter.decimal(r.saltKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                icon: Icons.scale_outlined,
                label: 'Toplam hamur',
                value: '${NumberFormatter.decimal(r.totalDoughKg)} kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.cleaning_services_outlined,
                label: 'Fire sonrası',
                value: '${NumberFormatter.decimal(r.doughAfterWasteKg)} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: StatCard(
                warm: true,
                icon: Icons.bakery_dining_outlined,
                label: 'Tahmini adet',
                value: NumberFormatter.integer(r.estimatedPieces),
                accent: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.items});
  final List<RecipeIngredient> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                color: AppColors.borderHairline,
                indent: AppSpacing.l,
                endIndent: AppSpacing.l,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: const Icon(
                      Icons.circle,
                      color: AppColors.primary,
                      size: 8,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          items[i].name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        if ((items[i].note?.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              items[i].note!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${NumberFormatter.decimal(items[i].amount)} ${items[i].unit}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.items});
  final List<RecipeStep> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                color: AppColors.borderHairline,
                indent: AppSpacing.l,
                endIndent: AppSpacing.l,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Text(
                      '${sorted[i].order}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sorted[i].text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                        if (sorted[i].durationMin != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${sorted[i].durationMin} dk',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BakeInfoCard extends StatelessWidget {
  const _BakeInfoCard({required this.bake});
  final RecipeBakeInfo bake;

  @override
  Widget build(BuildContext context) {
    final items = <_BakeMetric>[];
    if (bake.tempC != null) {
      items.add(
        _BakeMetric(
          icon: Icons.thermostat_rounded,
          label: 'Pişirme derecesi',
          value: '${NumberFormatter.decimal(bake.tempC!)}°C',
        ),
      );
    }
    if (bake.durationMin != null) {
      items.add(
        _BakeMetric(
          icon: Icons.timer_outlined,
          label: 'Pişirme süresi',
          value: '${bake.durationMin} dk',
        ),
      );
    }
    if (bake.proofMin != null) {
      items.add(
        _BakeMetric(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Mayalanma',
          value: '${bake.proofMin} dk',
        ),
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final m in items) m],
      ),
    );
  }
}

class _BakeMetric extends StatelessWidget {
  const _BakeMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          const Expanded(
            child: Text(
              'Foto ve video yükleme sonraki fazda aktif olacak. '
              'Bu reçete metin tabanlı paylaşılabilir.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends ConsumerWidget {
  const _ShareSheet({required this.text, required this.recipeTitle});
  final String text;
  final String recipeTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Paylaş — $recipeTitle',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reçete sadece sende kayıtlı. Paylaşmak gizliliğini değiştirmez; '
              'sadece bu içeriği oluşturur.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            _ShareOption(
              icon: Icons.public_outlined,
              title: "Feed'de paylaş",
              subtitle: 'FırınNet akışında bir gönderi oluşturulur',
              onTap: () => _shareToFeed(context, ref),
            ),
            const SizedBox(height: AppSpacing.s),
            _ShareOption(
              icon: Icons.groups_outlined,
              title: 'Grupta paylaş',
              subtitle: 'Sonraki fazda — grup seçimi açılacak',
              comingSoon: true,
              onTap: () => _comingSoon(context, 'Grupta paylaşım'),
            ),
            const SizedBox(height: AppSpacing.s),
            _ShareOption(
              icon: Icons.ios_share_rounded,
              title: 'WhatsApp / Sistem paylaşımı',
              subtitle: 'WhatsApp, mesaj, kopyala — sistem menüsü',
              onTap: () => _shareSystem(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToFeed(BuildContext context, WidgetRef ref) async {
    // V1.3.2 — Feed'e paylaşmak app içinde post oluşturur; üyelik gerektirir.
    // (Dış sistem paylaşımı — Share.share — guardsız kalmaya devam eder.)
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      Navigator.of(context).pop();
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(feedRepositoryProvider);
    final profile = ref.read(profileControllerProvider);
    final author = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName
        : 'Sen';
    final role = (profile?.roleBadge.isNotEmpty ?? false)
        ? profile!.roleBadge
        : 'FırınNet';
    try {
      await repo.addPost(
        type: PostType.production,
        author: author,
        role: role,
        text: text,
        tags: const <String>['reçete'],
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reçete akışa eklendi.')));
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım başarısız. Lütfen tekrar dene.'),
          ),
        );
      }
    }
  }

  void _comingSoon(BuildContext context, String feature) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature sonraki fazda aktif olacak.')),
    );
  }

  Future<void> _shareSystem(BuildContext context) async {
    Navigator.of(context).pop();
    await Share.share(text, subject: 'FırınNet — Reçete');
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: const Text(
                              'YAKINDA',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
