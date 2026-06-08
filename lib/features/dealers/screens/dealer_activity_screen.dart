import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_filter_chip.dart';

/// Bayi Defteri Hareketler tab içeriği (Sprint Activity).
///
/// Tüm bayilerin tüm tx'leri tek listede; tarih bucket'larına göre
/// gruplanır (Bugün / Dün / Bu hafta / Daha eski). Filtre chipleri
/// (Tümü/Teslimat/İade/Tahsilat/Düzeltme) + bayi adı search.
///
/// Backend dokunmaz: mevcut `allTransactionsProvider` (Sprint 6B) +
/// `dealersListProvider` üzerinden Dart-side filter+group. Satır
/// tap'i ilgili bayi detail'ine push eder.
class DealerActivityScreen extends ConsumerStatefulWidget {
  const DealerActivityScreen({super.key});

  @override
  ConsumerState<DealerActivityScreen> createState() =>
      _DealerActivityScreenState();
}

class _DealerActivityScreenState extends ConsumerState<DealerActivityScreen> {
  _TxFilter _filter = _TxFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(allTransactionsProvider);
    final dealersAsync = ref.watch(dealersListProvider);

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerActivityTitle)),
      body: SafeArea(
        top: false,
        child: txsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const Center(child: Text(AppStrings.dealersErrorLoad)),
          data: (txs) {
            final dealerNameById = dealersAsync.maybeWhen(
              data: (list) => {for (final d in list) d.id: d.name},
              orElse: () => <String, String>{},
            );
            return _buildContent(txs, dealerNameById);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<DealerTransaction> allTxs,
    Map<String, String> dealerNameById,
  ) {
    // Hiç tx yok → empty state
    if (allTxs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: EmptyState(
          title: AppStrings.dealerActivityEmptyTitle,
          subtitle: AppStrings.dealerActivityEmptyBody,
          icon: Icons.history_outlined,
        ),
      );
    }

    // Tip başına count (filter chip'lerinde gösterilir)
    final typeCounts = _countByType(allTxs);

    // Filter + search uygula
    final filtered = _applyFilter(allTxs, dealerNameById);

    // Grup
    final groups = _groupByDate(filtered);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppStrings.dealerActivitySearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        _FilterChipRow(
          filter: _filter,
          counts: typeCounts,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: EmptyState(
                    title: AppStrings.dealerActivityNoMatchTitle,
                    subtitle: AppStrings.dealerActivityNoMatchBody,
                    icon: Icons.search_off_rounded,
                    compact: true,
                  ),
                )
              : _buildGroupedList(groups, dealerNameById),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    List<_DateGroup> groups,
    Map<String, String> dealerNameById,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xl,
      ),
      itemCount: groups.length,
      itemBuilder: (_, gi) {
        final g = groups[gi];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s,
                  bottom: AppSpacing.s,
                ),
                child: Text(
                  g.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < g.txs.length; i++) ...[
                      _ActivityRow(
                        tx: g.txs[i],
                        dealerName: dealerNameById[g.txs[i].dealerId] ?? '—',
                      ),
                      if (i < g.txs.length - 1)
                        const Divider(
                          height: 0.6,
                          thickness: 0.6,
                          color: AppColors.borderHairline,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<DealerTransactionType, int> _countByType(List<DealerTransaction> txs) {
    final out = <DealerTransactionType, int>{
      for (final t in DealerTransactionType.values) t: 0,
    };
    for (final t in txs) {
      out[t.type] = (out[t.type] ?? 0) + 1;
    }
    return out;
  }

  List<DealerTransaction> _applyFilter(
    List<DealerTransaction> src,
    Map<String, String> dealerNameById,
  ) {
    final q = _query.toLowerCase();
    return src.where((t) {
      if (_filter != _TxFilter.all && _filter.toTxType() != t.type) {
        return false;
      }
      if (q.isNotEmpty) {
        final name = (dealerNameById[t.dealerId] ?? '').toLowerCase();
        if (!name.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<_DateGroup> _groupByDate(List<DealerTransaction> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final buckets = <String, List<DealerTransaction>>{
      AppStrings.dealerActivityGroupToday: [],
      AppStrings.dealerActivityGroupYesterday: [],
      AppStrings.dealerActivityGroupThisWeek: [],
      AppStrings.dealerActivityGroupOlder: [],
    };

    for (final t in txs) {
      final at = t.createdAt;
      if (!at.isBefore(today)) {
        buckets[AppStrings.dealerActivityGroupToday]!.add(t);
      } else if (!at.isBefore(yesterday)) {
        buckets[AppStrings.dealerActivityGroupYesterday]!.add(t);
      } else if (!at.isBefore(weekStart)) {
        buckets[AppStrings.dealerActivityGroupThisWeek]!.add(t);
      } else {
        buckets[AppStrings.dealerActivityGroupOlder]!.add(t);
      }
    }

    final order = [
      AppStrings.dealerActivityGroupToday,
      AppStrings.dealerActivityGroupYesterday,
      AppStrings.dealerActivityGroupThisWeek,
      AppStrings.dealerActivityGroupOlder,
    ];
    return [
      for (final label in order)
        if (buckets[label]!.isNotEmpty)
          _DateGroup(label: label, txs: buckets[label]!),
    ];
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final _TxFilter filter;
  final Map<DealerTransactionType, int> counts;
  final ValueChanged<_TxFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: 44,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        children: [
          _chip('${AppStrings.dealerTxFilterTypeAll} ($total)', _TxFilter.all),
          const SizedBox(width: 8),
          _chip(
            '${AppStrings.dealerTxFilterTypeDelivery} '
            '(${counts[DealerTransactionType.delivery] ?? 0})',
            _TxFilter.delivery,
          ),
          const SizedBox(width: 8),
          _chip(
            '${AppStrings.dealerTxFilterTypeReturn} '
            '(${counts[DealerTransactionType.returned] ?? 0})',
            _TxFilter.returned,
          ),
          const SizedBox(width: 8),
          _chip(
            '${AppStrings.dealerTxFilterTypePayment} '
            '(${counts[DealerTransactionType.payment] ?? 0})',
            _TxFilter.payment,
          ),
          const SizedBox(width: 8),
          _chip(
            '${AppStrings.dealerTxFilterTypeAdjustment} '
            '(${counts[DealerTransactionType.adjustment] ?? 0})',
            _TxFilter.adjustment,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _TxFilter f) {
    return DealerFilterChip(
      label: label,
      selected: filter == f,
      onSelected: (_) => onChanged(f),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx, required this.dealerName});

  final DealerTransaction tx;
  final String dealerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, sign) = _meta(tx.type);
    final amount = tx.amount.abs();
    final formattedAmount = '$sign${NumberFormatter.currency(amount)}';

    return InkWell(
      onTap: () => context.push('${AppRoutes.dealers}/${tx.dealerId}'),
      borderRadius: BorderRadius.circular(AppRadius.s),
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
                    _shortDate(tx.createdAt),
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

  /// tx tipi → (ikon, renk, tutar işareti)
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

  String _shortDate(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final atDay = DateTime(at.year, at.month, at.day);
    if (atDay == today) {
      return DateFormat('HH:mm').format(at);
    }
    if (atDay == today.subtract(const Duration(days: 1))) {
      return AppStrings.dealerActivityGroupYesterday;
    }
    return DateFormat('d MMM', 'tr_TR').format(at);
  }
}

class _DateGroup {
  const _DateGroup({required this.label, required this.txs});
  final String label;
  final List<DealerTransaction> txs;
}

enum _TxFilter {
  all,
  delivery,
  returned,
  payment,
  adjustment;

  DealerTransactionType? toTxType() {
    switch (this) {
      case _TxFilter.all:
        return null;
      case _TxFilter.delivery:
        return DealerTransactionType.delivery;
      case _TxFilter.returned:
        return DealerTransactionType.returned;
      case _TxFilter.payment:
        return DealerTransactionType.payment;
      case _TxFilter.adjustment:
        return DealerTransactionType.adjustment;
    }
  }
}
