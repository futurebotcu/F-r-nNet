import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_bottom_nav.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_transaction.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_filter_chip.dart';
import '../widgets/dealer_kpi_tile.dart';
import '../widgets/driver_scoped_dealer_card.dart';
import '../widgets/driver_scoped_tx_tile.dart';

/// Faz 1 / UI Hizalama (Yol B+) — Patron/toptancı bir şoföre dokununca açılan
/// ŞOFÖR-SCOPED mini Bayi Yönetimi. Normal Bayi Yönetimi shell'iyle aynı dil:
/// alt [PremiumBottomNav] + tek AppBar (şoför adı + alt metin + sağ üst owner
/// menü). Üst mekanik segment YOK; "Yönetim" ayrı tab değil — aksiyonlar
/// AppBar menüsünde ve Genel Bakış yönetim kartında.
///
/// Veri scope'u: yalnız bu şoföre atanmış bayiler + bu şoförün driver_id'li
/// hareketleri + scoped özet. Mevcut provider'lardan okur; hesap mantığı,
/// backend, owner-on-behalf write değişmez.
class DriverScopedDealerShell extends ConsumerStatefulWidget {
  const DriverScopedDealerShell({super.key, required this.driverId});
  final String driverId;

  @override
  ConsumerState<DriverScopedDealerShell> createState() =>
      _DriverScopedDealerShellState();
}

class _DriverScopedDealerShellState
    extends ConsumerState<DriverScopedDealerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(driverByIdProvider(widget.driverId)).valueOrNull;
    final isWholesaler = ref.watch(
          profileControllerProvider.select((p) => p?.accountType),
        ) ==
        AccountType.wholesaler;
    final dealersLabel = isWholesaler ? 'Müşteriler' : 'Bayiler';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(driver?.name ?? 'Şoför'),
        actions: [
          if (driver != null)
            _OwnerMenu(driverId: widget.driverId, driver: driver),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.pageH, bottom: 6, right: AppSpacing.pageH),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isWholesaler ? 'Şoför Müşteri Defteri' : 'Şoför Bayi Defteri',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _tab,
          children: [
            _OverviewSection(
              driverId: widget.driverId,
              onOpenDealers: () => setState(() => _tab = 1),
              onOpenActivity: () => setState(() => _tab = 2),
            ),
            _ScopedDealersSection(driverId: widget.driverId),
            _ScopedTransactionsSection(driverId: widget.driverId),
            _ScopedReportsSection(driverId: widget.driverId),
          ],
        ),
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: _tab,
        onSelect: (i) => setState(() => _tab = i),
        items: [
          const PremiumNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: AppStrings.dealerShellTabOverview,
          ),
          PremiumNavItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: dealersLabel,
          ),
          const PremiumNavItem(
            icon: Icons.swap_vert_outlined,
            activeIcon: Icons.swap_vert_rounded,
            label: AppStrings.dealerShellTabActivity,
          ),
          const PremiumNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics_rounded,
            label: AppStrings.dealerShellTabReports,
          ),
        ],
      ),
    );
  }
}

Color _netColor(double net) {
  if (net == 0) return AppColors.textMuted;
  return net > 0 ? AppColors.copper : AppColors.success;
}

