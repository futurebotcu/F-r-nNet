// FırınNet V1 Unified Profile M2 — tek public profile sayfası.
//
// V1.2 öncesi: SocialProfilePage donor-first sosyal profil (header +
// statistics + posts). Unified Profile M2 ile aşağıdaki section'lar
// eklendi:
//   * AccountType rozet (Ticari/Bireysel/Toptancı) — publicProfileDetail
//   * Hakkında / İşletme — bakery (commercial)
//   * Mesleki Profil ve Deneyim — worker_profiles + worker_experiences
//   * Açık Reçeteler — recipe_calculations is_public=true (ProfileScreen
//     legacy section taşındı)
//   * Gönderiler — mevcut SocialPostCard listesi korundu
//
// Profession_badge sırası (V1): worker_profiles.profession_badge varsa
// onu kullan; yoksa profiles.profession_badge fallback.
//
// Self görüntülemede header altında "Profili düzenle" CTA görünür;
// non-self'te FollowButton + Mesaj CTA (M1.2 messaging).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../bakery_panel/models/recipe_record.dart';
import '../../bakery_panel/providers/bakery_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../profile/models/public_profile_detail.dart';
import '../../profile/providers/follow_providers.dart';
import '../../profile/providers/public_profile_detail_provider.dart';
import '../../profile/widgets/follow_button.dart';
import '../../profile/widgets/profile_edit_sheet.dart';
import '../post/social_post_card.dart';
import '../providers/social_providers.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_statistics.dart';

class SocialProfilePage extends ConsumerWidget {
  const SocialProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(socialProfileProvider(userId));
    final detailAsync = ref.watch(publicProfileDetailProvider(userId));
    // M4 Polish — profile postları paged. Yüksek-post kullanıcıda ilk
    // açılış 20'lik sayfa; "Daha fazla göster" CTA ile loadMore.
    final pagedAsync = ref.watch(userPostsPagedNotifierProvider(userId));
    final countsAsync = ref.watch(followCountsProvider(userId));
    final postCountAsync = ref.watch(socialProfilePostCountProvider(userId));
    final recipesAsync = ref.watch(publicRecipesByOwnerProvider(userId));
    final me = ref.watch(currentAuthUserProvider);
    final isSelf = me != null && me.id == userId;

