import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';

/// Şoförler — Genel Hesap (Sprint 5). Tüm şoförlerin seçili aralıktaki özeti +
/// şoför bazlı kırılım. Kaynak: tek defter (dealer_transactions, driver_id
/// filtreli). Yeni hesap kuralı yok.
class DriverGeneralSummaryScreen extends ConsumerStatefulWidget {
  const DriverGeneralSummaryScreen({super.key});

  @override
  ConsumerState<DriverGeneralSummaryScreen> createState() =>
      _DriverGeneralSummaryScreenState();
}

class _DriverGeneralSummaryScreenState
    extends ConsumerState<DriverGeneralSummaryScreen> {
  DriverSummaryRange _range = DriverSummaryRange.today;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driversGeneralSummaryProvider(_range));
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Genel Hesap')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.s),
              child: Row(
                children: [
                  for (final r in DriverSummaryRange.values) ...[
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                    const SizedBox(width: AppSpacing.s),
                  ],
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('Özet yüklenemedi.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                data: (s) => ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.pageH, 0,
                      AppSpacing.pageH, AppSpacing.xxl),
                  children: [
                    _SummaryCard(s: s),
                    const SizedBox(height: AppSpacing.m),
                    const Text('Şoför Kırılımı',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: AppSpacing.s),
                    if (s.txCount == 0 && s.perDriver.every((d) => d.txCount == 0))
                      _empty()
                    else
                      for (final d in s.perDriver) ...[
                        _DriverBreakdownRow(d: d),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.borderHairline, width: 0.8),
        ),
        child: const Text('Bu aralıkta şoför işlemi yok.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
      );
}

String _tl(double v) => '₺${v.toStringAsFixed(0)}';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.s});
  final DriversGeneralSummary s;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              children: [
                _kpi('Şoför', '${s.activeDrivers}/${s.totalDrivers}'),
                _kpi('İşlem', '${s.txCount}'),
                _kpi('Net', _tl(s.netChange)),
              ],
            ),
            const Divider(height: AppSpacing.l),
            Row(
              children: [
                _kpi('Teslimat', _tl(s.totalDelivery)),
                _kpi('Tahsilat', _tl(s.totalPayment)),
                _kpi('İade', _tl(s.totalReturn)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _DriverBreakdownRow extends StatelessWidget {
  const _DriverBreakdownRow({required this.d});
  final DriverRangeSummary d;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.dealerDriver(d.driverId)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                if (!d.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text('Pasif',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${d.assignedDealerCount} bayi · ${d.txCount} işlem · Net ${_tl(d.netChange)}',
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Teslimat ${_tl(d.totalDelivery)} · Tahsilat ${_tl(d.totalPayment)} · İade ${_tl(d.totalReturn)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
