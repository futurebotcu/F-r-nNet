// B2B Pazar — Tedarikçi > Talepler (S2; eski "Teklif Ağı").
//
// Tedarikçinin günlük talep yönetimi merkezi. Dört segment, tek veri kaynağı
// ([supplierRequestsInboxProvider] — Panel KPI'larıyla aynı):
//   Yeni            — yanıtlamadığım, yanıta uygun açık talepler → "Teklif Ver"
//   Yanıtladıklarım — cevaplarım + durum (bekliyor / seçildi / başka seçildi)
//   İlgilenenler    — alıcının ilgilendiği cevaplarım (telefon onaylıysa)
//   Kazanılan       — alıcının seçtiği cevaplarım
// Filtre/arama (Yeni + Yanıtladıklarım): kategori · il · metin; seçenekler
// listedeki gerçek değerlerden türetilir (yeni tablo yok).
//
// ANONİMLİK: alıcı kimliği/iletişimi hiçbir kartta yok (model zaten taşımaz).
// Talep hedefi (ürünüm/kampanyam/mağazam) yalnız BENİM nesnelerimle eşlenir;
// başka tedarikçinin hedefi için ad gösterilmez, yalnız "belirli bir
// tedarikçiye yönelik" notu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_retry_state.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_list_skeleton.dart';
import '../../models/b2b_quote_lead.dart';
import '../../models/b2b_quote_request.dart';
import '../../models/b2b_replied_request.dart';
import '../../models/supplier_requests_inbox.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_lead_card.dart';
import '../../widgets/b2b_meta_pill.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_quote_request_card.dart';
import '../../widgets/b2b_search_field.dart';

enum SupplierRequestsSegment { fresh, replied, interested, won }

class SupplierRequestsTab extends ConsumerStatefulWidget {
  const SupplierRequestsTab({super.key, this.initialSegment});

  final SupplierRequestsSegment? initialSegment;

  @override
  ConsumerState<SupplierRequestsTab> createState() =>
      _SupplierRequestsTabState();
}

class _SupplierRequestsTabState extends ConsumerState<SupplierRequestsTab> {
  late SupplierRequestsSegment _seg =
      widget.initialSegment ?? SupplierRequestsSegment.fresh;
  SupplierRequestFilter _filter = const SupplierRequestFilter();

  /// S3 — sunucu sayfalama: ilk sayfa provider'dan, sonraki sayfalar burada
  /// birikir (filtre anahtarına göre). Biriken sayfalar, ilk sayfa yeniden
  /// çekildiğinde (yenile/segment dönüşü/yazma) geçersiz sayılır; tekrar eden
  /// kayıtlar id ile ayıklanır; boş sayfa gelirse liste "tükendi" sayılır.
  static const _pageSize = 20;
  final Map<String, _ExtraPages> _extraPages = {};
  bool _loadingMore = false;

  String get _serverFilterKey => encodeFreshPageKey((
    categories: _filter.category == null ? null : [_filter.category!],
    cities: _filter.city == null ? null : [_filter.city!],
    offset: 0,
    limit: _pageSize,
  ));

