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
import '../../../core/widgets/premium/section_label.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_avatar.dart';
import '../widgets/dealer_filter_chip.dart';

class DealerListScreen extends ConsumerStatefulWidget {
  const DealerListScreen({super.key});

  @override
  ConsumerState<DealerListScreen> createState() => _DealerListScreenState();
}

class _DealerListScreenState extends ConsumerState<DealerListScreen> {
  String _query = '';
  _ActiveFilter _filter = _ActiveFilter.all;

  @override
  void initState() {
    super.initState();
    // Sprint 6B.x: Genel Bakış "Borçlu Bayiler" CTA prefilter set ederse
    // bu ekran ilk açılışta debtOnly filtre'ye alınır. Provider one-shot;
    // tüketildikten sonra false'a reset edilir. Kullanıcı manuel
    // filtre değiştirirse normal akış sürer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefilter = ref.read(dealerShellPrefilterDebtOnlyProvider);
      if (prefilter) {
        setState(() => _filter = _ActiveFilter.debtOnly);
        ref.read(dealerShellPrefilterDebtOnlyProvider.notifier).state = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // fix/wholesaler-dealer-shell-parity: Toptancı da bu listeyi normal Bayi
    // Defteri shell'i içinde kullanır (eski wholesaler redirect KALDIRILDI).
    // Tek fark dil/scope: başlık "Müşteriler", ekleme akışı toptan müşteri
    // tipiyle, liste verisi `dealerListScopeProvider` ile wholesale_customer.
    final isWholesaler =
        ref.watch(profileControllerProvider.select((p) => p?.accountType)) ==
            AccountType.wholesaler;

    final dealersAsync = ref.watch(dealersListProvider);
    // Sprint 6B.x: Borçlu filtre + chip count'lar için per-dealer balance
    // map'i. allTxs zaten Sprint 6B'de sağlanan provider'dan.
    final txsAsync = ref.watch(allTransactionsProvider);
    final svc = ref.watch(dealerBalanceServiceProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(isWholesaler ? 'Müşteriler' : AppStrings.dealerListTitle),
        actions: [
          IconButton(
            tooltip: isWholesaler ? 'Müşteri ekle' : AppStrings.dealerAddTooltip,
            onPressed: () => context.push(
              isWholesaler
                  ? AppRoutes.wholesaleCustomerNew
                  : AppRoutes.dealerNew,
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dealersAsync.when(
          // Perf: yeni bayi eklenince/düzenlenince liste eski içeriğini korur
          // (spinner flash yok); spinner yalnız ilk yüklemede.
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              const Center(child: Text(AppStrings.dealersErrorLoad)),
          data: (all) {
            if (all.isEmpty) {
              return EmptyState(
                title: AppStrings.dealerListEmptyTitle,
                subtitle: AppStrings.dealerListEmptySub,
                icon: Icons.storefront_rounded,
                actionLabel: isWholesaler
                    ? 'Müşteri ekle'
                    : AppStrings.dealerListEmptyCta,
                onAction: () => context.push(
                  isWholesaler
                      ? AppRoutes.wholesaleCustomerNew
                      : AppRoutes.dealerNew,
                ),
              );
            }

            // Quality Patch v1 P0-3: balance/lastTx tek pass'te parent'ta
            // hesaplanıp _DealerCard'a prop olarak geçirilir. Eskiden her
            // kart `balanceSummaryProvider` + `transactionsByDealerProvider`
            // ile ikinci kez hesaplıyordu (N round-trip + double summarize).
            // allTx async henüz gelmezse boş map ile ilerle — "Borçlu" filter
            // o anda boş gösterir, sonra tx geldiğinde rebuild olur.
            final txs = txsAsync.value ?? const <DealerTransaction>[];
            final summaryById = <String, DealerBalanceSummary>{
              for (final d in all)
                d.id: svc.summarize(dealerId: d.id, transactions: txs),
            };
            // listAllTransactions desc sıralı döner — putIfAbsent ile her
            // bayinin ilk match'i (en yeni) tutulur.
            final lastTxById = <String, DealerTransaction>{};
            for (final t in txs) {
              lastTxById.putIfAbsent(t.dealerId, () => t);
            }
            final balanceById = {
              for (final e in summaryById.entries)
                e.key: e.value.currentBalance,
            };
            final debtorCount = all
                .where((d) => d.isActive && (balanceById[d.id] ?? 0) > 0)
                .length;

            final filtered = _applyFilters(all, balanceById);

            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.s,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: AppStrings.dealerSearchHint,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.softGold,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                _FilterRow(
                  filter: _filter,
                  total: all.length,
                  active: all.where((d) => d.isActive).length,
                  debtor: debtorCount,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                    child: EmptyState(
                      title: AppStrings.dealerListNoMatch,
                      subtitle: AppStrings.dealerListNoMatchHint,
                      icon: Icons.search_off_rounded,
                      compact: true,
                    ),
                  )
                else
                  const SectionLabel(
                    title: AppStrings.dealerListSection,
                    topGap: AppSpacing.s,
                    bottomGap: AppSpacing.s,
                  ),
                for (final d in filtered)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      0,
                      AppSpacing.pageH,
                      AppSpacing.s,
                    ),
                    child: _DealerCard(
                      dealer: d,
                      summary: summaryById[d.id]!,
                      lastTx: lastTxById[d.id],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Dealer> _applyFilters(
    List<Dealer> src,
    Map<String, double> balanceById,
  ) {
    Iterable<Dealer> r = src;
    switch (_filter) {
      case _ActiveFilter.all:
        break;
      case _ActiveFilter.active:
        r = r.where((d) => d.isActive);
        break;
      case _ActiveFilter.passive:
        r = r.where((d) => !d.isActive);
        break;
      case _ActiveFilter.debtOnly:
        // Sprint 6B.x: aktif + currentBalance > 0. Pasif borçlular
        // bilinçli olarak hariç (kullanıcı "ödenmedi ama bayi de
        // gitti" durumunu zaten pasif filtresinden görür).
        r = r.where((d) => d.isActive && (balanceById[d.id] ?? 0) > 0);
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      r = r.where(
        (d) =>
            d.name.toLowerCase().contains(q) ||
            d.area.toLowerCase().contains(q) ||
            d.contactName.toLowerCase().contains(q),
      );
    }
    return r.toList();
  }
}

enum _ActiveFilter { all, active, passive, debtOnly }

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.total,
    required this.active,
    required this.debtor,
    required this.onChanged,
  });

  final _ActiveFilter filter;
  final int total;
  final int active;
  final int debtor;
  final ValueChanged<_ActiveFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final passive = total - active;
    return SizedBox(
      height: 44,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            context,
            '${AppStrings.dealerFilterAll} ($total)',
            _ActiveFilter.all,
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            '${AppStrings.dealerFilterActive} ($active)',
            _ActiveFilter.active,
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            '${AppStrings.dealerFilterPassive} ($passive)',
            _ActiveFilter.passive,
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            '${AppStrings.dealerFilterDebtOnly} ($debtor)',
            _ActiveFilter.debtOnly,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, _ActiveFilter f) {
    return DealerFilterChip(
      label: label,
      selected: filter == f,
      onSelected: (_) => onChanged(f),
    );
  }
}

/// Quality Patch v1 P0-3: artık `ConsumerWidget` değil — balance ve last
/// tx parent'tan prop olarak gelir (tek pass'te hesaplanır). Eski
/// `balanceSummaryProvider` + `transactionsByDealerProvider` watch'ları
/// kaldırıldı: N kart × 2 provider çağrısı → 1 toplu hesap.
class _DealerCard extends StatelessWidget {
  const _DealerCard({
    required this.dealer,
    required this.summary,
    required this.lastTx,
  });

  final Dealer dealer;
  final DealerBalanceSummary summary;
  final DealerTransaction? lastTx;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => context.push('${AppRoutes.dealers}/${dealer.id}'),
      padding: const EdgeInsets.all(AppSpacing.l),
      warm: !dealer.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DealerAvatar(
                dealer: dealer,
                size: 42,
                palette: DealerAvatarPalette.autoActivity,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dealer.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!dealer.isActive)
                          const _Badge(
                            label: AppStrings.dealerCardPassiveBadge,
                            color: AppColors.textMuted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (dealer.area.isNotEmpty) dealer.area,
                        dealer.workingType.label,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(
            height: 1,
            thickness: 0.6,
            color: AppColors.borderHairline,
          ),
          const SizedBox(height: AppSpacing.m),
          _BalanceFooter(summary: summary, lastTx: lastTx),
        ],
      ),
    );
  }
}

class _BalanceFooter extends StatelessWidget {
  const _BalanceFooter({required this.summary, this.lastTx});
  final DealerBalanceSummary summary;
  final DealerTransaction? lastTx;

  @override
  Widget build(BuildContext context) {
    final balance = summary.currentBalance;
    // Quality Patch v1 P0-1: 0 bakiye rengi diğer 3 ekranla aynı (textMuted).
    final color = balance > 0
        ? AppColors.copper
        : balance < 0
        ? AppColors.success
        : AppColors.textMuted;

    final label = balance > 0
        ? AppStrings.dealerCardBalanceLabel
        : balance < 0
        ? AppStrings.dealerCardCreditLabel
        : AppStrings.dealerCardClosedLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormatter.currency(balance.abs()),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        if (lastTx != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.dealerCardLastTxLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _shortLabel(lastTx!),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _shortLabel(DealerTransaction t) {
    final d = t.createdAt;
    final diff = DateTime.now().difference(d).inDays;
    final ago = diff == 0 ? 'bugün' : '$diff g önce';
    switch (t.type) {
      case DealerTransactionType.delivery:
        return 'Teslim · $ago';
      case DealerTransactionType.returned:
        return 'İade · $ago';
      case DealerTransactionType.payment:
        return 'Ödeme · $ago';
      case DealerTransactionType.adjustment:
        return 'Düzeltme · $ago';
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
