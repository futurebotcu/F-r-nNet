import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer_range_metrics.dart';
import '../providers/dealer_providers.dart';
import '../services/dealer_period.dart';

/// Bayi için sabit-6 periyot arasında metrik raporu (Sprint 3).
///
/// `[start, end)` aralığında: gross totals (delivery/return/payment/
/// adjustment) + netChange + txCount. `summarize`'ın sabit periyot
/// hesabını **bozmaz** — yan-yana yaşar.
///
/// Custom date range picker, PDF export ve EMA-baseline pulse card
/// bu sprintte yok (Sprint 3.5 ve sonrası).
class DealerRangeReportScreen extends ConsumerStatefulWidget {
  const DealerRangeReportScreen({
    super.key,
    required this.dealerId,
    this.initialPeriodKey,
    @visibleForTesting this.now,
  });

  final String dealerId;

  /// Quality Patch v2: Raporlar tab'ından gelen periyot anahtarı.
  /// Bilinen değerler: `last30Days`, `thisMonth`. Bilinmeyen/null →
  /// default `last30Days` davranışı korunur.
  final String? initialPeriodKey;

  /// Test deterministik için reference time injection. Production'da null.
  final DateTime? now;

  @override
  ConsumerState<DealerRangeReportScreen> createState() =>
      _DealerRangeReportScreenState();
}

class _DealerRangeReportScreenState
    extends ConsumerState<DealerRangeReportScreen> {
  late _ReportPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = _parseInitialPeriod(widget.initialPeriodKey);
  }

  static _ReportPeriod _parseInitialPeriod(String? key) {
    switch (key) {
      case 'last30Days':
        return _ReportPeriod.last30Days;
      case 'thisMonth':
        return _ReportPeriod.thisMonth;
      case 'thisWeek':
        return _ReportPeriod.thisWeek;
      case 'today':
        return _ReportPeriod.today;
      case 'previousWeek':
        return _ReportPeriod.previousWeek;
      case 'previousMonth':
        return _ReportPeriod.previousMonth;
      default:
        return _ReportPeriod.last30Days;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealerAsync = ref.watch(dealerByIdProvider(widget.dealerId));
    final range = _period.range(now: widget.now);
    final metricsAsync = ref.watch(dealerRangeMetricsProvider(
      (dealerId: widget.dealerId, start: range.start, end: range.end),
    ));

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(
          dealerAsync.maybeWhen(
            data: (d) => d == null
                ? AppStrings.dealerReportTitle
                : '${AppStrings.dealerReportTitle} — ${d.name}',
            orElse: () => AppStrings.dealerReportTitle,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pageH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodChipRow(
                selected: _period,
                onSelect: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: AppSpacing.m),
              _DateRangeLabel(start: range.start, end: range.end),
              const SizedBox(height: AppSpacing.l),
              metricsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: Text('Hata: $e')),
                ),
                data: (m) => m.txCount == 0
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: EmptyState(
                          title: AppStrings.dealerReportEmptyTitle,
                          subtitle: AppStrings.dealerReportEmptyBody,
                          icon: Icons.event_busy_outlined,
                          compact: true,
                        ),
                      )
                    : _MetricsGrid(metrics: m),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Periyot seçim chip satırı.
class _PeriodChipRow extends StatelessWidget {
  const _PeriodChipRow({required this.selected, required this.onSelect});

  final _ReportPeriod selected;
  final ValueChanged<_ReportPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: _ReportPeriod.values.map((p) {
        final isSelected = p == selected;
        return ChoiceChip(
          label: Text(p.label),
          selected: isSelected,
          onSelected: (_) => onSelect(p),
        );
      }).toList(),
    );
  }
}

/// "18 May – 24 May 2026" benzeri okunabilir aralık etiketi.
class _DateRangeLabel extends StatelessWidget {
  const _DateRangeLabel({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'tr_TR');
    // end exclusive — gösterimde aralık-içi son tam günü (`end - 1ms`) işaret et.
    final inclusiveEnd = end.subtract(const Duration(milliseconds: 1));
    final text = '${fmt.format(start)} – ${fmt.format(inclusiveEnd)}';
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// 2 sütun × 3 satır KPI tile grid.
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final DealerRangeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s,
      crossAxisSpacing: AppSpacing.s,
      childAspectRatio: 1.4,
      children: [
        _MetricTile(
          label: AppStrings.dealerTxFilterTypeDelivery,
          value: NumberFormatter.currency(metrics.totalDelivery),
          accent: AppColors.copper,
        ),
        _MetricTile(
          label: AppStrings.dealerTxFilterTypeReturn,
          value: NumberFormatter.currency(metrics.totalReturn),
          accent: AppColors.info,
        ),
        _MetricTile(
          label: AppStrings.dealerTxFilterTypePayment,
          value: NumberFormatter.currency(metrics.totalPayment),
          accent: AppColors.success,
        ),
        _MetricTile(
          label: AppStrings.dealerTxFilterTypeAdjustment,
          value: NumberFormatter.currency(metrics.totalAdjustment),
          accent: AppColors.softGold,
        ),
        _MetricTile(
          label: AppStrings.dealerReportMetricNet,
          value: NumberFormatter.currency(metrics.netChange),
          accent: metrics.netChange == 0
              ? AppColors.textMuted
              : (metrics.netChange > 0 ? AppColors.copper : AppColors.success),
          emphasized: true,
        ),
        _MetricTile(
          label: AppStrings.dealerReportMetricTxCount,
          value: NumberFormatter.integer(metrics.txCount),
          accent: AppColors.textMuted,
          isCount: true,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    this.emphasized = false,
    this.isCount = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool emphasized;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      warm: emphasized,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          Text(
            value,
            style: (emphasized
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleLarge)
                ?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              fontFeatures: isCount ? null : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sabit 6 periyot — Sprint 3 scope'unda kilitli. Custom date range
/// picker Sprint 3.5'te.
enum _ReportPeriod {
  today,
  thisWeek,
  thisMonth,
  last30Days,
  previousWeek,
  previousMonth,
}

extension _ReportPeriodX on _ReportPeriod {
  String get label {
    switch (this) {
      case _ReportPeriod.today:
        return AppStrings.dealerTxFilterRangeToday;
      case _ReportPeriod.thisWeek:
        return AppStrings.dealerTxFilterRangeWeek;
      case _ReportPeriod.thisMonth:
        return AppStrings.dealerTxFilterRangeMonth;
      case _ReportPeriod.last30Days:
        return AppStrings.dealerReportPeriodLast30;
      case _ReportPeriod.previousWeek:
        return AppStrings.dealerReportPeriodPrevWeek;
      case _ReportPeriod.previousMonth:
        return AppStrings.dealerReportPeriodPrevMonth;
    }
  }

  ({DateTime start, DateTime end}) range({DateTime? now}) {
    switch (this) {
      case _ReportPeriod.today:
        return DealerPeriod.today(now: now);
      case _ReportPeriod.thisWeek:
        return DealerPeriod.thisWeek(now: now);
      case _ReportPeriod.thisMonth:
        return DealerPeriod.thisMonth(now: now);
      case _ReportPeriod.last30Days:
        return DealerPeriod.lastNDays(30, now: now);
      case _ReportPeriod.previousWeek:
        return DealerPeriod.previousWeek(now: now);
      case _ReportPeriod.previousMonth:
        return DealerPeriod.previousMonth(now: now);
    }
  }
}