  /// [key] ve [base] istek ANINDA yakalanır: istek sürerken filtre değişirse
  /// sonuç eski filtrenin anahtarına yazılır (yanlış listeye karışmaz).
  Future<void> _loadMore(
    String key,
    B2bOpenRequestsPage base,
    int rawOffset,
  ) async {
    if (_loadingMore) return;
    final cats = _filter.category == null ? null : [_filter.category!];
    final cities = _filter.city == null ? null : [_filter.city!];
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(b2bRepositoryProvider)
          .listOpenQuoteRequestsPage(
            categories: cats,
            cities: cities,
            excludeReplied: true,
            limit: _pageSize,
            offset: rawOffset,
          );
      if (!mounted) return;
      setState(() {
        if (page != null) {
          var ex = _extraPages[key];
          if (ex == null || !identical(ex.base, base)) {
            ex = _ExtraPages(base);
            _extraPages[key] = ex;
          }
          ex.items.addAll(page.items);
          ex.latestTotal = page.totalCount;
          if (page.items.isEmpty) ex.exhausted = true;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _filterable =>
      _seg == SupplierRequestsSegment.fresh ||
      _seg == SupplierRequestsSegment.replied;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supplierRequestsInboxProvider);
    final inbox = async.valueOrNull;
    // Yazma (teklif ver vb.) → biriken sayfalar geçersiz.
    ref.listen<int>(b2bMarketControllerProvider, (_, __) {
      if (_extraPages.isNotEmpty) setState(_extraPages.clear);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: _SegmentBar(
            value: _seg,
            counts: inbox,
            onChanged: (v) => setState(() => _seg = v),
          ),
        ),
        if (_filterable && inbox != null) ...[
          B2bSearchField(
            key: const ValueKey('sup_req_search'),
            hint: AppStrings.supReqSearchHint,
            onChanged: (q) =>
                setState(() => _filter = _filter.copyWith(query: q)),
          ),
          const SizedBox(height: AppSpacing.s),
          _FilterRow(
            filter: _filter,
            categories: SupplierRequestFilter.categoriesOf(
              _seg == SupplierRequestsSegment.fresh
                  ? inbox.fresh
                  : inbox.replied.map((i) => i.request).whereType(),
            ),
            cities: SupplierRequestFilter.citiesOf(
              _seg == SupplierRequestsSegment.fresh
                  ? inbox.fresh
                  : inbox.replied.map((i) => i.request).whereType(),
            ),
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Expanded(
          child: async.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const PremiumListSkeleton(),
            error: (_, __) => ErrorRetryState(
              compact: true,
              onRetry: () => supplierRequestsInboxRefresh(ref),
            ),
            data: (box) => _body(box),
          ),
        ),
      ],
    );
  }

  Widget _body(SupplierRequestsInbox box) {
    switch (_seg) {
      case SupplierRequestsSegment.fresh:
        // S3: sunucu sayfası varsa (migration uygulanmış) onu kullan; yoksa
        // S2 istemci listesi. Metin araması her iki modda istemci tarafı.
        final key = _serverFilterKey;
        final page = ref.watch(b2bFreshRequestsPageProvider(key)).valueOrNull;
        final textOnly = SupplierRequestFilter(query: _filter.query);
        if (page != null) {
          // İlk sayfa yeniden çekildiyse biriken sayfalar bayat → yok say.
          final ex = _extraPages[key];
          final valid = ex != null && identical(ex.base, page) ? ex : null;
          final rawCount = page.items.length + (valid?.items.length ?? 0);
          final seen = <String>{};
          final loaded = <B2bQuoteRequest>[
            for (final r in [...page.items, ...?valid?.items])
              if (seen.add(r.id)) r,
          ];
          final total = valid?.latestTotal ?? page.totalCount;
          final hasMore = !(valid?.exhausted ?? false) && rawCount < total;
          return _FreshList(
            items: loaded.where(textOnly.matchesRequest).toList(),
            filtered: !_filter.isEmpty,
            onClearFilter: () =>
                setState(() => _filter = const SupplierRequestFilter()),
            totalCount: total,
            loadedCount: loaded.length,
            hasMore: hasMore,
            loadingMore: _loadingMore,
            onLoadMore: () => _loadMore(key, page, rawCount),
          );
        }
        return _FreshList(
          items: box.fresh.where(_filter.matchesRequest).toList(),
          filtered: !_filter.isEmpty,
          onClearFilter: () =>
              setState(() => _filter = const SupplierRequestFilter()),
        );
      case SupplierRequestsSegment.replied:
        return _RepliedList(
          items: box.replied.where(_filter.matchesReplied).toList(),
          filtered: !_filter.isEmpty,
          emptyTitle: AppStrings.supReqEmptyRepliedTitle,
          emptySub: AppStrings.supReqEmptyRepliedSub,
          emptyIcon: Icons.outbox_outlined,
          onClearFilter: () =>
              setState(() => _filter = const SupplierRequestFilter()),
        );
      case SupplierRequestsSegment.interested:
        return _LeadList(items: box.interested);
      case SupplierRequestsSegment.won:
        return _RepliedList(
          items: box.won,
          filtered: false,
          emptyTitle: AppStrings.supReqEmptyWonTitle,
          emptySub: AppStrings.supReqEmptyWonSub,
          emptyIcon: Icons.emoji_events_outlined,
          onClearFilter: null,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Segment çubuğu (yatay kaydırılabilir, sayaçlı, 44px)
// ---------------------------------------------------------------------------

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.value,
    required this.onChanged,
    this.counts,
  });
  final SupplierRequestsSegment value;
  final ValueChanged<SupplierRequestsSegment> onChanged;
  final SupplierRequestsInbox? counts;

  @override
  Widget build(BuildContext context) {
    final items = <(SupplierRequestsSegment, String, int?)>[
      (
        SupplierRequestsSegment.fresh,
        AppStrings.supReqSegFresh,
        counts?.fresh.length,
      ),
      (
        SupplierRequestsSegment.replied,
        AppStrings.supReqSegReplied,
        counts?.replied.length,
      ),
      (
        SupplierRequestsSegment.interested,
        AppStrings.supReqSegInterested,
        counts?.interested.length,
      ),
      (
        SupplierRequestsSegment.won,
        AppStrings.supReqSegWon,
        counts?.won.length,
      ),
    ];
    // 4 kısa segment: tembel liste yerine düz satır (hepsi ağaçta, erişilebilir).
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _segChip(items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segChip((SupplierRequestsSegment, String, int?) item) {
    final (seg, label, n) = item;
    final selected = seg == value;
    return Semantics(
      button: true,
      selected: selected,
      label: n == null ? label : '$label $n',
      child: InkWell(
        key: ValueKey('sup_req_seg_${seg.name}'),
        onTap: () => onChanged(seg),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLemon : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandLemon : AppColors.borderHairline,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.chipLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.brandInk
                      : AppColors.textSecondary,
                ),
              ),
              if (n != null && n > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandInk
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$n',
                    style: AppTypography.badge.copyWith(
                      color: selected
                          ? AppColors.brandLemon
                          : AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre satırı: kategori · il chip'leri (veriden türetilir)
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.categories,
    required this.cities,
    required this.onChanged,
  });
  final SupplierRequestFilter filter;
  final List<String> categories;
  final List<String> cities;
  final ValueChanged<SupplierRequestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty && cities.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          if (!filter.isEmpty)
            _FilterChip(
              key: const ValueKey('sup_req_filter_clear'),
              label: AppStrings.supReqFilterClear,
              icon: Icons.close_rounded,
              selected: false,
              onTap: () => onChanged(const SupplierRequestFilter()),
            ),
          for (final c in categories)
            _FilterChip(
              key: ValueKey('sup_req_cat_$c'),
              label: c,
              icon: Icons.category_outlined,
              selected: filter.category == c,
              onTap: () => onChanged(
                filter.copyWith(
                  category: () => filter.category == c ? null : c,
                ),
              ),
            ),
          for (final city in cities)
            _FilterChip(
              key: ValueKey('sup_req_city_$city'),
              label: city,
              icon: Icons.location_on_outlined,
              selected: filter.city == city,
              onTap: () => onChanged(
                filter.copyWith(city: () => filter.city == city ? null : city),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brandInk : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLemonPale : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandLemon : AppColors.borderHairline,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.chipLabel.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yeni
// ---------------------------------------------------------------------------

class _FreshList extends ConsumerWidget {
  const _FreshList({
    required this.items,
    required this.filtered,
    required this.onClearFilter,
    this.totalCount,
    this.loadedCount,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
  });
  final List<B2bQuoteRequest> items;
  final bool filtered;
  final VoidCallback onClearFilter;

  /// Sunucudan yüklenen (metin aramasından ÖNCE) benzersiz kayıt sayısı —
  /// "yüklenen / toplam" sayacı bununla gösterilir.
  final int? loadedCount;

  /// S3 — sunucu sayfalama (null → istemci modu, sayfa yok).
  final int? totalCount;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sayfalama modunda metin araması yalnız yüklenen sayfaları süzer;
    // eşleşme yoksa ama daha fazla sayfa varsa "Daha fazla yükle" kalır.
    if (items.isEmpty && !hasMore) {
      return EmptyState(
        icon: Icons.hub_outlined,
        title: filtered
            ? AppStrings.supReqEmptyFreshFiltered
            : AppStrings.supReqEmptyFreshTitle,
        subtitle: filtered ? null : AppStrings.supReqEmptyFreshSub,
        actionLabel: filtered ? AppStrings.supReqFilterClear : null,
        onAction: filtered ? onClearFilter : null,
        compact: true,
      );
    }
    final myShopId = ref.watch(b2bMyStoreProvider).valueOrNull?.id;
    final myProducts = ref.watch(b2bMyProductsProvider).valueOrNull ?? const [];
    final myCampaigns =
        ref.watch(b2bMyCampaignsProvider).valueOrNull ?? const [];
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      itemCount: items.length + 1 + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (context, i) {
        if (i == 0) return const _AnonymityNote();
        if (i == items.length + 1) {
          return _LoadMoreRow(
            shown: loadedCount ?? items.length,
            total: totalCount ?? items.length,
            loading: loadingMore,
            onTap: onLoadMore,
          );
        }
        final r = items[i - 1];
        final target = SupplierRequestsInbox.targetOf(
          r,
          myShopId: myShopId,
          myProducts: myProducts,
          myCampaigns: myCampaigns,
        );
        final label = SupplierRequestsInbox.myTargetLabel(
          r,
          myShopId: myShopId,
          myProducts: myProducts,
          myCampaigns: myCampaigns,
        );
        return B2bQuoteRequestCard(
          key: ValueKey('sup_req_card_${r.id}'),
          request: r,
          dateLabel: r.createdAt == null ? null : relativeTimeTr(r.createdAt!),
          contextChip: _targetChip(target, r.targetType, label),
          onReply: r.status.isTerminal
              ? null
              : () => showB2bOfferFlow(
                  context,
                  kind: B2bOfferKind.giveOffer,
                  contextLine: '${r.productOrCategory} · ${r.city}',
                  quoteRequestId: r.id,
                ),
        );
      },
    );
  }

  static Widget? _targetChip(
    SupplierRequestTarget target,
    String targetType,
    String? label,
  ) {
    switch (target) {
      case SupplierRequestTarget.category:
        return null;
      case SupplierRequestTarget.other:
        return const B2bOutcomeChip(
          icon: Icons.storefront_outlined,
          label: AppStrings.supReqTargetOther,
          tone: B2bOutcomeTone.muted,
        );
      case SupplierRequestTarget.mine:
        final text = switch (targetType) {
          'product' when (label ?? '').isNotEmpty =>
            '${AppStrings.supReqTargetMineProduct}: $label',
          'campaign' when (label ?? '').isNotEmpty =>
            '${AppStrings.supReqTargetMineCampaign}: $label',
          _ => AppStrings.supReqTargetMine,
        };
        return B2bOutcomeChip(
          icon: Icons.star_rounded,
          label: text,
          tone: B2bOutcomeTone.warning,
        );
    }
  }
}

class _AnonymityNote extends StatelessWidget {
  const _AnonymityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.shield_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppStrings.supReqAnonNote,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yanıtladıklarım / Kazanılan
// ---------------------------------------------------------------------------

class _RepliedList extends StatelessWidget {
  const _RepliedList({
    required this.items,
    required this.filtered,
    required this.emptyTitle,
    required this.emptySub,
    required this.emptyIcon,
    required this.onClearFilter,
  });
  final List<SupplierRepliedItem> items;
  final bool filtered;
  final String emptyTitle;
  final String emptySub;
  final IconData emptyIcon;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: filtered ? AppStrings.supReqEmptyFreshFiltered : emptyTitle,
        subtitle: filtered ? null : emptySub,
        actionLabel: filtered ? AppStrings.supReqFilterClear : null,
        onAction: filtered ? onClearFilter : null,
        compact: true,
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (context, i) => _RepliedCard(item: items[i]),
    );
  }
}

class _RepliedCard extends StatelessWidget {
  const _RepliedCard({required this.item});
  final SupplierRepliedItem item;

  @override
  Widget build(BuildContext context) {
    final reply = item.reply;
    final dateLabel = reply.createdAt != null
        ? relativeTimeTr(reply.createdAt!)
        : reply.createdAtLabel;
    final req = item.request;
    final lead = item.lead;

    final outcome = item.won
        ? const B2bOutcomeChip(
            icon: Icons.verified_rounded,
            label: AppStrings.supReqWon,
            tone: B2bOutcomeTone.success,
          )
        : item.lost
        ? const B2bOutcomeChip(
            icon: Icons.info_outline_rounded,
            label: AppStrings.supReqLost,
            tone: B2bOutcomeTone.muted,
          )
        : item.requestUnavailable
        ? const B2bOutcomeChip(
            icon: Icons.lock_clock_outlined,
            label: AppStrings.supReqClosedUnknown,
            tone: B2bOutcomeTone.muted,
          )
        : const B2bOutcomeChip(
            icon: Icons.schedule_rounded,
            label: AppStrings.supReqWaiting,
            tone: B2bOutcomeTone.warning,
          );

    return PremiumCard(
      key: ValueKey('sup_replied_card_${reply.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title.isNotEmpty
                      ? item.title
                      : AppStrings.supReqUnknownTitle,
                  style: AppTypography.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // Row non-flex çocuğa sınırsız genişlik verir → çip Flexible.
              Flexible(child: outcome),
            ],
          ),
          if (item.requestUnavailable) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.supReqClosedUnknownSub,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (item.quantity.isNotEmpty ||
              item.city.isNotEmpty ||
              (req?.deliveryTime.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.quantity.isNotEmpty)
                  B2bMetaPill(icon: Icons.scale_outlined, label: item.quantity),
                if (item.city.isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.location_on_outlined,
                    label: item.city,
                  ),
                if (req != null && req.deliveryTime.isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.schedule_rounded,
                    label: req.deliveryTime,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          _MyOfferBox(reply: reply, dateLabel: dateLabel),
          if (lead != null && lead.isInterested) ...[
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppColors.successInk,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    AppStrings.supReqInterestedLine,
                    style: AppTypography.infoLabel.copyWith(
                      color: AppColors.successInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tedarikçinin kendi teklif özeti (mesaj + fiyat/teslimat notu + zaman).
class _MyOfferBox extends StatelessWidget {
  const _MyOfferBox({required this.reply, required this.dateLabel});
  final dynamic reply;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final String message = reply.message as String;
    final String? price = reply.priceHint as String?;
    final String? delivery = reply.deliveryNote as String?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                size: 14,
                color: AppColors.brandInk,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  AppStrings.supReqMyOffer,
                  style: AppTypography.infoLabel.copyWith(
                    color: AppColors.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (dateLabel.isNotEmpty)
                Text(
                  dateLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTypography.body.copyWith(fontSize: 13.5, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if ((price ?? '').isNotEmpty || (delivery ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((price ?? '').isNotEmpty)
                  B2bMetaPill(icon: Icons.sell_outlined, label: price!),
                if ((delivery ?? '').isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.local_shipping_outlined,
                    label: delivery!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// İlgilenenler
// ---------------------------------------------------------------------------

class _LeadList extends StatelessWidget {
  const _LeadList({required this.items});
  final List<B2bQuoteLead> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: AppStrings.supReqEmptyInterestedTitle,
        subtitle: AppStrings.supReqEmptyInterestedSub,
        compact: true,
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (context, i) => B2bLeadCard(lead: items[i]),
    );
  }
}

/// S3 — "Daha fazla talep yükle" satırı (44px, sayaç: gösterilen / toplam).
class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({
    required this.shown,
    required this.total,
    required this.loading,
    required this.onTap,
  });
  final int shown;
  final int total;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppStrings.supReqShownOf(shown, total),
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            key: const ValueKey('sup_req_load_more'),
            onPressed: loading ? null : onTap,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded, size: 18),
            label: const Text(AppStrings.supReqLoadMore),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderHairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sunucudan "Daha fazla" ile yüklenen sayfalar (ilk sayfa nesnesine bağlı).
class _ExtraPages {
  _ExtraPages(this.base);

  /// Bu sayfaların eklendiği ilk sayfa (identity) — ilk sayfa yeniden
  /// çekilince birikenler geçersiz olur.
  final B2bOpenRequestsPage base;
  final List<B2bQuoteRequest> items = <B2bQuoteRequest>[];
  int? latestTotal;
  bool exhausted = false;
}