    return PremiumScaffold(
      appBar: AppBar(
        title: profileAsync.maybeWhen(
          data: (p) => Text(p.displayNameOrFallback),
          orElse: () => const Text(AppStrings.publicProfileTitle),
        ),
        actions: [
          if (isSelf)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: AppStrings.settingsTooltip,
              onPressed: () => context.push(AppRoutes.settings),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialProfileProvider(userId));
            ref.invalidate(publicProfileDetailProvider(userId));
            ref.invalidate(userPostsProvider(userId));
            ref.invalidate(userPostsPagedNotifierProvider(userId));
            ref.invalidate(followCountsProvider(userId));
            ref.invalidate(socialProfilePostCountProvider(userId));
            ref.invalidate(publicRecipesByOwnerProvider(userId));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              // Header (avatar + name + effective profession_badge + city).
              // detailAsync sayesinde avatar_url ve worker fallback'li badge
              // header'a tek kaynaktan akar — `effectiveProfessionBadge`.
              ProfileHeader(
                profileAsync: profileAsync,
                detailAsync: detailAsync,
                isSelf: isSelf,
              ),

              // Account type rozet (Ticari/Bireysel/Toptancı)
              _AccountTypeBadge(detailAsync: detailAsync),

              const SizedBox(height: AppSpacing.s),
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

              // CTA: non-self → Follow + Mesaj; self → Düzenle
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.m,
                  AppSpacing.pageH,
                  0,
                ),
                child: isSelf
                    ? _SelfEditCta(
                        onTap: () => ProfileEditSheet.show(context),
                      )
                    : Row(
                        children: [
                          Expanded(child: FollowButton(userId: userId)),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: _ProfileMessageCta(
                              onTap: () =>
                                  _openProfileChat(context, ref, userId),
                            ),
                          ),
                        ],
                      ),
              ),

              // ── Hakkında / İşletme ──
              _AboutBakerySection(
                detailAsync: detailAsync,
                isSelf: isSelf,
              ),

              // ── Mesleki Profil ve Deneyim ──
              _ProfessionalSection(
                detailAsync: detailAsync,
                isSelf: isSelf,
                onEdit: () => context.push(AppRoutes.workerProfile),
              ),

              // ── Açık Reçeteler ──
              _PublicRecipesSection(
                async: recipesAsync,
                isSelf: isSelf,
              ),

              const SizedBox(height: AppSpacing.m),
              const Divider(
                height: 0,
                thickness: 0.6,
                color: AppColors.borderHairline,
              ),

              // ── Gönderiler ──
              _SectionHeader(label: AppStrings.profileSectionPosts),
              pagedAsync.when(
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
                data: (paged) {
                  if (paged.posts.isEmpty) {
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
                  return Column(
                    children: [
                      for (final p in paged.posts)
                        SocialPostCard(key: ValueKey(p.id), post: p),
                      if (paged.hasMore)
                        _LoadMoreCta(
                          isLoading: paged.isLoadingMore,
                          onTap: () => ref
                              .read(userPostsPagedNotifierProvider(userId)
                                  .notifier)
                              .loadMore(),
                        ),
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

  Future<void> _openProfileChat(
    BuildContext context,
    WidgetRef ref,
    String otherUserId,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    try {
      final convId = await ref
          .read(messagingRepositoryProvider)
          .findOrCreateDirectConversation(
            otherUserId: otherUserId,
            contextType: 'profile_direct',
          );
      if (!context.mounted) return;
      context.push('/messages/$convId');
    } on GuestActionRequiredException {
      if (context.mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][Profile] open chat error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.messagingStartError)),
        );
      }
    }
  }
}

// ── CTA widgets ───────────────────────────────────────────────────

