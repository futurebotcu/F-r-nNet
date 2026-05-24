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

class DealerListScreen extends ConsumerStatefulWidget {
  const DealerListScreen({super.key});

  @override
  ConsumerState<DealerListScreen> createState() => _DealerListScreenState();
}

class _DealerListScreenState extends ConsumerState<DealerListScreen> {
  String _query = '';
  _ActiveFilter _filter = _ActiveFilter.all;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider);

    // Toptancı kullanıcı "Bayi Defteri" dilini görmez — kendi tarafı
    // "Müşteriler" diliyle ayrı yaşar. Nav kartında bu route'a giden link
    // yok; yalnız deep-link / legacy bookmark senaryosu için defansif
    // redirect.
    if (profile?.accountType == AccountType.wholesaler) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.wholesaleCustomers);
      });
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Bireysel kullanıcı kendi adına bayi defteri açmaz; yalnız bir ticari
    // işletme tarafından FırınNet ID ile yetkilendirildiğinde o işletmenin
    // defterini görür. Staff modeli (dealer_staff) henüz aktif olmadığı
    // için bireyselin sonucu daima EmptyAuthorizedState'tir. C2'de
    // dealer_staff geldiğinde DealerAccessResolver ile değiştirilecek.
    if (profile?.accountType == AccountType.individual) {
      return PremiumScaffold(
        appBar: AppBar(
          title: const Text(AppStrings.dealerListTitle),
        ),
        body: const SafeArea(
          top: false,
          child: EmptyState(
            title: AppStrings.dealerEmptyAuthorizedTitle,
            subtitle: AppStrings.dealerEmptyAuthorizedBody,
            icon: Icons.business_outlined,
          ),
        ),
      );
    }

    final dealersAsync = ref.watch(dealersListProvider);

    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dealerListTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.dealerAddTooltip,
            onPressed: () => context.push(AppRoutes.dealerNew),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dealersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (all) {
            if (all.isEmpty) {
              return EmptyState(
                title: AppStrings.dealerListEmptyTitle,
                subtitle: AppStrings.dealerListEmptySub,
                icon: Icons.storefront_rounded,
                actionLabel: AppStrings.dealerListEmptyCta,
                onAction: () => context.push(AppRoutes.dealerNew),
              );
            }

            final filtered = _applyFilters(all);

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
                  onChanged: (f) => setState(() => _filter = f),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        AppStrings.dealerListNoMatch,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
                    child: _DealerCard(dealer: d),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Dealer> _applyFilters(List<Dealer> src) {
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
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      r = r.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.area.toLowerCase().contains(q) ||
          d.contactName.toLowerCase().contains(q));
    }
    return r.toList();
  }
}

enum _ActiveFilter { all, active, passive }

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.total,
    required this.active,
    required this.onChanged,
  });

  final _ActiveFilter filter;
  final int total;
  final int active;
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
          _chip(context, '${AppStrings.dealerFilterAll} ($total)',
              _ActiveFilter.all),
          const SizedBox(width: 8),
          _chip(context, '${AppStrings.dealerFilterActive} ($active)',
              _ActiveFilter.active),
          const SizedBox(width: 8),
          _chip(context, '${AppStrings.dealerFilterPassive} ($passive)',
              _ActiveFilter.passive),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, _ActiveFilter f) {
    return ChoiceChip(
      label: Text(label),
      selected: filter == f,
      onSelected: (_) => onChanged(f),
    );
  }
}

class _DealerCard extends ConsumerWidget {
  const _DealerCard({required this.dealer});
  final Dealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceSummaryProvider(dealer.id));
    final txs = ref.watch(transactionsByDealerProvider(dealer.id));

    return PremiumCard(
      onTap: () => context.push('${AppRoutes.dealers}/${dealer.id}'),
      padding: const EdgeInsets.all(AppSpacing.l),
      warm: !dealer.isActive,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: dealer.isActive
                        ? AppColors.softGold.withValues(alpha: 0.14)
                        : AppColors.surfaceLine.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dealer.name.isNotEmpty
                        ? dealer.name[0].toUpperCase()
                        : 'B',
                    style: TextStyle(
                      color: dealer.isActive
                          ? AppColors.softGold
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
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
                      const SizedBox(height: 3),
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
            balance.when(
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ),
              ),
              error: (e, _) => Text(
                'Bakiye okunamadı: $e',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
              data: (s) => _BalanceFooter(
                summary: s,
                lastTx: txs.maybeWhen(
                  data: (list) => list.isEmpty ? null : list.first,
                  orElse: () => null,
                ),
              ),
            ),
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
    final color = balance > 0
        ? AppColors.copper
        : balance < 0
            ? AppColors.success
            : AppColors.textSecondary;

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
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 0.6,
        ),
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
