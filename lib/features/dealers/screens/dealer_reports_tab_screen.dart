import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../models/dealer_range_metrics.dart';
import '../providers/dealer_providers.dart';
import '../services/dealer_period.dart';

/// Bayi Defteri mini-app Raporlar tab (toplu + bayi bazlı rapor).
///
/// 3 periyot segmenti (Son 7 gün / Son 30 gün / Bu ay) + Genel Toplam
/// KPI kartı + Bayi Bazlı Rapor listesi. Listede her satır mevcut
/// [DealerRangeReportScreen] (`/dealers/:id/report`) ekranına yönlendirir.
///
/// Net değişim renk mantığı DealerPulseCard ile aynı: pozitif → copper
/// (borç artıyor), negatif → success (tahsilat iyi), sıfır → textMuted.
class DealerReportsTabScreen extends ConsumerStatefulWidget {
  const DealerReportsTabScreen({super.key, @visibleForTesting this.now});

  /// Test deterministik için reference time injection.
  final DateTime? now;

  @override
  ConsumerState<DealerReportsTabScreen> createState() =>
      _DealerReportsTabScreenState();
}

class _DealerReportsTabScreenState
    extends ConsumerState<DealerReportsTabScreen> {
  _ReportsPeriod _period = _ReportsPeriod.last30Days;

  @override
  Widget build(BuildContext context) {
    final range = _period.range(now: widget.now);
    final metricsAsync = ref.watch(
      allDealersRangeMetricsProvider(
        (start: range.start, end: range.end),
      ),
    );
    final dealersAsync = ref.watch(activeDealersListProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dealerShellTabReports),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodSegment(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: AppSpacing.l),
              metricsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                  child: Text('Hata: $e'),
                ),
                data: (m) => _SummarySection(metrics: m),
              ),
              const SizedBox(height: AppSpacing.l),
              dealersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('Hata: $e'),
                data: (dealers) => _ByDealerSection(
                  dealers: dealers,
                  perDealerNet: metricsAsync.maybeWhen(
                    data: (m) => m.perDealerNet,
                    orElse: () => const <String, double>{},
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

enum _ReportsPeriod {
  last7Days,
  last30Days,
  thisMonth,
}

extension on _ReportsPeriod {
  String get label {
    switch (this) {
      case _ReportsPeriod.last7Days:
        return AppStrings.dealerReportsPeriodLast7;
      case _ReportsPeriod.last30Days:
        return AppStrings.dealerReportsPeriodLast30;
      case _ReportsPeriod.thisMonth:
        return AppStrings.dealerReportsPeriodThisMonth;
    }
  }

  ({DateTime start, DateTime end}) range({DateTime? now}) {
    switch (this) {
      case _ReportsPeriod.last7Days:
        return DealerPeriod.lastNDays(7, now: now);
      case _ReportsPeriod.last30Days:
        return DealerPeriod.lastNDays(30, now: now);
      case _ReportsPeriod.thisMonth:
        return DealerPeriod.thisMonth(now: now);
    }
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.value, required this.onChanged});

  final _ReportsPeriod value;
  final ValueChanged<_ReportsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final p in _ReportsPeriod.values)
          ChoiceChip(
            label: Text(p.label),
            selected: value == p,
            onSelected: (s) {
              if (s) onChanged(p);
            },
            selectedColor: AppColors.copper.withValues(alpha: 0.18),
            backgroundColor: AppColors.card,
            side: BorderSide(
              color: value == p
                  ? AppColors.copper
                  : AppColors.borderHairline,
              width: value == p ? 1.2 : 0.6,
            ),
            labelStyle: TextStyle(
              color: value == p ? AppColors.copper : AppColors.textSecondary,
              fontWeight: value == p ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.metrics});
  final DealerAggregateRangeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnyActivity = metrics.txCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Text(
                AppStrings.dealerReportsSummaryTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${metrics.activeDealerCount} '
                '${AppStrings.dealerReportsActiveDealersLabel}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        if (!hasAnyActivity)
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                AppStrings.dealerReportsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          _KpiBlock(metrics: metrics),
      ],
    );
  }
}

class _KpiBlock extends StatelessWidget {
  const _KpiBlock({required this.metrics});
  final DealerAggregateRangeMetrics metrics;

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
              label: AppStrings.dealerReportsKpiDelivery,
              value: NumberFormatter.currency(metrics.totalDelivery),
              accent: AppColors.softGold,
            ),
            _KpiTile(
              label: AppStrings.dealerReportsKpiReturn,
              value: NumberFormatter.currency(metrics.totalReturn),
              accent: AppColors.textSecondary,
            ),
            _KpiTile(
              label: AppStrings.dealerReportsKpiPayment,
              value: NumberFormatter.currency(metrics.totalPayment),
              accent: AppColors.success,
            ),
            _KpiTile(
              label: AppStrings.dealerReportsKpiTxCount,
              value: NumberFormatter.integer(metrics.txCount),
              accent: AppColors.textSecondary,
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        _KpiTile(
          label: AppStrings.dealerReportsKpiNetChange,
          value: NumberFormatter.currency(metrics.netChange),
          accent: _netColor(metrics.netChange),
          emphasized: true,
          fullWidth: true,
        ),
      ],
    );
  }
}

Color _netColor(double net) {
  if (net == 0) return AppColors.textMuted;
  return net > 0 ? AppColors.copper : AppColors.success;
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

class _ByDealerSection extends StatelessWidget {
  const _ByDealerSection({
    required this.dealers,
    required this.perDealerNet,
  });

  final List<Dealer> dealers;
  final Map<String, double> perDealerNet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.dealerReportsByDealerTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        if (dealers.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                AppStrings.dealerReportsNoActiveDealers,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < dealers.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 0.6,
                      thickness: 0.6,
                      color: AppColors.borderHairline,
                    ),
                  _DealerRow(
                    dealer: dealers[i],
                    net: perDealerNet[dealers[i].id] ?? 0,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DealerRow extends StatelessWidget {
  const _DealerRow({required this.dealer, required this.net});

  final Dealer dealer;
  final double net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        dealer.name.isEmpty ? '?' : dealer.name[0].toUpperCase();
    return InkWell(
      onTap: () => context.push(AppRoutes.dealerReport(dealer.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.copper.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.copper.withValues(alpha: 0.25),
                  width: 0.6,
                ),
              ),
              child: Text(
                initial,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.copper,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                dealer.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            _NetChip(net: net),
            const SizedBox(width: AppSpacing.s),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetChip extends StatelessWidget {
  const _NetChip({required this.net});
  final double net;

  @override
  Widget build(BuildContext context) {
    final color = _netColor(net);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.6),
      ),
      child: Text(
        NumberFormatter.currency(net),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
