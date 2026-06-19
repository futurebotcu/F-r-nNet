import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer.dart';
import '../models/dealer_transaction.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';

/// Şoför detayı (Sprint 2): bilgiler + aktif/pasif + atanmış bayiler + "Bayi Ata".
/// İşlem özeti Sprint 3'te aktif olacak (driver_id bu sprintte yazılmıyor) →
/// placeholder.
class DriverDetailScreen extends ConsumerWidget {
  const DriverDetailScreen({super.key, required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByIdProvider(driverId));
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text('Şoför'),
        actions: [
          IconButton(
            tooltip: 'Bayileri Düzenle',
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: () =>
                context.push(AppRoutes.dealerDriverAssign(driverId)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: driverAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Şoför yüklenemedi.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (driver) {
            if (driver == null) {
              return const Center(
                child: Text('Şoför bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                // ── Bilgi kartı + aktif/pasif ──
                PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (driver.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(driver.phone,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (driver.note.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s),
                          Text(driver.note,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4)),
                        ],
                        const SizedBox(height: AppSpacing.s),
                        Row(
                          children: [
                            const Text('Aktif',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            Switch(
                              value: driver.isActive,
                              onChanged: (v) async {
                                await ref
                                    .read(dealerRepositoryProvider)
                                    .updateDriver(
                                        driver.copyWith(isActive: v));
                                ref.invalidate(driverByIdProvider(driverId));
                                ref.invalidate(driversListProvider);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),

                // ── Atanmış bayiler ──
                Row(
                  children: [
                    const Text('Atanmış Bayiler',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context
                          .push(AppRoutes.dealerDriverAssign(driverId)),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Bayi Ata'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _AssignedDealers(driverId: driverId),

                const SizedBox(height: AppSpacing.l),

                // ── İşlem özeti + son işlemler (Sprint 5) ──
                _DriverSummarySection(driverId: driverId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssignedDealers extends ConsumerWidget {
  const _AssignedDealers({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(assignedDealerIdsProvider(driverId));
    final dealersAsync = ref.watch(dealersListProvider);
    return idsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Atamalar yüklenemedi.',
          style: TextStyle(color: AppColors.textSecondary)),
      data: (ids) {
        if (ids.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: const Text(
              'Henüz bayi atanmadı. "Bayi Ata" ile kendi bayilerinden seç.',
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600),
            ),
          );
        }
        final dealers = dealersAsync.valueOrNull ?? const <Dealer>[];
        final byId = {for (final d in dealers) d.id: d};
        return Column(
          children: [
            for (final id in ids)
              PremiumCard(
                padding: EdgeInsets.zero,
                onTap: () => context.push('${AppRoutes.dealers}/$id'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          byId[id]?.name ?? 'Bayi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _tl(double v) => '₺${v.toStringAsFixed(0)}';

String _shortDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd.$mm $hh:$mi';
}

/// Patron şoför detayı — gerçek özet (tarih filtreli) + son işlemler (Sprint 5).
class _DriverSummarySection extends ConsumerStatefulWidget {
  const _DriverSummarySection({required this.driverId});
  final String driverId;

  @override
  ConsumerState<_DriverSummarySection> createState() =>
      _DriverSummarySectionState();
}

class _DriverSummarySectionState
    extends ConsumerState<_DriverSummarySection> {
  DriverSummaryRange _range = DriverSummaryRange.today;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(driverRangeSummaryProvider(
        (driverId: widget.driverId, range: _range)));
    final recentAsync =
        ref.watch(driverRecentTransactionsProvider(widget.driverId));
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final byId = {for (final d in dealers) d.id: d.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('İşlem Özeti',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            for (final r in DriverSummaryRange.values) ...[
              ChoiceChip(
                label: Text(r.label,
                    style: const TextStyle(fontSize: 11.5)),
                selected: _range == r,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _range = r),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) => PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  Row(children: [
                    _kpi('İşlem', '${s.txCount}'),
                    _kpi('Net', _tl(s.netChange)),
                    _kpi('Teslimat', _tl(s.totalDelivery)),
                  ]),
                  const Divider(height: AppSpacing.l),
                  Row(children: [
                    _kpi('Tahsilat', _tl(s.totalPayment)),
                    _kpi('İade', _tl(s.totalReturn)),
                    _kpi('Bayi', '${s.assignedDealerCount}'),
                  ]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        const Text('Son İşlemler',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.s),
        recentAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Text('Hareketler yüklenemedi.',
              style: TextStyle(color: AppColors.textSecondary)),
          data: (txs) {
            if (txs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border:
                      Border.all(color: AppColors.borderHairline, width: 0.8),
                ),
                child: const Text('Bu aralıkta işlem yok.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              );
            }
            return Column(
              children: [
                for (final t in txs) ...[
                  _DriverTxRow(tx: t, dealerName: byId[t.dealerId] ?? 'Bayi'),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kpi(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _DriverTxRow extends StatelessWidget {
  const _DriverTxRow({required this.tx, required this.dealerName});
  final DealerTransaction tx;
  final String dealerName;

  @override
  Widget build(BuildContext context) {
    final negative = tx.type == DealerTransactionType.payment ||
        tx.type == DealerTransactionType.returned;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$dealerName · ${tx.type.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    tx.note.isNotEmpty
                        ? '${_shortDate(tx.createdAt)} · ${tx.note}'
                        : _shortDate(tx.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              '${negative ? '−' : '+'}${_tl(tx.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: negative ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
