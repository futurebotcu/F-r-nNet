import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';

/// V1 Market — gerçek `market_listings` verisine bağlı (V2 sprint sonrası
/// coming-soon kaldırıldı). Authenticated user kendi ilanını yayınlayabilir;
/// herkes aktif ilanları okur.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String? _activeCategory;

  Future<void> _onAddPressed() async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    context.push(AppRoutes.marketListingNew);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeMarketListingsProvider(_activeCategory));
    final user = ref.watch(currentAuthUserProvider);
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
                    icon: Icons.add_rounded,
                    tooltip: AppStrings.marketListingAddCta,
                    onTap: _onAddPressed,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
                  scrollDirection: Axis.horizontal,
                  itemCount: AppStrings.marketCategoryLabels.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final selected = _activeCategory == null;
                      return ChoiceChip(
                        label: const Text('Tümü'),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _activeCategory = null),
                      );
                    }
                    final entry =
                        AppStrings.marketCategoryLabels.entries.toList()[i - 1];
                    final selected = _activeCategory == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _activeCategory = entry.key),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionLabel(title: 'Aktif ilanlar'),
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
                  return SliverToBoxAdapter(
                    child: _MarketMessage(
                      icon: Icons.inbox_outlined,
                      message: user == null
                          ? AppStrings.marketListingEmptyGuest
                          : AppStrings.marketListingEmpty,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    0,
                    AppSpacing.pageH,
                    AppSpacing.l,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: _MarketListingCard(listing: items[i]),
                      ),
                      childCount: items.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _MarketListingCard extends StatelessWidget {
  const _MarketListingCard({required this.listing});
  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel =
        AppStrings.marketCategoryLabels[listing.category] ?? listing.category;
    final priceText = listing.price == null
        ? '—'
        : '₺ ${listing.price!.toStringAsFixed(0)}'
            '${listing.unit != null && listing.unit!.isNotEmpty ? ' / ${listing.unit}' : ''}';
    final city = (listing.city ?? '').trim();
    final district = (listing.district ?? '').trim();
    final location = city.isEmpty && district.isEmpty
        ? '—'
        : (district.isEmpty
            ? city
            : (city.isEmpty ? district : '$city · $district'));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: AppColors.borderHairline, width: 0.6),
                ),
                child: Text(
                  categoryLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          if (listing.description != null && listing.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(
                listing.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(icon: Icons.payments_outlined, label: priceText),
              _Pill(icon: Icons.place_outlined, label: location),
              if (listing.authorName != null &&
                  listing.authorName!.isNotEmpty)
                _Pill(icon: Icons.storefront_outlined, label: listing.authorName!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.softGold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
              color: AppColors.borderHairline, width: 0.6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.softGold, size: 20),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
