import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/job_seek_post.dart';
import '../providers/worker_providers.dart';

/// İş Arıyorum İlanlarım — bireyselin kendi yayında olan/kapalı ilanları.
class JobSeekPostsScreen extends ConsumerWidget {
  const JobSeekPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myJobSeekPostsProvider);

    return PremiumScaffold(
      appBar: AppBar(title: const Text('İş Arıyorum İlanlarım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.jobSeekNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni ilan'),
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.brandInk,
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
          // İş İlanları Polish V1 — ham exception gösterme; kaliteli hata
          // durumu + UI-level retry (provider yeniden tetiklenir).
          error: (_, __) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'İlanların yüklenemedi',
            subtitle: 'Bağlantını kontrol edip tekrar dener misin?',
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(active: post.isActive),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (post.professionBadge != null) post.professionBadge!,
              if (post.city != null) post.city!,
              if (post.experienceYears != null)
                '${post.experienceYears} yıl tecrübe',
            ].whereType<String>().join(' · '),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          if (post.description != null && post.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              post.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Text(
                post.createdAt != null ? df.format(post.createdAt!) : '—',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Paylaş',
                onPressed: () =>
                    Share.share(post.toShareText(), subject: 'FırınNet — İş'),
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.softGold,
                  size: 18,
                ),
              ),
              IconButton(
                tooltip: post.isActive ? 'Yayını kapat' : 'Yayına aç',
                onPressed: () => _toggleActive(context, ref),
                icon: Icon(
                  post.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_outlined,
                  color: post.isActive
                      ? AppColors.success
                      : AppColors.textMuted,
                  size: 22,
                ),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: () => _delete(context, ref),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                  size: 18,
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
        } on GuestActionRequiredException {
          rethrow;
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.jobSeekPostToggleError)),
          );
        }
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (post.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı sil'),
        content: const Text(
          'Bu ilan kalıcı olarak silinecek. Devam edilsin mi?',
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
    await runGuardedMutation(
      context,
      ref,
      action: () async {
        // V1.4 P1.25 — deleteJobSeekPost network/Postgrest hatalarını
        // yakalayıp Türkçe snackbar göster. GuestActionRequired ise rethrow
        // et ki runGuardedMutation auth sheet'i açabilsin.
        try {
          await ref.read(workerRepositoryProvider).deleteJobSeekPost(post.id!);
        } on GuestActionRequiredException {
          rethrow;
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.jobSeekPostDeleteError)),
          );
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
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Text(
        active ? 'YAYINDA' : 'KAPALI',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.9,
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
                    color: AppColors.softGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.softGold,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                const Text(
                  'Henüz iş arıyorum ilanı yok',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'İlk ilanını yayınla — şehir, vardiya tercihi ve tecrübeni '
                  'yazınca işverenler seni görür.',
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
            label: 'İlk iş ilanını ver',
            icon: Icons.add_rounded,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.jobSeekNew),
          ),
        ],
      ),
    );
  }
}
