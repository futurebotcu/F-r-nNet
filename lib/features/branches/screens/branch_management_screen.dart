import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// Şube Yönetimi — ticari mini app ana ekranı (operasyon merkezi).
///
/// "Bugün Öne Çıkanlar" KPI şeridi + şube kartları + Yeni Şube Oluştur.
/// Şube durumu: pasif saklanır, "Dikkat" açık attention süreçten türetilir.
class BranchManagementScreen extends ConsumerWidget {
  const BranchManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(myBranchesProvider);
    final overview = ref.watch(branchOverviewProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(AppStrings.branchMgmtTitle),
            Text(
              AppStrings.branchMgmtSubtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: branches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: ErrorRetryState(
              title: AppStrings.branchListError,
              onRetry: () => ref.invalidate(myBranchesProvider),
            ),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.m,
              AppSpacing.pageH,
              AppSpacing.xxl,
            ),
            children: [
              _HighlightsCard(overview: overview.valueOrNull),
              const SizedBox(height: AppSpacing.l),
              if (list.isEmpty)
                const _BranchesEmpty()
              else ...[
                for (final b in list) ...[
                  _BranchCard(branch: b),
                  const SizedBox(height: AppSpacing.s),
                ],
              ],
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('branch_create_cta'),
                  onPressed: () => context.push(AppRoutes.branchNew),
                  icon: const Icon(Icons.add_business_rounded, size: 18),
                  label: const Text(AppStrings.branchCreateCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bugün Öne Çıkanlar" — 4 KPI'lı özet kart.
class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({this.overview});

  final BranchOverview? overview;

  @override
  Widget build(BuildContext context) {
    final o = overview ?? const BranchOverview();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: AppSpacing.s),
          child: Text(
            AppStrings.branchMgmtHighlights,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: AppStrings.branchKpiTotalBranches,
                value: '${o.totalBranches}',
                icon: Icons.store_mall_directory_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: StatCard(
                label: AppStrings.branchKpiActiveStaff,
                value: '${o.activeMembers}',
                icon: Icons.groups_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: AppStrings.branchKpiOpenProcesses,
                value: '${o.openProcesses}',
                icon: Icons.pending_actions_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: StatCard(
                label: AppStrings.branchKpiPendingInvites,
                value: '${o.pendingInvites}',
                icon: Icons.mark_email_unread_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.branchDetail(branch.id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandLemonPale,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.brandLemonPressed.withValues(
                        alpha: 0.28,
                      ),
                      width: 0.7,
                    ),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    color: AppColors.brandInk,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        branch.managerName ?? AppStrings.branchDetailNoManager,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(branch: branch),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            // Dar ekran + büyük yazı ölçeğinde sayaçlar taşmasın: Wrap ile
            // gerekirse ikinci satıra iner, chevron sağda sabit kalır.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.m,
                    runSpacing: 4,
                    children: [
                      _MiniStat(
                        icon: Icons.groups_outlined,
                        label: '${branch.memberCount} personel',
                      ),
                      _MiniStat(
                        icon: Icons.pending_actions_outlined,
                        label: '${branch.openProcessCount} açık süreç',
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Durum rozeti: pasif saklanır; "Dikkat" attention süreçten türetilir.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = !branch.isActive
        ? (
            AppStrings.branchStatusPassive,
            AppColors.surfaceVariant,
            AppColors.textMuted,
          )
        : branch.hasAttention
        ? (
            AppStrings.branchStatusAttention,
            const Color(0xFFFFF1F2),
            const Color(0xFFB91C1C),
          )
        : (
            AppStrings.branchStatusActive,
            const Color(0xFFF3FBEF),
            const Color(0xFF166534),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BranchesEmpty extends StatelessWidget {
  const _BranchesEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: const [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.branchListEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
