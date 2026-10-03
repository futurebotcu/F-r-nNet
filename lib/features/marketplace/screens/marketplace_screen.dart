// FırınNet Market V1 M2 — Ana marketplace ekranı.
//
// Donor pattern referansı: Bagisto `category_page.dart`:
//   header + search/filter row + chip row + product grid + filter sheet.
// FırınNet adaptasyonu:
//   * Header (FirinNetHeader) + + (yeni ilan) action.
//   * Listing_type chip row (Tümü / Ekipman satışı / Fırın devri).
//   * Filter buton → MarketplaceFiltersSheet (yan menü değil bottom sheet).
//   * Active filter chips row.
//   * MarketplaceListingCard (image + title + price + chips + save).
//   * Tap → /market/listings/:id (detail).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../dealers/widgets/dealer_filter_chip.dart';
import '../../listings/utils/listing_format.dart';
import '../../listings/widgets/listing_ui.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';
import '../widgets/marketplace_filters_sheet.dart';
import '../widgets/marketplace_listing_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({
    super.key,
    this.embedded = false,
    this.forceListingType,
  });

  /// İlanlar sekmesi altında "İş yeri" / "Ekipman" segmenti olarak gömüldüğünde
  /// true: kendi FırınNetHeader'ını ve listing-type chip satırını çizmez
  /// (üst kapsayıcı başlık + segment sağlar). Standalone /market → false.
  final bool embedded;

  /// Gömülü segmentte listing_type kilidi ('bakery_transfer' = İş yeri,
  /// 'equipment_sale' = Ekipman). null → tüm tipler (standalone Market).
  final String? forceListingType;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  late MarketFilters _filters = widget.forceListingType == null
      ? const MarketFilters()
      : MarketFilters(listingType: widget.forceListingType);

  Future<void> _onAddPressed() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    // Gömülü segmentte (İş yeri / Ekipman) form doğru ilan tipiyle açılır.
    final type = widget.forceListingType;
    context.push(
      type == null
          ? AppRoutes.marketListingNew
          : Uri(
              path: AppRoutes.marketListingNew,
              queryParameters: {'type': type},
            ).toString(),
    );
  }

  /// Gömülü segmentte forced tip korunarak filtre sıfırlanır.
  MarketFilters get _baseFilters => widget.forceListingType == null
      ? const MarketFilters()
      : MarketFilters(listingType: widget.forceListingType);

  /// Segment kilidi dışındaki aktif filtre sayısı ("Filtrele (n)").
  int get _extraFilterCount => widget.forceListingType == null
      ? _filters.activeCount
      : _filters.activeCount - (_filters.listingType == null ? 0 : 1);

  Future<void> _onRefresh() async {
    ref.invalidate(filteredMarketListingsProvider(_filters));
    await ref
        .read(filteredMarketListingsProvider(_filters).future)
        .catchError((_) => const <MarketListing>[]);
  }

  Future<void> _openFilters() async {
    final result = await MarketplaceFiltersSheet.show(
      context,
      initial: _filters,
      lockedListingType: widget.forceListingType,
    );
    if (result != null) {
      final forced = widget.forceListingType;
      setState(
        () => _filters = forced == null
            ? result
            : result.copyWith(listingType: forced),
      );
    }
  }

  void _setListingType(String? type) {
    setState(() {
      _filters = _filters.copyWith(
        listingType: type,
        clearListingType: type == null,
      );
    });
  }

  Future<void> _toggleSave(MarketListing l) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(marketListingRepositoryProvider);
    AppHaptics.toggle();
    final wasSaved = l.isSavedByMe;
    try {
      if (wasSaved) {
        await repo.unsaveListing(l.id!);
      } else {
        await repo.saveListing(l.id!);
      }
      ref.invalidate(filteredMarketListingsProvider(_filters));
      ref.invalidate(savedMarketListingsProvider);
      if (mounted) {
        AppFeedback.success(
          context,
          wasSaved
              ? AppStrings.listingsUnsavedToast
              : AppStrings.listingsSavedToast,
        );
      }
    } catch (e) {
      debugPrint('[FirinNet][Market] toggle save error: $e');
      if (mounted) {
        AppFeedback.error(context, AppStrings.listingsSaveToggleError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMarketListingsProvider(_filters));
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.brandInk,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              if (!widget.embedded) ...[
                SliverToBoxAdapter(
                  child: FirinNetHeader(
                    title: AppStrings.marketTitle,
                    subtitle: AppStrings.marketSubtitle,
                    actions: [
                      HeaderActionButton(
                        icon: Icons.tune_rounded,
                        tooltip: AppStrings.marketFilterCta,
                        onTap: _openFilters,
                      ),
                      const SizedBox(width: 6),
                      HeaderActionButton(
                        icon: Icons.add_rounded,
                        tooltip: AppStrings.marketListingAddCta,
                        onTap: _onAddPressed,
                      ),
                    ],
                  ),
                ),
                // Görsel kalite — header ile içerik arası çok hafif ayraç.
                const SliverToBoxAdapter(
                  child: Divider(
                    height: 1,
                    thickness: 0.6,
                    color: AppColors.borderHairline,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s)),
                SliverToBoxAdapter(
                  child: _ListingTypeChipRow(
                    selected: _filters.listingType,
                    onSelect: _setListingType,
                  ),
                ),
              ],
              // Gömülü segmentte listing_type kilitli → type chip satırı yok;
              // yerine kompakt "Filtrele (n)" + aktif filtre rozetleri.
              if (widget.embedded || _filters.activeCount > 0)
                SliverToBoxAdapter(
                  child: _ActiveFilterChipRow(
                    filters: _filters,
                    hideListingType: widget.embedded,
                    leading: widget.embedded
                        ? _FilterPill(
                            count: _extraFilterCount,
                            onTap: _openFilters,
                          )
                        : null,
                    showClear: _extraFilterCount > 0,
                    onClear: () => setState(() => _filters = _baseFilters),
                    onRemoveType: () => setState(
                      () =>
                          _filters = _filters.copyWith(clearListingType: true),
                    ),
                    onRemoveEquipment: () => setState(
                      () => _filters = _filters.copyWith(
                        clearEquipmentCategory: true,
                      ),
                    ),
                    onRemoveCity: () => setState(
                      () => _filters = _filters.copyWith(clearCity: true),
                    ),
                    onRemoveDistrict: () => setState(
                      () => _filters = _filters.copyWith(clearDistrict: true),
                    ),
                    onRemovePrice: () => setState(
                      () => _filters = _filters.copyWith(
                        clearMinPrice: true,
                        clearMaxPrice: true,
                      ),
                    ),
                    onRemoveCondition: () => setState(
                      () => _filters = _filters.copyWith(clearCondition: true),
                    ),
                    onRemoveNegotiable: () => setState(
                      () => _filters = _filters.copyWith(negotiableOnly: false),
                    ),
                  ),
                ),
              async.when(
                // Perf: ilan oluşturma/kaydet-toggle sonrası liste eski
                // içeriğini korur, spinner flash yok.
                skipLoadingOnReload: true,
                // Polish 2 — ilk yüklemede tek spinner yerine hafif iskelet.
                loading: () => const SliverToBoxAdapter(
                  child: ListingSkeletonList(withImage: true),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ErrorRetryState(
                    compact: true,
                    title: AppStrings.listingsLoadError,
                    subtitle: AppStrings.listingsLoadErrorHint,
                    // UI-level retry — mevcut provider'ı yeniden tetikler
                    // (backend/provider logic değişmez).
                    onRetry: () => ref.invalidate(
                      filteredMarketListingsProvider(_filters),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    // M3 polish (C): filtre aktifse farklı mesaj + clear CTA;
                    // boş listede ise "İlk ilanı oluştur" CTA.
                    // Navigation IA: gömülü segmentte forceListingType bir aktif
                    // filtre sayılır; segmentin kendisi boşsa "filtreli" değil
                    // sade boş-state göster (activeCount>1 → gerçek ek filtre).
                    final filterActive = widget.embedded
                        ? _filters.activeCount > 1
                        : _filters.activeCount > 0;
                    return SliverToBoxAdapter(
                      child: _MarketEmptyState(
                        filterActive: filterActive,
                        onAddPressed: _onAddPressed,
                        // Gömülüde "temizle" forced tipi KORUR (segment kilidi
                        // kırılmasın); standalone'da tüm filtreleri sıfırlar.
                        onClearFilters: () =>
                            setState(() => _filters = _baseFilters),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.s,
                      AppSpacing.pageH,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.m),
                      itemBuilder: (_, i) {
                        final l = items[i];
                        return MarketplaceListingCard(
                          listing: l,
                          onTap: () => context.push('/market/listings/${l.id}'),
                          onToggleSave: l.id == null
                              ? null
                              : () => _toggleSave(l),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gömülü segment filtre girişi: "Filtrele" / "Filtrele (2)".
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? AppColors.brandLemonPale : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? AppColors.brandLemonSoft : AppColors.borderHairline,
          width: 0.8,
        ),
      ),
      child: InkWell(
        key: const ValueKey('market_filter_pill'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        // Polish 2 — en az 44px dokunma yüksekliği.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 15,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                active
                    ? '${AppStrings.marketFilterCta} ($count)'
                    : AppStrings.marketFilterCta,
                style: AppTypography.chipLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingTypeChipRow extends StatelessWidget {
  const _ListingTypeChipRow({required this.selected, required this.onSelect});

  final String? selected;
  final void Function(String? type) onSelect;

  @override
  Widget build(BuildContext context) {
    // Market UI Polish V1 - kanonik chip standardi:
    // secili lemon border + pale bg; pasif card bg + hairline.
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          _typeChip(label: AppStrings.finalFilterAll, value: null),
          const SizedBox(width: AppSpacing.s),
          for (final e in MarketplaceTaxonomy.listingTypes.entries) ...[
            _typeChip(label: e.value, value: e.key),
            const SizedBox(width: AppSpacing.s),
          ],
        ],
      ),
    );
  }

  Widget _typeChip({required String label, required String? value}) {
    final isSelected = selected == value;
    return DealerFilterChip(
      label: label,
      selected: isSelected,
      onSelected: (_) => onSelect(value),
    );
  }
}

class _ActiveFilterChipRow extends StatelessWidget {
  const _ActiveFilterChipRow({
    required this.filters,
    this.hideListingType = false,
    this.leading,
    this.showClear = true,
    required this.onClear,
    required this.onRemoveType,
    required this.onRemoveEquipment,
    required this.onRemoveCity,
    required this.onRemoveDistrict,
    required this.onRemovePrice,
    required this.onRemoveCondition,
    required this.onRemoveNegotiable,
  });

  final MarketFilters filters;

  /// Gömülü segmentte tip kilitli → tip rozeti gösterilmez.
  final bool hideListingType;

  /// Satır başı (gömülüde "Filtrele (n)" pill'i).
  final Widget? leading;
  final bool showClear;
  final VoidCallback onClear;
  final VoidCallback onRemoveType;
  final VoidCallback onRemoveEquipment;
  final VoidCallback onRemoveCity;
  final VoidCallback onRemoveDistrict;
  final VoidCallback onRemovePrice;
  final VoidCallback onRemoveCondition;
  final VoidCallback onRemoveNegotiable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.s,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ?leading,
          if (filters.listingType != null && !hideListingType)
            _RemovableChip(
              label:
                  MarketplaceTaxonomy.listingTypes[filters.listingType!] ??
                  filters.listingType!,
              onRemove: onRemoveType,
            ),
          if (filters.equipmentCategory != null)
            _RemovableChip(
              label:
                  MarketplaceTaxonomy.equipmentCategories[filters
                      .equipmentCategory!] ??
                  filters.equipmentCategory!,
              onRemove: onRemoveEquipment,
            ),
          if ((filters.city ?? '').isNotEmpty)
            _RemovableChip(label: filters.city!, onRemove: onRemoveCity),
          if ((filters.district ?? '').isNotEmpty)
            _RemovableChip(
              label: filters.district!,
              onRemove: onRemoveDistrict,
            ),
          if (filters.minPrice != null || filters.maxPrice != null)
            _RemovableChip(
              label: _priceRangeLabel(filters),
              onRemove: onRemovePrice,
            ),
          if (filters.condition != null)
            _RemovableChip(
              label:
                  MarketplaceTaxonomy.conditions[filters.condition!] ??
                  filters.condition!,
              onRemove: onRemoveCondition,
            ),
          if (filters.negotiableOnly)
            _RemovableChip(
              label: AppStrings.marketFilterNegotiable,
              onRemove: onRemoveNegotiable,
            ),
          if (showClear)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: Text(
                leading != null
                    ? AppStrings.listingsFilterClear
                    : AppStrings.marketFilterClearAll,
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
                textStyle: AppTypography.chipLabel,
              ),
            ),
        ],
      ),
    );
  }

  static String _priceRangeLabel(MarketFilters f) {
    final lo = f.minPrice;
    final hi = f.maxPrice;
    if (lo != null && hi != null) {
      return '${ListingFormat.price(lo)} – ${ListingFormat.amount(hi)}';
    }
    if (lo != null) return '≥ ${ListingFormat.price(lo)}';
    if (hi != null) return '≤ ${ListingFormat.price(hi)}';
    return '';
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Aktif filtre rozeti - lemon pale bg + hairline + koyu label.
    // Polish 2 — rozetin tamamı kaldırma hedefi (≥ 44px yükseklik);
    // metin/ikon mürekkep tonunda.
    return Semantics(
      button: true,
      label: '$label, ${AppStrings.listingsRemoveFilterTooltip}',
      excludeSemantics: true,
      child: Tooltip(
        message: AppStrings.listingsRemoveFilterTooltip,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.chipLabel.copyWith(
                          color: AppColors.brandInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.brandInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// M3 polish (C): boş/filtre-empty durum için ikon + başlık + alt
/// açıklama + birincil CTA. Filtre aktifse "Filtreleri temizle" alternatifi
/// gösterilir; boş liste için "İlk ilanı oluştur" CTA.
class _MarketEmptyState extends StatelessWidget {
  const _MarketEmptyState({
    required this.filterActive,
    required this.onAddPressed,
    required this.onClearFilters,
  });

  final bool filterActive;
  final VoidCallback onAddPressed;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final title = filterActive
        ? AppStrings.marketEmptyFilteredTitle
        : AppStrings.marketEmptyTitle;
    final subtitle = filterActive
        ? AppStrings.marketEmptyFilteredSubtitle
        : AppStrings.marketEmptySubtitle;
    final icon = filterActive
        ? Icons.filter_alt_off_outlined
        : Icons.storefront_outlined;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xxxl,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderHairline, width: 0.8),
              ),
              child: Icon(icon, size: 22, color: AppColors.brandInk),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.m),
            if (filterActive)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  key: const ValueKey('market_empty_clear_filters'),
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text(AppStrings.marketEmptyClearFiltersCta),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: AppTypography.buttonLabel,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(AppStrings.marketEmptyCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: AppTypography.buttonLabel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
