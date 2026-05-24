import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_picker_sheet.dart';
import '../widgets/quick_payment_sheet.dart';

/// Bayi Defteri Genel Bakış ekranı (Sprint 6B).
///
/// Sprint 6A shell'inin Genel Bakış tab'ında render edilir. KPI grid +
/// Son Hareketler + Hızlı İşlem CTA'ları içerir. Backend dokunmaz;
/// mevcut [dealersOverviewProvider] + [recentActivityProvider] +
/// [dealersListProvider] üzerinden çalışır.
class DealerOverviewScreen extends ConsumerWidget {
  const DealerOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(dealersOverviewProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dealerShellTabOverview),
      ),
      body: SafeArea(
        top: false,
        child: overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (o) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.m,
              AppSpacing.pageH,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActiveDealersChip(
                  active: o.activeDealers,
                  total: o.totalDealers,
                ),
                const SizedBox(height: AppSpacing.m),
                _KpiGrid(overview: o),
                const SizedBox(height: AppSpacing.l),
                const _RecentActivitySection(),
                const SizedBox(height: AppSpacing.l),
                const _QuickActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDealersChip extends StatelessWidget {
  const _ActiveDealersChip({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_rounded,
              size: 16, color: AppColors.softGold),
          const SizedBox(width: AppSpacing.s),
          Text(
            AppStrings.dealerOverviewActiveDealersLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            '$active / $total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.overview});
  final DealerOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          childAspectRatio: 1.5,
          children: [
            _KpiTile(
              label: AppStrings.dealerOverviewKpiOpenBalance,
              value: NumberFormatter.currency(overview.openBalance),
              accent: AppColors.copper,
            ),
            _KpiTile(
              label: AppStrings.dealerOverviewKpiTodayDelivery,
              value: NumberFormatter.currency(overview.todayDelivered),
              accent: AppColors.softGold,
            ),
            _KpiTile(
              label: AppStrings.dealerOverviewKpiTodayPayment,
              value: NumberFormatter.currency(overview.todayCollected),
              accent: AppColors.success,
            ),
            _KpiTile(
              label: AppStrings.dealerOverviewKpiMonthTxCount,
              value: NumberFormatter.integer(overview.monthTxCount),
              accent: AppColors.textSecondary,
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        // Bu Ay Net Değişim full-width emphasized tile
        _KpiTile(
          label: AppStrings.dealerOverviewKpiMonthNetChange,
          value: NumberFormatter.currency(overview.monthNetChange),
          accent: overview.monthNetChange == 0
              ? AppColors.textMuted
              : (overview.monthNetChange > 0
                  ? AppColors.copper
                  : AppColors.success),
          emphasized: true,
          fullWidth: true,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.accent,
    this.emphasized = false,
    this.isCount = false,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool emphasized;
  final bool isCount;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      warm: emphasized,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: fullWidth ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: (emphasized
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleLarge)
                ?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              fontFeatures:
                  isCount ? null : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentActivityProvider);
    final dealersAsync = ref.watch(dealersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Text(
                AppStrings.dealerOverviewRecentActivityTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // "Tümünü Gör" → Bayiler tab'a switch
                  ref.read(dealerShellTabIndexProvider.notifier).state = 1;
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 0,
                  ),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.copper,
                ),
                child: const Text(AppStrings.dealerOverviewSeeAll),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        recentAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
            child: Center(child: Text('Hata: $e')),
          ),
          data: (txs) {
            if (txs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: EmptyState(
                  title: AppStrings.dealerOverviewEmptyActivity,
                  icon: Icons.history_outlined,
                  compact: true,
                ),
              );
            }
            final dealerNameById = dealersAsync.maybeWhen(
              data: (list) => {for (final d in list) d.id: d.name},
              orElse: () => <String, String>{},
            );
            return PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < txs.length; i++) ...[
                    _RecentTxRow(
                      tx: txs[i],
                      dealerName: dealerNameById[txs[i].dealerId] ?? '—',
                    ),
                    if (i < txs.length - 1)
                      const Divider(
                        height: 0.6,
                        thickness: 0.6,
                        color: AppColors.borderHairline,
                      ),
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

class _RecentTxRow extends StatelessWidget {
  const _RecentTxRow({required this.tx, required this.dealerName});

  final DealerTransaction tx;
  final String dealerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, sign) = _meta(tx.type);
    final amount = tx.amount.abs();
    final formattedAmount =
        '$sign${NumberFormatter.currency(amount)}'.replaceAll(' ', ' ');

    return InkWell(
      onTap: () =>
          context.push('${AppRoutes.dealers}/${tx.dealerId}'),
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dealerName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _relativeDate(tx.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formattedAmount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// tx tipi → (ikon, renk, tutar işareti)
  (IconData, Color, String) _meta(DealerTransactionType t) {
    switch (t) {
      case DealerTransactionType.delivery:
        return (Icons.bakery_dining_rounded, AppColors.copper, '+');
      case DealerTransactionType.returned:
        return (Icons.assignment_returned_rounded, AppColors.info, '−');
      case DealerTransactionType.payment:
        return (Icons.payments_rounded, AppColors.success, '−');
      case DealerTransactionType.adjustment:
        return (Icons.tune_rounded, AppColors.softGold, '±');
    }
  }
}

/// Görece kısa tarih: bugün → "bugün HH:mm", dün → "dün", aynı hafta →
/// "N gün önce", aksi halde "d MMM" (TR locale).
String _relativeDate(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final atDay = DateTime(at.year, at.month, at.day);
  final diff = today.difference(atDay).inDays;
  if (diff == 0) {
    final hm = DateFormat('HH:mm').format(at);
    return 'bugün $hm';
  }
  if (diff == 1) return 'dün';
  if (diff > 1 && diff < 7) return '$diff gün önce';
  return DateFormat('d MMM', 'tr_TR').format(at);
}

class _QuickActionsSection extends ConsumerWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.dealerOverviewQuickActionsTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            _QuickActionChip(
              icon: Icons.person_add_alt_1_rounded,
              label: AppStrings.dealerOverviewQuickAddDealer,
              onTap: () => context.push(AppRoutes.dealerNew),
            ),
            _QuickActionChip(
              icon: Icons.bakery_dining_rounded,
              label: AppStrings.dealerOverviewQuickDelivery,
              accent: AppColors.copper,
              onTap: () => _pickThen(context, ref, debtOnly: false,
                  onPicked: (d) => context.push(
                        '${AppRoutes.dealers}/${d.id}/delivery',
                      )),
            ),
            _QuickActionChip(
              icon: Icons.payments_rounded,
              label: AppStrings.dealerOverviewQuickPayment,
              accent: AppColors.success,
              onTap: () => _pickThen(context, ref, debtOnly: true,
                  onPicked: (d) async {
                // Borçlu filter zaten currentBalance > 0 garantiler;
                // QuickPaymentSheet.show direkt çağrılır.
                final svc = ref.read(dealerBalanceServiceProvider);
                final repo = ref.read(dealerRepositoryProvider);
                final txs = await repo.listTransactions(d.id);
                final summary =
                    svc.summarize(dealerId: d.id, transactions: txs);
                if (!context.mounted) return;
                await QuickPaymentSheet.show(
                  context: context,
                  dealerId: d.id,
                  dealerName: d.name,
                  currentBalance: summary.currentBalance,
                );
              }),
            ),
            _QuickActionChip(
              icon: Icons.warning_amber_rounded,
              label: AppStrings.dealerOverviewQuickDebtDealers,
              accent: AppColors.copper,
              // Sprint 6B kontrollü kapsam: Bayiler tab'a switch yeterli;
              // kart'lardaki BAKIYE pill'i borçlu bayileri zaten vurgular.
              // True "debt-only" filter chip ileride 6B.x'te.
              onTap: () =>
                  ref.read(dealerShellTabIndexProvider.notifier).state = 1,
            ),
            _QuickActionChip(
              icon: Icons.analytics_outlined,
              label: AppStrings.dealerOverviewQuickReports,
              accent: AppColors.info,
              onTap: () {
                ref.read(dealerShellTabIndexProvider.notifier).state = 3;
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickThen(
    BuildContext context,
    WidgetRef ref, {
    required bool debtOnly,
    required Future<void> Function(Dealer) onPicked,
  }) async {
    final picked = await DealerPickerSheet.show(
      context: context,
      debtOnly: debtOnly,
    );
    if (picked == null || !context.mounted) return;
    await onPicked(picked);
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.softGold,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.borderHairline,
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: AppSpacing.s),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