/// Sağ üst owner aksiyon menüsü — eski "Yönetim" segmentinin yerine.
class _OwnerMenu extends ConsumerWidget {
  const _OwnerMenu({required this.driverId, required this.driver});
  final String driverId;
  final DealerDriver driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'Yönetim',
      onSelected: (value) async {
        switch (value) {
          case 'assign':
            context.push(AppRoutes.dealerDriverAssign(driverId));
            break;
          case 'toggle':
            await ref
                .read(dealerRepositoryProvider)
                .updateDriver(driver.copyWith(isActive: !driver.isActive));
            ref.invalidate(driverByIdProvider(driverId));
            ref.invalidate(driversListProvider);
            break;
          case 'info':
            if (context.mounted) _showDriverInfo(context, driver);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'assign',
          child: Row(children: [
            Icon(Icons.edit_location_alt_outlined,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: AppSpacing.s),
            Flexible(child: Text('Bayi ata / atamaları yönet')),
          ]),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(children: [
            Icon(
              driver.isActive
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s),
            Flexible(
              child: Text(
                  driver.isActive ? 'Şoförü pasife al' : 'Şoförü aktifleştir'),
            ),
          ]),
        ),
        const PopupMenuItem(
          value: 'info',
          child: Row(children: [
            Icon(Icons.person_outline_rounded,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: AppSpacing.s),
            Flexible(child: Text('Şoför bilgisi')),
          ]),
        ),
      ],
    );
  }

  void _showDriverInfo(BuildContext context, DealerDriver driver) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.s),
              _InfoRow(
                icon: driver.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                label: driver.isActive ? 'Aktif' : 'Pasif',
              ),
              if (driver.phone.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, label: driver.phone),
              if (driver.note.isNotEmpty)
                _InfoRow(icon: Icons.notes_rounded, label: driver.note),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Genel Bakış ───────────────────────────────────────────────────────────

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({
    required this.driverId,
    required this.onOpenDealers,
    required this.onOpenActivity,
  });
  final String driverId;
  final VoidCallback onOpenDealers;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(driverRangeSummaryProvider(
        (driverId: driverId, range: DriverSummaryRange.today)));
    final ids =
        ref.watch(assignedDealerIdsProvider(driverId)).valueOrNull ?? const [];
    final recent =
        ref.watch(driverRecentTransactionsProvider(driverId)).valueOrNull ??
            const [];
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final dealerById = {for (final d in dealers) d.id: d};
    final nameById = {for (final d in dealers) d.id: d.name};
    final lastTxByDealer = <String, DealerTransaction>{};
    for (final t in recent) {
      lastTxByDealer.putIfAbsent(t.dealerId, () => t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        today.when(
          loading: () => const _CardSpinner(),
          error: (_, __) => const _ErrorCard('Özet yüklenemedi.'),
          data: (s) => _OverviewKpis(assignedCount: ids.length, summary: s),
        ),
        const SizedBox(height: AppSpacing.l),
        // Doğal yönetim kartı (ekranı boğmaz).
        PremiumCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push(AppRoutes.dealerDriverAssign(driverId)),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Row(children: [
              Icon(Icons.edit_location_alt_outlined,
                  size: 20, color: AppColors.brandLemonPressed),
              SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text('Bayi ata / atamaları yönet',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        // Atanan bayiler kısa listesi.
        _SectionHeader(
          title: 'ATANAN BAYİLER',
          actionLabel: ids.length > 3 ? 'Tümünü gör' : null,
          onAction: onOpenDealers,
        ),
        const SizedBox(height: AppSpacing.s),
        if (ids.isEmpty)
          const _EmptyBox('Bu şoföre henüz bayi atanmadı.')
        else
          for (final id in ids.take(3))
            if (dealerById[id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: DriverScopedDealerCard(
                  dealer: dealerById[id]!,
                  balance:
                      ref.watch(balanceSummaryProvider(id)).valueOrNull,
                  lastTx: lastTxByDealer[id],
                  onTap: () => context.push('${AppRoutes.dealers}/$id'),
                ),
              ),
        const SizedBox(height: AppSpacing.l),
        // Son hareketler.
        _SectionHeader(
          title: 'SON HAREKETLER',
          actionLabel: recent.isNotEmpty ? 'Tümünü gör' : null,
          onAction: onOpenActivity,
        ),
        const SizedBox(height: AppSpacing.s),
        if (recent.isEmpty)
          const _EmptyBox('Bu şoförün henüz işlemi yok.')
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.take(5).length; i++) ...[
                  DriverScopedTxTile(
                    tx: recent[i],
                    dealerName: nameById[recent[i].dealerId] ?? '—',
                    onTap: () =>
                        context.push('${AppRoutes.dealers}/${recent[i].dealerId}'),
                  ),
                  if (i < recent.take(5).length - 1)
                    const Divider(
                        height: 0.6,
                        thickness: 0.6,
                        color: AppColors.borderHairline),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _OverviewKpis extends StatelessWidget {
  const _OverviewKpis({required this.assignedCount, required this.summary});
  final int assignedCount;
  final DriverRangeSummary summary;

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
              label: 'Atanan bayi',
              value: NumberFormatter.integer(assignedCount),
              accent: AppColors.softGold,
              isCount: true,
            ),
            DealerKpiTile(
              label: 'Bugün teslimat',
              value: NumberFormatter.currency(summary.totalDelivery),
              accent: AppColors.copper,
            ),
            DealerKpiTile(
              label: 'Bugün tahsilat',
              value: NumberFormatter.currency(summary.totalPayment),
              accent: AppColors.success,
            ),
            DealerKpiTile(
              label: 'Bugün işlem',
              value: NumberFormatter.integer(summary.txCount),
              accent: AppColors.textSecondary,
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        DealerKpiTile(
          label: 'Bugün net değişim',
          value: NumberFormatter.currency(summary.netChange),
          accent: _netColor(summary.netChange),
          emphasized: true,
          fullWidth: true,
        ),
      ],
    );
  }
}

// ── Bayiler ─────────────────────────────────────────────────────────────────

class _ScopedDealersSection extends ConsumerWidget {
  const _ScopedDealersSection({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(assignedDealerIdsProvider(driverId));
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final dealerById = {for (final d in dealers) d.id: d};
    final recent =
        ref.watch(driverRecentTransactionsProvider(driverId)).valueOrNull ??
            const [];
    final lastTxByDealer = <String, DealerTransaction>{};
    for (final t in recent) {
      lastTxByDealer.putIfAbsent(t.dealerId, () => t);
    }

    return idsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Yüklenemedi.')),
      data: (ids) {
        if (ids.isEmpty) {
          return const _EmptyBox('Bu şoföre henüz bayi atanmadı.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.xxl),
          children: [
            for (final id in ids)
              if (dealerById[id] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: DriverScopedDealerCard(
                    dealer: dealerById[id]!,
                    balance: ref.watch(balanceSummaryProvider(id)).valueOrNull,
                    lastTx: lastTxByDealer[id],
                    onTap: () => context.push('${AppRoutes.dealers}/$id'),
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ── Hareketler ──────────────────────────────────────────────────────────────

class _ScopedTransactionsSection extends ConsumerStatefulWidget {
  const _ScopedTransactionsSection({required this.driverId});
  final String driverId;

  @override
  ConsumerState<_ScopedTransactionsSection> createState() =>
      _ScopedTransactionsSectionState();
}

class _ScopedTransactionsSectionState
    extends ConsumerState<_ScopedTransactionsSection> {
  DealerTransactionType? _filter;

  @override
  Widget build(BuildContext context) {
    final txAsync =
        ref.watch(driverRecentTransactionsProvider(widget.driverId));
    final dealers = ref.watch(dealersListProvider).valueOrNull ?? const [];
    final nameById = {for (final d in dealers) d.id: d.name};

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Hareketler yüklenemedi.')),
      data: (txs) {
        if (txs.isEmpty) {
          return const _EmptyBox('Bu şoförün hareketi yok.');
        }
        final counts = <DealerTransactionType, int>{
          for (final t in DealerTransactionType.values) t: 0,
        };
        for (final t in txs) {
          counts[t.type] = (counts[t.type] ?? 0) + 1;
        }
        final filtered =
            _filter == null ? txs : txs.where((t) => t.type == _filter).toList();

        return Column(
          children: [
            _TxFilterRow(
              selected: _filter,
              total: txs.length,
              counts: counts,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyBox('Bu filtrede hareket yok.')
                  : DriverScopedTxList(
                      txs: filtered,
                      dealerNames: nameById,
                      onTapTx: (t) =>
                          context.push('${AppRoutes.dealers}/${t.dealerId}'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TxFilterRow extends StatelessWidget {
  const _TxFilterRow({
    required this.selected,
    required this.total,
    required this.counts,
    required this.onChanged,
  });

  final DealerTransactionType? selected;
  final int total;
  final Map<DealerTransactionType, int> counts;
  final ValueChanged<DealerTransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        children: [
          DealerFilterChip(
            label: '${AppStrings.dealerTxFilterTypeAll} ($total)',
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final t in DealerTransactionType.values) ...[
            const SizedBox(width: 8),
            DealerFilterChip(
              label: '${t.label} (${counts[t] ?? 0})',
              selected: selected == t,
              onSelected: (_) => onChanged(t),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Raporlar ────────────────────────────────────────────────────────────────

class _ScopedReportsSection extends ConsumerStatefulWidget {
  const _ScopedReportsSection({required this.driverId});
  final String driverId;

  @override
  ConsumerState<_ScopedReportsSection> createState() =>
      _ScopedReportsSectionState();
}

class _ScopedReportsSectionState extends ConsumerState<_ScopedReportsSection> {
  DriverSummaryRange _range = DriverSummaryRange.today;

  @override
  Widget build(BuildContext context) {
    final sum = ref.watch(driverRangeSummaryProvider(
        (driverId: widget.driverId, range: _range)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final r in DriverSummaryRange.values)
              DealerFilterChip(
                label: r.label,
                selected: _range == r,
                onSelected: (s) {
                  if (s) setState(() => _range = r);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        const _SectionHeader(title: 'ÖZET'),
        const SizedBox(height: AppSpacing.s),
        sum.when(
          loading: () => const _CardSpinner(),
          error: (_, __) => const _ErrorCard('Rapor yüklenemedi.'),
          data: (s) => s.txCount == 0
              ? const _EmptyBox('Bu dönemde işlem yok.')
              : _ReportsKpiBlock(summary: s),
        ),
      ],
    );
  }
}

class _ReportsKpiBlock extends StatelessWidget {
  const _ReportsKpiBlock({required this.summary});
  final DriverRangeSummary summary;

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
              label: 'Teslimat',
              value: NumberFormatter.currency(summary.totalDelivery),
              accent: AppColors.softGold,
            ),
            DealerKpiTile(
              label: 'İade',
              value: NumberFormatter.currency(summary.totalReturn),
              accent: AppColors.textSecondary,
            ),
            DealerKpiTile(
              label: 'Tahsilat',
              value: NumberFormatter.currency(summary.totalPayment),
              accent: AppColors.success,
            ),
            DealerKpiTile(
              label: 'İşlem adedi',
              value: NumberFormatter.integer(summary.txCount),
              accent: AppColors.textSecondary,
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        DealerKpiTile(
          label: 'Net değişim',
          value: NumberFormatter.currency(summary.netChange),
          accent: _netColor(summary.netChange),
          emphasized: true,
          fullWidth: true,
        ),
      ],
    );
  }
}

// ── Ortak küçük parçalar ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.6,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: AppColors.brandLemonPressed,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _CardSpinner extends StatelessWidget {
  const _CardSpinner();
  @override
  Widget build(BuildContext context) => const PremiumCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.l),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Text(text,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
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
