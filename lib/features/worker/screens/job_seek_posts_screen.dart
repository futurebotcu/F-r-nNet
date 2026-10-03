import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/tr_case.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../listings/widgets/listing_ui.dart';
import '../models/job_seek_post.dart';
import '../providers/worker_providers.dart';

/// İş Arıyorum İlanlarım — bireyselin kendi yayında olan/kapalı ilanları.
class JobSeekPostsScreen extends ConsumerWidget {
  const JobSeekPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myJobSeekPostsProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.finalSeekMyPostsTitle,
          style: AppTypography.sectionTitle,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.jobSeekNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          AppStrings.finalSeekNewPost,
          style: AppTypography.buttonLabel,
        ),
        backgroundColor: AppColors.brandLemon,
        foregroundColor: AppColors.brandInk,
      ),
      body: SafeArea(
        child: async.when(
          // Polish 2 — ilk yüklemede hafif kart iskeleti.
          loading: () => const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: ListingSkeletonList(),
          ),
          // İş İlanları Polish V1 — ham exception gösterme; kaliteli hata
          // durumu + UI-level retry (provider yeniden tetiklenir).
          error: (_, __) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: AppStrings.listingsMyLoadError,
            subtitle: AppStrings.listingsLoadErrorHint,
            actionLabel: AppStrings.retry,
            onAction: () => ref.invalidate(myJobSeekPostsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.l,
                AppSpacing.pageH,
                AppSpacing.xxl + 40,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) => JobSeekPostCard(post: items[i]),
            );
          },
        ),
      ),
    );
  }
}

/// V1.4 P1.24/P1.25 — Widget regresyon testi tarafından doğrudan pump
/// edilebilmesi için library-public (underscore'suz). Sadece bu dosyada
/// construct ediliyor; UI'a yeni surface eklemiyor.
class JobSeekPostCard extends ConsumerWidget {
  const JobSeekPostCard({super.key, required this.post});
  final JobSeekPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('d MMM yyyy', 'tr_TR');
    // Boş parçalar atlanır ("—" / "null" yok).
    final meta = [
      post.professionBadge,
      post.city,
      if (post.experienceYears != null)
        '${post.experienceYears} ${AppStrings.listingsExperienceYearsSuffix}',
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      onTap: () => context.push('${AppRoutes.jobSeek}/${post.id}/edit'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: AppTypography.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _StatusBadge(active: post.isActive),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (post.description != null && post.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              post.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body,
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              if (post.createdAt != null)
                Text(df.format(post.createdAt!), style: AppTypography.caption),
              const Spacer(),
              IconButton(
                tooltip: AppStrings.listingsShareTooltip,
                onPressed: () => Share.share(
                  post.toShareText(),
                  subject: AppStrings.finalSeekShareSubject,
                ),
                icon: const Icon(
                  Icons.share_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: post.isActive
                    ? AppStrings.listingsToggleOffTooltip
                    : AppStrings.listingsToggleOnTooltip,
                onPressed: () => _toggleActive(context, ref),
                icon: Icon(
                  post.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_outlined,
                  color: post.isActive
                      ? AppColors.success
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              IconButton(
                tooltip: AppStrings.listingsDeleteTooltip,
                onPressed: () => _delete(context, ref),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    if (post.id == null) return;
    await runGuardedMutation(
      context,
      ref,
      action: () async {
        // V1.4 P1.24 — upsertJobSeekPost network/Postgrest hatalarını
        // yakalayıp Türkçe snackbar göster. GuestActionRequired ise rethrow
        // et ki runGuardedMutation yakalayıp AuthRequired sheet'i açabilsin.
        try {
          await ref
              .read(workerRepositoryProvider)
              .upsertJobSeekPost(post.copyWith(isActive: !post.isActive));
          if (!context.mounted) return;
          AppFeedback.success(
            context,
            post.isActive
                ? AppStrings.listingsClosedToast
                : AppStrings.listingsRepublishedToast,
          );
        } on GuestActionRequiredException {
          rethrow;
        } catch (_) {
          if (!context.mounted) return;
          AppFeedback.error(context, AppStrings.jobSeekPostToggleError);
        }
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (post.id == null) return;
    final ok = await showAppConfirmDialog(
      context,
      title: AppStrings.listingsDeleteSeekConfirmTitle,
      message: AppStrings.listingsDeleteConfirmBody,
      confirmLabel: AppStrings.listingsDeleteCta,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    if (!context.mounted) return;
    await runGuardedMutation(
      context,
      ref,
      action: () async {
        // V1.4 P1.25 — deleteJobSeekPost network/Postgrest hatalarını
        // yakalayıp Türkçe snackbar göster. GuestActionRequired ise rethrow
        // et ki runGuardedMutation auth sheet'i açabilsin.
        try {
          await ref.read(workerRepositoryProvider).deleteJobSeekPost(post.id!);
          if (!context.mounted) return;
          AppFeedback.success(context, AppStrings.listingsDeleted);
        } on GuestActionRequiredException {
          rethrow;
        } catch (_) {
          if (!context.mounted) return;
          AppFeedback.error(context, AppStrings.jobSeekPostDeleteError);
        }
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Text(
        (active
                ? AppStrings.listingsPublishOpen
                : AppStrings.listingsPublishClosed)
            .trUpper,
        style: AppTypography.badge.copyWith(color: color),
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
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.brandInk,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Text(
                  'Henüz iş arıyorum ilanı yok',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 6),
                const Text(
                  'İlk ilanını yayınla — şehir, vardiya tercihi ve tecrübeni '
                  'yazınca işverenler seni görür.',
                  style: AppTypography.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          AppPrimaryButton(
            label: 'İlk iş ilanını ver',
            icon: Icons.add_rounded,
            onPressed: () => context.push(AppRoutes.jobSeekNew),
          ),
        ],
      ),
    );
  }
}
