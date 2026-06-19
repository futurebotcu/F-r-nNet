import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../models/dealer_range_metrics.dart';
import '../providers/dealer_providers.dart';
import '../services/dealer_period.dart';
import '../widgets/dealer_avatar.dart';
import '../widgets/dealer_filter_chip.dart';
import '../widgets/dealer_kpi_tile.dart';

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
      allDealersRangeMetricsProvider((start: range.start, end: range.end)),
    );
    final dealersAsync = ref.watch(activeDealersListProvider);

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerShellTabReports)),
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
              const SizedBox(height: AppSpacing.m),
              // Gün Sonu artık ayrı alt-tab değil; Raporlar içinden açılır.
              PremiumCard(
                padding: EdgeInsets.zero,
                onTap: () => context.push(AppRoutes.dealerEndOfDay),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 20, color: AppColors.copper),
                      SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text('Gün Sonu',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              metricsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                  child: Text(AppStrings.dealersErrorLoad),
                ),
                data: (m) => _SummarySection(metrics: m),
              ),
              const SizedBox(height: AppSpacing.l),
              dealersAsync.when(
                skipLoadingOnReload: true,
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const Text(AppStrings.dealersErrorLoad),
                data: (dealers) => _ByDealerSection(
                  dealers: dealers,
                  perDealerNet: metricsAsync.maybeWhen(
                    data: (m) => m.perDealerNet,
                    orElse: () => const <String, double>{},
                  ),
                  activePeriod: _period,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ReportsPeriod { last7Days, last30Days, thisMonth }

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
          DealerFilterChip(
            label: p.label,
            selected: value == p,
            onSelected: (s) {
              if (s) onChanged(p);
            },
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
          const EmptyState(
            title: AppStrings.dealerReportsEmpty,
            icon: Icons.history_outlined,
            compact: true,
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
            DealerKpiTile(
              label: AppStrings.dealerReportsKpiDelivery,
              value: NumberFormatter.currency(metrics.totalDelivery),
              accent: AppColors.softGold,
            ),
            DealerKpiTile(
              label: AppStrings.dealerReportsKpiReturn,
              value: NumberFormatter.currency(metrics.totalReturn),
              accent: AppColors.textSecondary,
            ),
            DealerKpiTile(
              label: AppStrings.dealerReportsKpiPayment,
              value: NumberFormatter.currency(metrics.totalPayment),
              accent: AppColors.success,
            ),
            DealerKpiTile(
              label: AppStrings.dealerReportsKpiTxCount,
              value: NumberFormatter.integer(metrics.txCount),
              accent: AppColors.textSecondary,
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        DealerKpiTile(
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

class _ByDealerSection extends StatelessWidget {
  const _ByDealerSection({
    required this.dealers,
    required this.perDealerNet,
    required this.activePeriod,
  });

  final List<Dealer> dealers;
  final Map<String, double> perDealerNet;

  /// Quality Patch v2: bayi satır tap'ında range-report ekranına seçili
  /// periyot transfer edilir (eşleşen periyotlar için).
  final _ReportsPeriod activePeriod;

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
          const EmptyState(
            title: AppStrings.dealerReportsNoActiveDealers,
            icon: Icons.storefront_outlined,
            compact: true,
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
                    activePeriod: activePeriod,
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
  const _DealerRow({
    required this.dealer,
    required this.net,
    required this.activePeriod,
  });

  final Dealer dealer;
  final double net;
  final _ReportsPeriod activePeriod;

  /// Quality Patch v2: Reports periyot'larından sadece RangeReport'ta
  /// karşılığı olanlar transfer edilir; `last7Days` RangeReport'ta
  /// yok → null döner (default `last30Days`'e düşer).
  String? get _transferPeriodKey {
    switch (activePeriod) {
      case _ReportsPeriod.last7Days:
        return null;
      case _ReportsPeriod.last30Days:
        return 'last30Days';
      case _ReportsPeriod.thisMonth:
        return 'thisMonth';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(
        AppRoutes.dealerReport(dealer.id, period: _transferPeriodKey),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            DealerAvatar(
              dealer: dealer,
              size: 36,
              shape: DealerAvatarShape.circle,
              palette: DealerAvatarPalette.copper,
              fallbackChar: '?',
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
