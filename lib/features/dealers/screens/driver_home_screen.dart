import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer_transaction.dart';
import '../models/driver_summary.dart';
import '../providers/dealer_providers.dart';

/// Faz 1 — Bireysel şoför PANELİ (zayıf liste değil, mini panel).
///
/// Üstte bekleyen davet kartları (varsa); altında segmentler:
/// Genel Bakış · Atanan Bayiler · Hareketlerim · Raporlarım. Yalnız kendi
/// atanan bayileri + kendi driver_id hareketleri. Owner aksiyonları YOK.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  int _seg = 0;
  static const _segments = [
    'Genel Bakış',
    'Atanan Bayiler',
    'Hareketlerim',
    'Raporlarım',
  ];

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(myDriverInvitesProvider).valueOrNull ?? const [];
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final hasPanel = assigned.isNotEmpty ||
        (ref.watch(isAssignedDriverProvider).valueOrNull ?? false);

    return PremiumScaffold(
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
            if (hasPanel) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH, vertical: AppSpacing.s),
                child: Row(children: [
                  for (var i = 0; i < _segments.length; i++) ...[
                    ChoiceChip(
                      label: Text(_segments[i]),
                      selected: _seg == i,
                      onSelected: (_) => setState(() => _seg = i),
                    ),
                    const SizedBox(width: 6),
                  ],
                ]),
              ),
              Expanded(
                child: IndexedStack(
                  index: _seg,
                  children: const [
                    _MyOverview(),
                    _MyDealers(),
                    _MyTransactions(),
                    _MyReports(),
                  ],
                ),
              ),
            ] else
              const Expanded(child: _DriverEmpty()),
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

Widget _kpi(String label, String value) => Expanded(
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );

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
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: today.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Özet yüklenemedi.'),
              data: (s) => Column(children: [
                Row(children: [
                  _kpi('Atanan bayi', '${assigned.length}'),
                  _kpi('Bugün işlem', '${s.txCount}'),
                  _kpi('Net', _tl(s.netChange)),
                ]),
                const Divider(height: AppSpacing.l),
                Row(children: [
                  _kpi('Teslimat', _tl(s.totalDelivery)),
                  _kpi('Tahsilat', _tl(s.totalPayment)),
                  _kpi('İade', _tl(s.totalReturn)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        const Text('Son Hareketlerim',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.s),
        if (recent.isEmpty)
          const _Box('Henüz işlem girmedin.')
        else
          for (final t in recent.take(5)) ...[
            _TxRow(tx: t, dealerName: names[t.dealerId] ?? 'Bayi'),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _MyDealers extends ConsumerWidget {
  const _MyDealers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    if (assigned.isEmpty) return const _Box('Sana atanmış bayi yok.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        for (final d in assigned) ...[
          PremiumCard(
            padding: EdgeInsets.zero,
            onTap: () => context.push(AppRoutes.driverDealerDetail(d.id)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(children: [
                const Icon(Icons.storefront_rounded,
                    size: 20, color: AppColors.brandLemonPressed),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textMuted),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _MyTransactions extends ConsumerWidget {
  const _MyTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(myDriverTransactionsProvider).valueOrNull ?? const [];
    final assigned =
        ref.watch(dealersAssignedToMeProvider).valueOrNull ?? const [];
    final names = {for (final d in assigned) d.id: d.name};
    if (txs.isEmpty) return const _Box('Henüz işlemin yok.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        for (final t in txs) ...[
          _TxRow(tx: t, dealerName: names[t.dealerId] ?? 'Bayi'),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

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
          AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, AppSpacing.xxl),
      children: [
        Row(children: [
          for (final r in DriverSummaryRange.values) ...[
            ChoiceChip(
              label: Text(r.label, style: const TextStyle(fontSize: 12)),
              selected: _range == r,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _range = r),
            ),
            const SizedBox(width: 6),
          ],
        ]),
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
        child: Row(children: [
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
                  color: negative ? AppColors.success : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
