import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../providers/bakery_providers.dart';

/// Fırın Defteri — Gün Sonu.
///
/// Bu ekran FIRIN'IN KENDİ günlük defterini kapatır; bayi/dealer gün sonu
/// AYRI modüldür (Bayi Defteri) ve buradaki metinler bayi diliyle KARIŞMAZ.
class EndOfDayScreen extends ConsumerWidget {
  const EndOfDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final dayBook = ref.watch(todayDayBookProvider);
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.ledgerEodTitle)),
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryState(
            onRetry: () => ref.invalidate(todaySummaryProvider),
          ),
          data: (s) {
            final book = dayBook.valueOrNull;
            final closed = book?.isClosed ?? false;
            final ratio = s.wasteRatio;
            final doneCount = tasks.where((t) => t.isDone).length;
            final openCount = tasks.length - doneCount;
            return ListView(
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
                      child: Text(
                        df.format(s.day).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      key: ValueKey('eod_status_${closed ? 'closed' : 'open'}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: closed
                            ? const Color(0xFFF3FBEF)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        closed
                            ? AppStrings.ledgerDayClosed
                            : AppStrings.ledgerDayOpen,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: closed
                              ? const Color(0xFF166534)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                StatCard(
                  warm: true,
                  hero: true,
                  icon: Icons.payments_outlined,
                  label: AppStrings.ledgerEodRevenue,
                  value: book?.revenueAmount == null
                      ? '₺ —'
                      : NumberFormatter.currency(book!.revenueAmount!),
                  helper: AppStrings.ledgerRevenueHint,
                  accent: AppColors.softGold,
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.bakery_dining_outlined,
                        label: AppStrings.ledgerEodProduction,
                        value:
                            '${NumberFormatter.integer(s.totalProduction)} adet',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: StatCard(
                        icon: Icons.delete_sweep_outlined,
                        label: AppStrings.ledgerEodWaste,
                        value: '${NumberFormatter.integer(s.totalWaste)} adet',
                        accent: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.percent_rounded,
                        label: AppStrings.ledgerEodWasteRatio,
                        value: ratio == null
                            ? '—'
                            : '%${(ratio * 100).toStringAsFixed(1)}',
                        accent: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: StatCard(
                        icon: Icons.task_alt_rounded,
                        label: AppStrings.ledgerEodTasksDone,
                        value: '$doneCount / ${tasks.length}',
                        helper: openCount > 0
                            ? '$openCount ${AppStrings.ledgerEodTasksOpen.toLowerCase()}'
                            : null,
                        accent: const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
                if ((book?.dayNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.ledgerEodNoteLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book!.dayNote,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                if (closed) ...[
                  const Text(
                    AppStrings.ledgerDayClosedInfo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    key: const ValueKey('ledger_reopen_day'),
                    onPressed: () => ref
                        .read(bakeryRepositoryProvider)
                        .reopenDay(DateTime.now()),
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text(AppStrings.ledgerReopenDayCta),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.textSecondary,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ] else
                  FilledButton.icon(
                    key: const ValueKey('ledger_close_day'),
                    onPressed: () async {
                      await ref
                          .read(bakeryRepositoryProvider)
                          .closeDay(DateTime.now());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.ledgerDayClosed),
                        ),
                      );
                    },
                    icon: const Icon(Icons.nightlight_rounded, size: 18),
                    label: const Text(AppStrings.ledgerCloseDayCta),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandLemon,
                      foregroundColor: AppColors.brandInk,
                      minimumSize: const Size(0, 50),
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
          },
        ),
      ),
    );
  }
}