class _SelfEditCta extends StatelessWidget {
  const _SelfEditCta({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          AppStrings.profileEditCta,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.borderHairline,
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}

class _ProfileMessageCta extends StatelessWidget {
  const _ProfileMessageCta({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text(
          AppStrings.messagingMessageCtaProfile,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.borderHairline,
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeBadge extends StatelessWidget {
  const _AccountTypeBadge({required this.detailAsync});
  final AsyncValue<PublicProfileDetail?> detailAsync;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        final code = d?.header.accountType;
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        final label =
            AppStrings.profileAccountTypeLabels[code] ?? code;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.softGold.withValues(alpha: 0.36),
                  width: 0.6,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Section header ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Hakkında / İşletme ────────────────────────────────────────────

class _AboutBakerySection extends StatelessWidget {
  const _AboutBakerySection({
    required this.detailAsync,
    required this.isSelf,
  });
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final bool isSelf;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        final bakery = d.bakery;
        final hasContent = bakery != null && !bakery.isEmpty;
        if (!hasContent && !isSelf) {
          // Başkası bakıyor ve boş ise gizle.
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(label: AppStrings.profileSectionBakery),
            if (!hasContent)
              const _SectionEmptyHint(
                message: AppStrings.profileEmptyBakery,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bakery!.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                      if ((bakery.city ?? '').isNotEmpty ||
                          (bakery.district ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                [
                                  if ((bakery.city ?? '').isNotEmpty)
                                    bakery.city,
                                  if ((bakery.district ?? '').isNotEmpty)
                                    bakery.district,
                                ].whereType<String>().join(' · '),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((bakery.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          bakery.description!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── Mesleki Profil ve Deneyim ──────────────────────────────────────

class _ProfessionalSection extends StatelessWidget {
  const _ProfessionalSection({
    required this.detailAsync,
    required this.isSelf,
    required this.onEdit,
  });
  final AsyncValue<PublicProfileDetail?> detailAsync;
  final bool isSelf;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return detailAsync.maybeWhen(
      data: (d) {
        if (d == null) return const SizedBox.shrink();
        final w = d.worker;
        final hasContent = d.hasWorkerInfo;
        if (!hasContent && !isSelf) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              label: AppStrings.profileSectionProfessional,
              trailing: isSelf
                  ? TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text(
                        'Düzenle',
                        style: TextStyle(
                          color: AppColors.softGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.softGold,
                        minimumSize: const Size(0, 32),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
            if (!hasContent)
              const _SectionEmptyHint(
                message: AppStrings.profileEmptyProfessional,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                  vertical: AppSpacing.s,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (w != null && (w.bio ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.s),
                          child: Text(
                            w.bio!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      // Uzmanlık özeti — tek alan: yıl + skills + cities + shift.
                      // Profile Social Sprint: ayrı "Deneyimler" timeline'ı
                      // kaldırıldı; tek sade card profili Twitter/Facebook
                      // hissinde tutar.
                      if (w != null) _WorkerSnapshot(worker: w),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _WorkerSnapshot extends StatelessWidget {
  const _WorkerSnapshot({required this.worker});
  final PublicWorkerInfo worker;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (worker.experienceYears != null) {
      chips.add(_MiniChip(
        label:
            '${worker.experienceYears} ${AppStrings.profileExperienceYearsLabel}',
      ));
    }
    if ((worker.shiftPreference ?? '').isNotEmpty) {
      chips.add(_MiniChip(label: worker.shiftPreference!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        if (worker.skills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.profileWorkerSkillsLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in worker.skills) _MiniChip(label: s),
            ],
          ),
        ],
        if (worker.cities.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            AppStrings.profileWorkerCitiesLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in worker.cities) _MiniChip(label: c),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Açık Reçeteler ────────────────────────────────────────────────

/// Profile Social Sprint — public reçeteler küçük preview (max 4).
/// Feed'in görsel ağırlığını ezmemek için kısa liste, tap → RecipeDetail.
/// 4'ten fazla varsa alta küçük "+N daha" pasif satırı.
class _PublicRecipesSection extends StatelessWidget {
  const _PublicRecipesSection({
    required this.async,
    required this.isSelf,
  });
  final AsyncValue<List<Recipe>> async;
  final bool isSelf;

  static const int _previewLimit = 4;

  @override
  Widget build(BuildContext context) {
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty && !isSelf) return const SizedBox.shrink();
        final preview = list.take(_previewLimit).toList(growable: false);
        final overflow = list.length - preview.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              label: AppStrings.profileSectionPublicRecipes,
            ),
            if (list.isEmpty)
              const _SectionEmptyHint(
                message: AppStrings.profileEmptyRecipes,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: Column(
                  children: [
                    for (final r in preview)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.s,
                        ),
                        child: _PublicRecipeRow(recipe: r),
                      ),
                    if (overflow > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                          bottom: AppSpacing.s,
                        ),
                        child: Text(
                          '+$overflow ${AppStrings.profileRecipesMoreSuffix}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PublicRecipeRow extends StatelessWidget {
  const _PublicRecipeRow({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.m);
    return Material(
      color: AppColors.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push('${AppRoutes.recipes}/${recipe.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppColors.borderHairline,
              width: 0.6,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: AppColors.softGold,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  recipe.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yardımcılar ───────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.s,
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// M4 Polish — profile posts paged "Daha fazla göster" CTA.
class _LoadMoreCta extends StatelessWidget {
  const _LoadMoreCta({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: isLoading ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(
              color: AppColors.borderHairline,
              width: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              : const Text(
                  AppStrings.profilePostsLoadMore,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
        ),
      ),
    );
  }
}
