import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../services/dealer_period.dart';
import '../widgets/dealer_avatar.dart';
import '../widgets/dealer_kpi_tile.dart';

/// Bayi Defteri mini-app Gün Sonu tab — pasif günlük rapor (V1).
///
/// Bugünün KPI özeti + bugün hareketi olan aktif bayi listesi + bugünün
/// son hareketleri + WhatsApp/SMS paylaş. Gün kapatma / lock / DB yok;
/// query-driven (yarın açılınca yeni günün verisi gelir).
///
/// Hesap kaynağı: `allDealersRangeMetricsProvider((today, tomorrow))` —
/// Quality Patch v1 sonrası tek hesap kaynağı `aggregateRange` üzerinden.
class DealerEndOfDayTabScreen extends ConsumerWidget {
  const DealerEndOfDayTabScreen({super.key, @visibleForTesting this.now});

  /// Test deterministik için reference time injection.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref0 = now ?? DateTime.now();
    final todayRange = DealerPeriod.today(now: ref0);
    final metricsAsync = ref.watch(
      allDealersRangeMetricsProvider((
        start: todayRange.start,
        end: todayRange.end,
      )),
    );
    final dealersAsync = ref.watch(dealersListProvider);
    final txsAsync = ref.watch(allTransactionsProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dealerShellTabEndOfDay),
        actions: [
          IconButton(
            tooltip: AppStrings.dealerEndOfDayShareTooltip,
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _share(ref, ref0),
          ),
        ],
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
              _Header(now: ref0),
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
                data: (metrics) => _Body(
                  metrics: metrics,
                  dealers: dealersAsync.value ?? const <Dealer>[],
                  todayTxs: _todayTxs(txsAsync.value, todayRange),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              _ShareCta(onTap: () => _share(ref, ref0)),
            ],
          ),
        ),
      ),
    );
  }

  static List<DealerTransaction> _todayTxs(
    List<DealerTransaction>? all,
    ({DateTime start, DateTime end}) r,
  ) {
    if (all == null) return const <DealerTransaction>[];
    return all
        .where(
          (t) => !t.createdAt.isBefore(r.start) && t.createdAt.isBefore(r.end),
        )
        .toList();
  }

  Future<void> _share(WidgetRef ref, DateTime nowRef) async {
    final todayRange = DealerPeriod.today(now: nowRef);
    final metrics = await ref.read(
      allDealersRangeMetricsProvider((
        start: todayRange.start,
        end: todayRange.end,
      )).future,
    );
    final dealers = await ref.read(dealersListProvider.future);
    final builder = ref.read(dealerShareBuilderProvider);
    final text = builder.buildDailySummary(
      metrics: metrics,
      dealers: dealers,
      now: nowRef,
    );
    await Share.share(text, subject: AppStrings.dealerEndOfDayPlainTextHeader);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.dealerEndOfDayHeaderToday.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              df.format(now),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.metrics,
    required this.dealers,
    required this.todayTxs,
  });

  final DealerAggregateRangeMetrics metrics;
  final List<Dealer> dealers;
  final List<DealerTransaction> todayTxs;

  @override
  Widget build(BuildContext context) {
    if (metrics.txCount == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyState(
          title: AppStrings.dealerEndOfDayEmptyTitle,
          subtitle: AppStrings.dealerEndOfDayEmptyBody,
          icon: Icons.event_available_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummarySection(metrics: metrics),
        const SizedBox(height: AppSpacing.l),
        _ByDealerSection(metrics: metrics, dealers: dealers),
        const SizedBox(height: AppSpacing.l),
        _RecentSection(todayTxs: todayTxs, dealers: dealers),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.dealerEndOfDaySummaryTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
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
  const _ByDealerSection({required this.metrics, required this.dealers});

  final DealerAggregateRangeMetrics metrics;
  final List<Dealer> dealers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dealerById = {for (final d in dealers) d.id: d};
    // Yalnız bugün hareketi olan aktif bayiler (perDealerTxCount > 0).
    // Provider zaten pasif bayileri groupBy filter'lamış; bu yüzden
    // map'te yalnız aktif kayıt var.
    final entries =
        metrics.perDealerTxCount.entries
            .where((e) => e.value > 0 && dealerById.containsKey(e.key))
            .toList()
          ..sort((a, b) {
            final na = metrics.perDealerNet[a.key] ?? 0;
            final nb = metrics.perDealerNet[b.key] ?? 0;
            return nb.compareTo(na);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            AppStrings.dealerEndOfDayByDealerTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 0.6,
                    thickness: 0.6,
                    color: AppColors.borderHairline,
                  ),
                _DealerTodayRow(
                  dealer: dealerById[entries[i].key]!,
                  net: metrics.perDealerNet[entries[i].key] ?? 0,
                  txCount: entries[i].value,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DealerTodayRow extends StatelessWidget {
  const _DealerTodayRow({
    required this.dealer,
    required this.net,
    required this.txCount,
  });

  final Dealer dealer;
  final double net;
  final int txCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _netColor(net);
    return InkWell(
      onTap: () => context.push('${AppRoutes.dealers}/${dealer.id}'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dealer.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$txCount ${AppStrings.dealerEndOfDayTxCountSuffix}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 0.6,
                ),
              ),
              child: Text(
                NumberFormatter.currency(net),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
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

class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.todayTxs, required this.dealers});

  final List<DealerTransaction> todayTxs;
  final List<Dealer> dealers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (todayTxs.isEmpty) return const SizedBox.shrink();

    final dealerNameById = {for (final d in dealers) d.id: d.name};
    final top = todayTxs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Text(
                AppStrings.dealerEndOfDayRecentTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(dealerShellTabIndexProvider.notifier).state = 2;
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 0,
                  ),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.copper,
                ),
                child: const Text(AppStrings.dealerEndOfDaySeeAll),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < top.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 0.6,
                    thickness: 0.6,
                    color: AppColors.borderHairline,
                  ),
                _TodayTxRow(
                  tx: top[i],
                  dealerName: dealerNameById[top[i].dealerId] ?? '—',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayTxRow extends StatelessWidget {
  const _TodayTxRow({required this.tx, required this.dealerName});

  final DealerTransaction tx;
  final String dealerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, sign) = _meta(tx.type);
    final amount = tx.amount.abs();
    final formattedAmount = '$sign${NumberFormatter.currency(amount)}'
        .replaceAll(' ', ' ');
    final hm = DateFormat('HH:mm').format(tx.createdAt);

    return InkWell(
      onTap: () => context.push('${AppRoutes.dealers}/${tx.dealerId}'),
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
                    hm,
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

class _ShareCta extends StatelessWidget {
  const _ShareCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.share_rounded),
        label: const Text(AppStrings.dealerEndOfDayShareCta),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          // Beyaz zemin üzerinde okunur koyu ink metin; lemon yalnız kenarda.
          foregroundColor: AppColors.brandInk,
          side: const BorderSide(color: AppColors.copper, width: 1.0),
        ),
      ),
    );
  }
}
