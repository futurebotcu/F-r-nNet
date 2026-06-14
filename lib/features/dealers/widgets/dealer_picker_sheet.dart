import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

/// Bayi seçici modal (Sprint 6B). Genel Bakış'taki "Teslimat Gir" ve
/// "Ödeme Al" CTA'ları bu sheet'i çağırır; kullanıcı bayi seçince
/// [show] Future\<Dealer?\> ile seçileni döner.
///
/// `debtOnly: true` → yalnız `currentBalance > 0` bayiler listelenir.
/// "Ödeme Al" CTA bu modu kullanır ve Sprint 6C [QuickPaymentSheet]'in
/// hasDebt önkoşulunu garantiler.
class DealerPickerSheet extends ConsumerStatefulWidget {
  const DealerPickerSheet({super.key, this.initialDebtOnly = false});

  final bool initialDebtOnly;

  /// Convenience launcher. `Future<Dealer?>` — dismiss edilirse null.
  static Future<Dealer?> show({
    required BuildContext context,
    bool debtOnly = false,
  }) {
    return showModalBottomSheet<Dealer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DealerPickerSheet(initialDebtOnly: debtOnly),
    );
  }

  @override
  ConsumerState<DealerPickerSheet> createState() => _DealerPickerSheetState();
}

class _DealerPickerSheetState extends ConsumerState<DealerPickerSheet> {
  late bool _debtOnly;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _debtOnly = widget.initialDebtOnly;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    final dealersAsync = ref.watch(dealersListProvider);
    final txsAsync = ref.watch(allTransactionsProvider);
    final svc = ref.watch(dealerBalanceServiceProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  0,
                  AppSpacing.pageH,
                  AppSpacing.s,
                ),
                child: Row(
                  children: [
                    Text(
                      AppStrings.dealerPickerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(AppStrings.dealerPickerFilterAll),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(AppStrings.dealerPickerFilterDebtOnly),
                        ),
                      ],
                      selected: {_debtOnly},
                      onSelectionChanged: (s) =>
                          setState(() => _debtOnly = s.first),
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  0,
                  AppSpacing.pageH,
                  AppSpacing.s,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppStrings.dealerPickerSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(child: _buildList(dealersAsync, txsAsync, svc)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    AsyncValue<List<Dealer>> dealersAsync,
    AsyncValue<List<dynamic>> txsAsync,
    dynamic svc,
  ) {
    if (dealersAsync.isLoading || txsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dealersAsync.hasError || txsAsync.hasError) {
      return const ErrorRetryState(compact: true);
    }

    final all = dealersAsync.value ?? const [];
    final txs = txsAsync.value ?? const [];
    final q = _query.toLowerCase();

    // Aktif bayileri filtrele
    final filtered = all.where((d) {
      if (!d.isActive) return false;
      if (q.isNotEmpty &&
          !d.name.toLowerCase().contains(q) &&
          !d.area.toLowerCase().contains(q) &&
          !d.city.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    // Balance hesapla + debt filtresi uygula
    final entries = filtered
        .map((d) {
          final s = svc.summarize(dealerId: d.id, transactions: txs);
          return (dealer: d, balance: s.currentBalance as double);
        })
        .where((e) => _debtOnly ? e.balance > 0 : true)
        .toList();

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyState(
          title: _debtOnly
              ? AppStrings.dealerPickerNoDebtors
              : AppStrings.dealerPickerNoDealers,
          icon: _debtOnly
              ? Icons.check_circle_outline_rounded
              : Icons.search_off_rounded,
          compact: true,
        ),
      );
    }

    // Borç tutarına göre desc sıralama (debtOnly modunda anlamlı)
    if (_debtOnly) {
      entries.sort((a, b) => b.balance.compareTo(a.balance));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.xs,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (_, i) {
        final e = entries[i];
        return _DealerRow(
          dealer: e.dealer,
          balance: e.balance,
          onTap: () => Navigator.of(context).pop(e.dealer),
        );
      },
    );
  }
}

class _DealerRow extends StatelessWidget {
  const _DealerRow({
    required this.dealer,
    required this.balance,
    required this.onTap,
  });

  final Dealer dealer;
  final double balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebt = balance > 0;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.l),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.softGold.withValues(alpha: 0.18),
                child: Text(
                  dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dealer.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dealer.area.isNotEmpty || dealer.city.isNotEmpty)
                      Text(
                        [
                          dealer.area,
                          dealer.city,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasDebt)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    NumberFormatter.currency(balance),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.brandInk,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
