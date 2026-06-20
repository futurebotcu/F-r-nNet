import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_transaction.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';
import 'add_driver_screen.dart';

/// Faz 1 — Patron/toptancı: bir şoföre dokununca açılan ŞOFÖR-SCOPED mini Bayi
/// Yönetimi (tek defter, scoped görünüm). Sadece o şoföre atanmış bayiler + o
/// şoförün driver_id'li hareketleri + scoped özet + yönetim yardımcıları.
/// Mevcut provider'lardan okur; backend/yazma yok (owner-on-behalf Faz 2).
class DriverScopedDealerShell extends ConsumerStatefulWidget {
  const DriverScopedDealerShell({super.key, required this.driverId});
  final String driverId;

  @override
  ConsumerState<DriverScopedDealerShell> createState() =>
      _DriverScopedDealerShellState();
}

class _DriverScopedDealerShellState
    extends ConsumerState<DriverScopedDealerShell> {
  int _seg = 0;
  static const _segments = [
    'Genel Bakış',
    'Bayiler',
    'Hareketler',
    'Raporlar',
    'Yönetim',
  ];

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(driverByIdProvider(widget.driverId)).valueOrNull;
    final isWholesaler = ref.watch(
          profileControllerProvider.select((p) => p?.accountType),
        ) ==
        AccountType.wholesaler;
    return PremiumScaffold(
      appBar: AppBar(
        title: Text(driver?.name ?? 'Şoför'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.pageH, bottom: 6, right: AppSpacing.pageH),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isWholesaler ? 'Şoför Müşteri Defteri' : 'Şoför Bayi Defteri',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH, vertical: AppSpacing.s),
              child: Row(
                children: [
                  for (var i = 0; i < _segments.length; i++) ...[
                    ChoiceChip(
                      label: Text(_segments[i]),
                      selected: _seg == i,
                      onSelected: (_) => setState(() => _seg = i),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _seg,
                children: [
                  _OverviewSection(driverId: widget.driverId),
                  _ScopedDealersSection(driverId: widget.driverId),
                  _ScopedTransactionsSection(driverId: widget.driverId),
                  _ScopedReportsSection(driverId: widget.driverId),
                  _ManagementSection(driverId: widget.driverId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _tl(double v) => '₺${v.toStringAsFixed(0)}';

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Yetki seviyeleri bilgi popup'ı (AddDriverScreen ile aynı metinler).
void _showDriverPermissionInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.pageH, 0, AppSpacing.pageH, AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yarı Yetki',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(AddDriverScreen.halfPermissionInfo,
                style: TextStyle(fontSize: 13, height: 1.4)),
            SizedBox(height: AppSpacing.m),
            Text('Tam Yetki',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(AddDriverScreen.fullPermissionInfo,
                style: TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    ),
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(driverRangeSummaryProvider(
        (driverId: driverId, range: DriverSummaryRange.today)));
    final ids = ref.watch(assignedDealerIdsProvider(driverId)).valueOrNull ??
        const [];
    final recent =
        ref.watch(driverRecentTransactionsProvider(driverId)).valueOrNull ??
            const [];
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final byId = {for (final d in dealers) d.id: d.name};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: today.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Özet yüklenemedi.'),
              data: (s) => Column(
                children: [
                  Row(children: [
                    _kpi('Atanan bayi', '${ids.length}'),
                    _kpi('Bugün işlem', '${s.txCount}'),
                    _kpi('Net', _tl(s.netChange)),
                  ]),
                  const Divider(height: AppSpacing.l),
                  Row(children: [
                    _kpi('Teslimat', _tl(s.totalDelivery)),
                    _kpi('Tahsilat', _tl(s.totalPayment)),
                    _kpi('İade', _tl(s.totalReturn)),
                  ]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        // Yönetim yardımcı kartı.
        PremiumCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push(AppRoutes.dealerDriverAssign(driverId)),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Row(children: [
              Icon(Icons.edit_location_alt_outlined,
                  size: 18, color: AppColors.brandLemonPressed),
              SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text('Bayi ata / atamaları yönet',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        const Text('Son Hareketler',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.s),
        if (recent.isEmpty)
          const _EmptyBox('Bu şoförün henüz işlemi yok.')
        else
          for (final t in recent.take(5)) ...[
            _TxRow(tx: t, dealerName: byId[t.dealerId] ?? 'Bayi'),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _ScopedDealersSection extends ConsumerWidget {
  const _ScopedDealersSection({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(assignedDealerIdsProvider(driverId));
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final byId = {for (final d in dealers) d.id: d};
    return idsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Yüklenemedi.')),
      data: (ids) {
        if (ids.isEmpty) {
          return const _EmptyBox('Bu şoföre henüz bayi atanmadı.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
          children: [
            for (final id in ids) ...[
              _ScopedDealerCard(dealer: byId[id], dealerId: id),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _ScopedDealerCard extends ConsumerWidget {
  const _ScopedDealerCard({required this.dealer, required this.dealerId});
  final Dealer? dealer;
  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bal = ref.watch(balanceSummaryProvider(dealerId)).valueOrNull;
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('${AppRoutes.dealers}/$dealerId'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(dealer?.name ?? 'Bayi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            if (bal != null)
              Text(_tl(bal.currentBalance),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: bal.currentBalance > 0
                          ? AppColors.danger
                          : AppColors.textPrimary)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ScopedTransactionsSection extends ConsumerWidget {
  const _ScopedTransactionsSection({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(driverRecentTransactionsProvider(driverId));
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final byId = {for (final d in dealers) d.id: d.name};
    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Hareketler yüklenemedi.')),
      data: (txs) {
        if (txs.isEmpty) {
          return const _EmptyBox('Bu şoförün hareketi yok.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
          children: [
            for (final t in txs) ...[
              _TxRow(tx: t, dealerName: byId[t.dealerId] ?? 'Bayi'),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _ScopedReportsSection extends ConsumerStatefulWidget {
  const _ScopedReportsSection({required this.driverId});
  final String driverId;

  @override
  ConsumerState<_ScopedReportsSection> createState() =>
      _ScopedReportsSectionState();
}

class _ScopedReportsSectionState
    extends ConsumerState<_ScopedReportsSection> {
  DriverSummaryRange _range = DriverSummaryRange.today;

  @override
  Widget build(BuildContext context) {
    final sum = ref.watch(driverRangeSummaryProvider(
        (driverId: widget.driverId, range: _range)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        Row(
          children: [
            for (final r in DriverSummaryRange.values) ...[
              ChoiceChip(
                label: Text(r.label, style: const TextStyle(fontSize: 12)),
                selected: _range == r,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _range = r),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        sum.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Rapor yüklenemedi.'),
          data: (s) => PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(children: [
                Row(children: [
                  _kpi('İşlem', '${s.txCount}'),
                  _kpi('Net', _tl(s.netChange)),
                  _kpi('Teslimat', _tl(s.totalDelivery)),
                ]),
                const Divider(height: AppSpacing.l),
                Row(children: [
                  _kpi('Tahsilat', _tl(s.totalPayment)),
                  _kpi('İade', _tl(s.totalReturn)),
                  _kpi('Düzeltme', _tl(s.totalAdjustment)),
                ]),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagementSection extends ConsumerWidget {
  const _ManagementSection({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverAsync = ref.watch(driverByIdProvider(driverId));
    return driverAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Şoför yüklenemedi.')),
      data: (driver) {
        if (driver == null) {
          return const Center(child: Text('Şoför bulunamadı.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
          children: [
            PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name,
                        style: const TextStyle(
                            fontSize: 16,
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
                    Row(children: [
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
                              .updateDriver(driver.copyWith(isActive: v));
                          ref.invalidate(driverByIdProvider(driverId));
                          ref.invalidate(driversListProvider);
                        },
                      ),
                    ]),
                    // Yarı/Tam yetki — patron mevcut şoförü düzenler
                    // (feature/dealer-driver-permission-levels yüzey düzeltmesi).
                    const SizedBox(height: AppSpacing.s),
                    Row(children: [
                      const Text('Yetki',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.info_outline, size: 18),
                        tooltip: 'Yetki seviyeleri',
                        onPressed: () => _showDriverPermissionInfo(context),
                      ),
                      const Spacer(),
                      SegmentedButton<DriverPermission>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment(
                              value: DriverPermission.half,
                              label: Text('Yarı')),
                          ButtonSegment(
                              value: DriverPermission.full,
                              label: Text('Tam')),
                        ],
                        selected: {driver.permissionLevel},
                        onSelectionChanged: (s) async {
                          try {
                            await ref
                                .read(dealerRepositoryProvider)
                                .updateDriver(driver.copyWith(
                                    permissionLevel: s.first));
                            ref.invalidate(driverByIdProvider(driverId));
                            ref.invalidate(driversListProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e is StateError
                                      ? e.message
                                      : 'Yetki güncellenemedi.'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.dealerDriverAssign(driverId)),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Bayi Ata / Atamaları Yönet'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandLemon,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.dealerName});
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
                  Text(_shortDate(tx.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text('${negative ? '−' : '+'}${_tl(tx.amount)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        negative ? AppColors.success : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600)),
    );
  }
}
