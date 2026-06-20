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
import '../models/dealer_transaction.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_filter_chip.dart';
import '../widgets/dealer_kpi_tile.dart';
import '../widgets/driver_scoped_dealer_card.dart';
import '../widgets/driver_scoped_tx_tile.dart';

/// Faz 1 / UI Hizalama (Yol B+) — Bireysel şoför PANELİ. Normal Bayi
/// Yönetimi diliyle hizalı: alt [PremiumBottomNav] + 4 tab (Genel Bakış ·
/// Atanan Bayiler · Hareketlerim · Raporlarım). Yalnız kendi atanan
/// bayileri + kendi driver_id hareketleri. Owner aksiyonları YOK; davet
/// kartı ve boş durum korunur.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(myDriverInvitesProvider).valueOrNull ?? const [];
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final hasPanel = assigned.isNotEmpty ||
        (ref.watch(isAssignedDriverProvider).valueOrNull ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Şoför Paneli'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(left: AppSpacing.pageH, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sana atanan bayiler ve işlemlerin',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (invites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, 0),
                child: const _MyInvites(),
              ),
            if (hasPanel)
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    _MyOverview(),
                    _MyDealers(),
                    _MyTransactions(),
                    _MyReports(),
                  ],
                ),
              )
            else
              const Expanded(child: _DriverEmpty()),
          ],
        ),
      ),
      bottomNavigationBar: hasPanel
          ? PremiumBottomNav(
              selectedIndex: _tab,
              onSelect: (i) => setState(() => _tab = i),
              items: const [
                PremiumNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: AppStrings.dealerShellTabOverview,
                ),
                PremiumNavItem(
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  label: 'Atanan Bayiler',
                ),
                PremiumNavItem(
                  icon: Icons.swap_vert_outlined,
                  activeIcon: Icons.swap_vert_rounded,
                  label: 'Hareketlerim',
                ),
                PremiumNavItem(
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Raporlarım',
                ),
              ],
            )
          : null,
    );
  }
}

Color _netColor(double net) {
  if (net == 0) return AppColors.textMuted;
  return net > 0 ? AppColors.copper : AppColors.success;
}

// ── Genel Bakış ───────────────────────────────────────────────────────────

class _MyOverview extends ConsumerWidget {
  const _MyOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today =
        ref.watch(myDriverRangeSummaryProvider(DriverSummaryRange.today));
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final recent =
        ref.watch(myDriverTransactionsProvider).valueOrNull ?? const [];
    final names = {for (final d in assigned) d.id: d.name};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        today.when(
          loading: () => const _CardSpinner(),
          error: (_, __) => const _ErrorCard('Özet yüklenemedi.'),
          data: (s) => _MyKpis(assignedCount: assigned.length, summary: s),
        ),
        const SizedBox(height: AppSpacing.l),
        const Text('SON HAREKETLERİM',
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.6)),
        const SizedBox(height: AppSpacing.s),
        if (recent.isEmpty)
          const _Box('Henüz işlem girmedin.')
        else
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.take(5).length; i++) ...[
                  DriverScopedTxTile(
                    tx: recent[i],
                    dealerName: names[recent[i].dealerId] ?? '—',
                    onTap: () => context
                        .push(AppRoutes.driverDealerDetail(recent[i].dealerId)),
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

class _MyKpis extends StatelessWidget {
  const _MyKpis({required this.assignedCount, required this.summary});
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

// ── Atanan Bayiler ──────────────────────────────────────────────────────────

class _MyDealers extends ConsumerWidget {
  const _MyDealers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final recent =
        ref.watch(myDriverTransactionsProvider).valueOrNull ?? const [];
    final lastTxByDealer = <String, DealerTransaction>{};
    for (final t in recent) {
      lastTxByDealer.putIfAbsent(t.dealerId, () => t);
    }
    if (assigned.isEmpty) return const _Box('Sana atanmış bayi yok.');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.m, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        for (final d in assigned)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: DriverScopedDealerCard(
              dealer: d,
              balance: ref.watch(balanceSummaryProvider(d.id)).valueOrNull,
              lastTx: lastTxByDealer[d.id],
              onTap: () => context.push(AppRoutes.driverDealerDetail(d.id)),
            ),
          ),
      ],
    );
  }
}

// ── Hareketlerim ────────────────────────────────────────────────────────────

class _MyTransactions extends ConsumerWidget {
  const _MyTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(myDriverTransactionsProvider).valueOrNull ?? const [];
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final names = {for (final d in assigned) d.id: d.name};
    if (txs.isEmpty) return const _Box('Henüz işlemin yok.');

    return DriverScopedTxList(
      txs: txs,
      dealerNames: names,
      onTapTx: (t) => context.push(AppRoutes.driverDealerDetail(t.dealerId)),
    );
  }
}

// ── Raporlarım ──────────────────────────────────────────────────────────────

class _MyReports extends ConsumerStatefulWidget {
  const _MyReports();
  @override
  ConsumerState<_MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends ConsumerState<_MyReports> {
  DriverSummaryRange _range = DriverSummaryRange.today;

  @override
  Widget build(BuildContext context) {
    final sum = ref.watch(myDriverRangeSummaryProvider(_range));
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
        const Text('ÖZET',
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.6)),
        const SizedBox(height: AppSpacing.s),
        sum.when(
          loading: () => const _CardSpinner(),
          error: (_, __) => const _ErrorCard('Rapor yüklenemedi.'),
          data: (s) => s.txCount == 0
              ? const _Box('Bu dönemde işlem yok.')
              : _MyReportsKpiBlock(summary: s),
        ),
      ],
    );
  }
}

class _MyReportsKpiBlock extends StatelessWidget {
  const _MyReportsKpiBlock({required this.summary});
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

class _Box extends StatelessWidget {
  const _Box(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600)),
    );
  }
}

/// Şoföre gelen bekleyen davetler — Kabul/Reddet. Boşsa görünmez.
class _MyInvites extends ConsumerWidget {
  const _MyInvites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myDriverInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final inv in invites)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s),
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.brandLemonPale,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.ownerName.isNotEmpty
                      ? '${inv.ownerName} seni şoför olarak eklemek istiyor'
                      : 'Bir işletme seni şoför olarak eklemek istiyor',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandInk,
                      height: 1.35),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _respond(ref, inv.id, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandLemon,
                        foregroundColor: AppColors.brandInk,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      child: const Text('Kabul Et'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  OutlinedButton(
                    onPressed: () => _respond(ref, inv.id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderHairline),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: const Text('Reddet'),
                  ),
                ]),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _respond(WidgetRef ref, String inviteId, bool accept) async {
    await ref
        .read(dealerRepositoryProvider)
        .respondDriverInvite(inviteId, accept: accept);
    ref.invalidate(myDriverInvitesProvider);
    ref.invalidate(isAssignedDriverProvider);
    ref.invalidate(dealersAssignedToMeProvider);
  }
}

class _DriverEmpty extends StatelessWidget {
  const _DriverEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: AppColors.softGold, size: 26),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text('Henüz sana atanmış bayi yok',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Fırın/işletme sana davet gönderip bayi atadığında burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
