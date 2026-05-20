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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/market_filters.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';
import '../widgets/marketplace_filters_sheet.dart';
import '../widgets/marketplace_listing_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  MarketFilters _filters = const MarketFilters();

  Future<void> _onAddPressed() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    context.push(AppRoutes.marketListingNew);
  }

  Future<void> _openFilters() async {
    final result = await MarketplaceFiltersSheet.show(
      context,
      initial: _filters,
    );
    if (result != null) {
      setState(() => _filters = result);
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
    try {
      if (l.isSavedByMe) {
        await repo.unsaveListing(l.id!);
      } else {
        await repo.saveListing(l.id!);
      }
      ref.invalidate(filteredMarketListingsProvider(_filters));
      ref.invalidate(savedMarketListingsProvider);
    } catch (e) {
      debugPrint('[FirinNet][Market] toggle save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredMarketListingsProvider(_filters));
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
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
            SliverToBoxAdapter(
              child: _ListingTypeChipRow(
                selected: _filters.listingType,
                onSelect: _setListingType,
              ),
            ),
            if (_filters.activeCount > 0)
              SliverToBoxAdapter(
                child: _ActiveFilterChipRow(
                  filters: _filters,
                  onClear: () => setState(() => _filters = const MarketFilters()),
                  onRemoveType: () =>
                      setState(() => _filters = _filters.copyWith(clearListingType: true)),
                  onRemoveEquipment: () =>
                      setState(() => _filters = _filters.copyWith(clearEquipmentCategory: true)),
                  onRemoveCity: () =>
                      setState(() => _filters = _filters.copyWith(clearCity: true)),
                  onRemovePrice: () => setState(() => _filters = _filters.copyWith(
                        clearMinPrice: true,
                        clearMaxPrice: true,
                      )),
                  onRemoveCondition: () =>
                      setState(() => _filters = _filters.copyWith(clearCondition: true)),
                  onRemoveNegotiable: () => setState(
                      () => _filters = _filters.copyWith(negotiableOnly: false)),
                ),
              ),
            async.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: _MarketMessage(
                  icon: Icons.cloud_off_outlined,
                  message: AppStrings.marketListingErrorGeneric,
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _MarketMessage(
                      icon: Icons.inbox_outlined,
                      message: AppStrings.marketListingEmpty,
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
                        onTap: () => context.push(
                          '/market/listings/${l.id}',
                        ),
                        onToggleSave:
                            l.id == null ? null : () => _toggleSave(l),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingTypeChipRow extends StatelessWidget {
  const _ListingTypeChipRow({
    required this.selected,
    required this.onSelect,
  });

  final String? selected;
  final void Function(String? type) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
        children: [
          _typeChip(label: 'Tümü', value: null),
          const SizedBox(width: 8),
          for (final e in AppStrings.marketListingTypeLabels.entries) ...[
            _typeChip(label: e.value, value: e.key),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _typeChip({required String label, required String? value}) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.softGold.withValues(alpha: 0.18),
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.softGold : AppColors.borderHairline,
        width: isSelected ? 1.0 : 0.6,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.softGold : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => onSelect(value),
    );
  }
}

class _ActiveFilterChipRow extends StatelessWidget {
  const _ActiveFilterChipRow({
    required this.filters,
    required this.onClear,
    required this.onRemoveType,
    required this.onRemoveEquipment,
    required this.onRemoveCity,
    required this.onRemovePrice,
    required this.onRemoveCondition,
    required this.onRemoveNegotiable,
  });

  final MarketFilters filters;
  final VoidCallback onClear;
  final VoidCallback onRemoveType;
  final VoidCallback onRemoveEquipment;
  final VoidCallback onRemoveCity;
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
          if (filters.listingType != null)
            _RemovableChip(
              label: AppStrings.marketListingTypeLabels[filters.listingType!] ??
                  filters.listingType!,
              onRemove: onRemoveType,
            ),
          if (filters.equipmentCategory != null)
            _RemovableChip(
              label: AppStrings.marketEquipmentCategoryLabels[
                      filters.equipmentCategory!] ??
                  filters.equipmentCategory!,
              onRemove: onRemoveEquipment,
            ),
          if ((filters.city ?? '').isNotEmpty)
            _RemovableChip(label: filters.city!, onRemove: onRemoveCity),
          if (filters.minPrice != null || filters.maxPrice != null)
            _RemovableChip(
              label: _priceRangeLabel(filters),
              onRemove: onRemovePrice,
            ),
          if (filters.condition != null)
            _RemovableChip(
              label: AppStrings.marketConditionLabels[filters.condition!] ??
                  filters.condition!,
              onRemove: onRemoveCondition,
            ),
          if (filters.negotiableOnly)
            _RemovableChip(
              label: AppStrings.marketFilterNegotiable,
              onRemove: onRemoveNegotiable,
            ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text(AppStrings.marketFilterClearAll),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              visualDensity: VisualDensity.compact,
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
      return '₺${lo.toStringAsFixed(0)}–${hi.toStringAsFixed(0)}';
    }
    if (lo != null) return '≥ ₺${lo.toStringAsFixed(0)}';
    if (hi != null) return '≤ ₺${hi.toStringAsFixed(0)}';
    return '—';
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.softGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketMessage extends StatelessWidget {
  const _MarketMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.xxl,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.s),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
