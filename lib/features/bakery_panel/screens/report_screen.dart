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

/// Fırın Defteri — basit dönem raporu (Bugün / Dün / 7 Gün / 30 Gün).
/// PDF/Excel/grafik YOK (V2) — sade kart/liste.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  LedgerReportPeriod _period = LedgerReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(ledgerReportProvider(_period));
    final df = DateFormat('d MMM', 'tr_TR');

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.ledgerReportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            // Dönem seçici — dar ekranda taşmasın (Wrap).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in LedgerReportPeriod.values)
                  ChoiceChip(
                    key: ValueKey('ledger_period_${p.name}'),
                    label: Text(p.label),
                    selected: _period == p,
                    onSelected: (_) => setState(() => _period = p),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brandLemonPale,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            report.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorRetryState(
                onRetry: () => ref.invalidate(ledgerReportProvider(_period)),
              ),
              data: (r) {
                final empty =
                    r.totalProduction == 0 &&
                    r.totalWaste == 0 &&
                    r.totalRevenue == 0 &&
                    r.closedDays == 0;
                if (empty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    child: Text(
                      AppStrings.ledgerReportEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                final ratio = r.wasteRatio;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${df.format(r.from)} – ${df.format(r.to)}'.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.bakery_dining_outlined,
                            label: AppStrings.ledgerEodProduction,
                            value:
                                '${NumberFormatter.integer(r.totalProduction)} adet',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: StatCard(
                            icon: Icons.delete_sweep_outlined,
                            label: AppStrings.ledgerEodWaste,
                            value:
                                '${NumberFormatter.integer(r.totalWaste)} adet',
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
                            icon: Icons.payments_outlined,
                            label: AppStrings.ledgerEodRevenue,
                            value: NumberFormatter.currency(r.totalRevenue),
                            accent: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    StatCard(
                      icon: Icons.nightlight_outlined,
                      label: AppStrings.ledgerReportClosedDays,
                      value: NumberFormatter.integer(r.closedDays),
                    ),
                    if (r.topWasteProducts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.l),
                      const _SectionTitle(AppStrings.ledgerReportTopWaste),
                      const SizedBox(height: AppSpacing.s),
                      PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          children: [
                            for (final (product, qty) in r.topWasteProducts)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_sweep_outlined,
                                      size: 15,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: Text(
                                        product,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$qty adet',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (r.recentDayNotes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.l),
                      const _SectionTitle(AppStrings.ledgerReportRecentNotes),
                      const SizedBox(height: AppSpacing.s),
                      PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (date, note) in r.recentDayNotes)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      df.format(date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      note,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}
