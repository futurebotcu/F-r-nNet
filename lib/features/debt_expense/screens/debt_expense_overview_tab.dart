// Borç & Gider — Genel Bakış: özet metrikler + sakin gecikme uyarısı +
// hızlı aksiyonlar + son hareketler.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../models/debt_expense_entry.dart';
import '../providers/debt_expense_providers.dart';
import '../widgets/debt_expense_widgets.dart';
import 'debt_expense_entry_form_screen.dart';

class DebtExpenseOverviewTab extends ConsumerWidget {
  const DebtExpenseOverviewTab({super.key});

  void _openForm(BuildContext context, DebtExpenseKind kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DebtExpenseEntryFormScreen(kind: kind),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(debtExpenseSummaryProvider);
    final recentAsync = ref.watch(debtExpenseEntriesProvider(null));
    final today = DateTime.now();

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FirinNetHeader(
              title: AppStrings.debtExpenseTitle,
              subtitle: AppStrings.debtExpenseCardSub,
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  // Özet metrikler.
                  summaryAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => ErrorRetryState(
                      compact: true,
                      title: 'Özet yüklenemedi',
                      subtitle: 'Borç/gider özeti alınamadı. Tekrar deneyin.',
                      onRetry: () => ref.invalidate(debtExpenseSummaryProvider),
                    ),
                    data: (s) => _SummaryBlock(summary: s),
                  ),
                  const SectionLabel(title: 'Hızlı işlem'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageH),
                    child: Row(
                      children: [
                        _QuickAction(
                          icon: Icons.account_balance_wallet_rounded,
                          label: AppStrings.deAddDebt,
                          onTap: () => _openForm(context, DebtExpenseKind.debt),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        _QuickAction(
                          icon: Icons.receipt_long_rounded,
                          label: AppStrings.deAddExpense,
                          onTap: () =>
                              _openForm(context, DebtExpenseKind.expense),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        _QuickAction(
                          icon: Icons.badge_rounded,
                          label: AppStrings.deAddStaff,
                          onTap: () =>
                              _openForm(context, DebtExpenseKind.staffPayment),
                        ),
                      ],
                    ),
                  ),
                  const SectionLabel(title: 'Son hareketler'),
                  recentAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => ErrorRetryState(
                      compact: true,
                      title: 'Hareketler yüklenemedi',
                      subtitle: 'Son hareketler alınamadı. Tekrar deneyin.',
                      onRetry: () =>
                          ref.invalidate(debtExpenseEntriesProvider(null)),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s),
                          child: EmptyState(
                            compact: true,
                            icon: Icons.receipt_long_rounded,
                            title: AppStrings.deEmptyTitle,
                            subtitle: AppStrings.deEmptySub,
                          ),
                        );
                      }
                      final recent = items.take(5).toList();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageH),
                        child: Column(
                          children: [
                            for (final e in recent) ...[
                              DebtExpenseEntryCard(entry: e, today: today),
                              const SizedBox(height: AppSpacing.m),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.summary});
  final DebtExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        0,
      ),
      child: Column(
        children: [
          StatCard(
            label: AppStrings.deOpenDebt,
            value: NumberFormatter.currency(summary.openDebtTotal),
            icon: Icons.account_balance_wallet_rounded,
            hero: true,
            warm: true,
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: AppStrings.deThisMonthExpense,
                  value: NumberFormatter.currency(summary.thisMonthExpense),
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: StatCard(
                  label: AppStrings.deStaffPayable,
                  value: NumberFormatter.currency(summary.staffPayableTotal),
                  icon: Icons.badge_rounded,
                ),
              ),
            ],
          ),
          if (summary.overdueCount > 0) ...[
            const SizedBox(height: AppSpacing.m),
            _OverdueNotice(
              count: summary.overdueCount,
              total: summary.overdueTotal,
            ),
          ],
          if (summary.upcomingThisWeek > 0) ...[
            const SizedBox(height: AppSpacing.m),
            _UpcomingNotice(count: summary.upcomingThisWeek),
          ],
        ],
      ),
    );
  }
}

/// Geciken: sakin amber uyarı (panik kırmızı değil).
class _OverdueNotice extends StatelessWidget {
  const _OverdueNotice({required this.count, required this.total});
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: const Icon(Icons.schedule_rounded,
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count geciken ödeme',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Toplam ${NumberFormatter.currency(total)} — Borçlar '
                  'sekmesinden takip et.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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

class _UpcomingNotice extends StatelessWidget {
  const _UpcomingNotice({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.event_available_rounded,
            size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          'Bu hafta vadesi gelen $count ödeme',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.m, horizontal: AppSpacing.s),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
                  width: 0.7,
                ),
              ),
              child: Icon(icon, color: AppColors.brandInk, size: 19),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
