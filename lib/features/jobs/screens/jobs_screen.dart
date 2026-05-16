import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/job_opportunity_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../worker/models/job_seek_post.dart';
import '../../worker/providers/worker_providers.dart';

/// V1 İlanlar — gerçek `job_seek_posts` verisine bağlı (P0 mock temizliği).
///
/// "Usta Arıyor" segmenti V1'de tablo yok → coming-soon placeholder.
/// "İş Arıyor" segmenti `activeJobSeekPostsProvider` üzerinden sektörde
/// `is_active = true` ilanları listeler. Misafir read açık; yeni ilan
/// vermek isteyen guest [AuthRequiredSheet]'e düşer.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  int _segmentIndex = 0;

  Future<void> _onAddPressed() async {
    if (AuthRequiredGuard.canWriteWithRef(ref)) {
      context.push(AppRoutes.jobSeekNew);
      return;
    }
    await showAuthRequiredSheet(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            FirinNetHeader(
              title: AppStrings.jobsTitle,
              subtitle: AppStrings.jobsSubtitle,
              actions: [
                HeaderActionButton(
                  icon: Icons.add_rounded,
                  onTap: _onAddPressed,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: _Segment(
                index: _segmentIndex,
                onChange: (i) => setState(() => _segmentIndex = i),
              ),
            ),
            if (_segmentIndex == 0)
              const _HiringComingSoon()
            else
              const _LookingList(),
          ],
        ),
      ),
    );
  }
}

class _LookingList extends ConsumerWidget {
  const _LookingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobSeekPostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: AppStrings.jobsListLooking),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const _JobsMessage(
            icon: Icons.cloud_off_outlined,
            message: AppStrings.jobsErrorGeneric,
          ),
          data: (posts) {
            if (posts.isEmpty) {
              final user = ref.watch(currentAuthUserProvider);
              return _JobsMessage(
                icon: Icons.inbox_outlined,
                message: user == null
                    ? AppStrings.jobsLookingEmptyGuest
                    : AppStrings.jobsLookingEmpty,
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < posts.length; i++) ...[
                    _JobSeekCard(post: posts[i]),
                    if (i != posts.length - 1)
                      const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JobSeekCard extends StatelessWidget {
  const _JobSeekCard({required this.post});
  final JobSeekPost post;

  String _formatSalary() {
    final v = post.salaryExpectation;
    if (v == null || v <= 0) return AppStrings.jobsCardSalaryUnset;
    return 'Beklenti ₺ ${v.toStringAsFixed(0)}';
  }

  String _formatExperience() {
    final y = post.experienceYears;
    if (y == null || y < 0) return AppStrings.jobsCardExperienceUnset;
    if (y == 0) return 'Deneyimsiz olabilir';
    return '$y yıl';
  }

  String _formatBusiness() {
    final badge = post.professionBadge;
    if (badge == null || badge.trim().isEmpty) {
      return AppStrings.jobsCardBusinessFallback;
    }
    return badge.trim();
  }

  String _formatCity() {
    final c = post.city;
    if (c == null || c.trim().isEmpty) return AppStrings.jobsCardCityUnset;
    return c.trim();
  }

  @override
  Widget build(BuildContext context) {
    return JobOpportunityCard(
      position: post.title,
      business: _formatBusiness(),
      city: _formatCity(),
      salary: _formatSalary(),
      experience: _formatExperience(),
      badge: AppStrings.jobsCardBadgeActive,
      shift: null,
    );
  }
}

class _HiringComingSoon extends StatelessWidget {
  const _HiringComingSoon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.elevatedCard,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.copper.withValues(alpha: 0.22),
            width: 0.8,
          ),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: const Icon(
                    Icons.bakery_dining_rounded,
                    color: AppColors.softGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    AppStrings.jobsHiringComingSoonTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              AppStrings.jobsHiringComingSoonBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsMessage extends StatelessWidget {
  const _JobsMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.softGold, size: 20),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        children: [
          _SegmentTab(
            label: AppStrings.jobsSegHiring,
            selected: index == 0,
            onTap: () => onChange(0),
          ),
          _SegmentTab(
            label: AppStrings.jobsSegLooking,
            selected: index == 1,
            onTap: () => onChange(1),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          alignment: Alignment.center,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.elevatedCard : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.s),
            boxShadow: selected ? AppShadow.subtle : null,
            border: selected
                ? Border.all(
                    color: AppColors.copper.withValues(alpha: 0.22),
                    width: 0.8,
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13.5,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
