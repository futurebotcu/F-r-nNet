// FırınNet Market V1 M2 — Listing card widget.
//
// Donor pattern: Bagisto opensource-ecommerce-mobile-app
// (product list card + image + title + price + meta). FırınNet
// classified marketplace adaptasyonu:
//   * Twitter/Facebook readability (büyük başlık + okunabilir meta).
//   * Listing_type rozet (Ekipman satışı / Fırın devri).
//   * Image thumbnail (cached_network_image); placeholder içeride.
//   * Tap → detail route. Save action sağ üst köşede.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/market_listing.dart';

class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    required this.onToggleSave,
  });

  final MarketListing listing;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

  String _priceLabel() {
    if (listing.isBakeryTransfer) {
      final transfer = listing.transferPrice;
      if (transfer != null) {
        return '₺ ${transfer.toStringAsFixed(0)} devir';
      }
      final rent = listing.rentPrice;
      if (rent != null) {
        return '₺ ${rent.toStringAsFixed(0)}/ay kira';
      }
      return '—';
    }
    if (listing.price == null) return '—';
    return '₺ ${listing.price!.toStringAsFixed(0)}'
        '${listing.unit != null && listing.unit!.isNotEmpty ? ' / ${listing.unit}' : ''}';
  }

  String _locationLabel() {
    final city = (listing.city ?? '').trim();
    final district = (listing.district ?? '').trim();
    if (city.isEmpty && district.isEmpty) return '—';
    if (district.isEmpty) return city;
    if (city.isEmpty) return district;
    return '$city · $district';
  }

  String _typeLabel() {
    return AppStrings.marketListingTypeLabels[listing.listingType] ??
        listing.listingType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = listing.firstMedia?.publicUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.l),
            // P0 token — daha yumuşak/rafine hairline; premium gölge aynı.
            border: Border.all(
              color: AppColors.borderHairline.withValues(alpha: 0.7),
              width: 0.6,
            ),
            boxShadow: AppShadow.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image + listing_type rozet + save toggle ──
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const _PlaceholderArt(),
                      )
                    else
                      const _PlaceholderArt(),
                    // Listing type rozet (sol üst)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _TypeBadge(label: _typeLabel()),
                    ),
                    // Save toggle (sağ üst)
                    if (onToggleSave != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          // P0 token — hardcoded siyah yerine medya scrim.
                          color: AppColors.imageScrimSoft,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onToggleSave,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                listing.isSavedByMe
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: listing.isSavedByMe
                                    ? AppColors.brandLemonPressed
                                    : AppColors.surface,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Title + price + location ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _priceLabel(),
                      style: const TextStyle(
                        color: AppColors.brandInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _locationLabel(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (listing.negotiable) ...[
                          const SizedBox(width: 8),
                          const _NegotiableChip(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // P0 token — görsel üstü okunabilirlik scrim'i (hardcoded siyah değil).
        color: AppColors.imageScrimDark,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.surface,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NegotiableChip extends StatelessWidget {
  const _NegotiableChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.6),
      ),
      child: const Text(
        'Pazarlık',
        style: TextStyle(
          color: AppColors.brandLemonPressed,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt();

  @override
  Widget build(BuildContext context) {
    // Gorselsiz ilan - white-first yuzey + lemon accent detay.
    // ikon (sahte görsel değil; FırınNet premium placeholder dili).
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroTo],
        ),
      ),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
        ),
        child: const Icon(
          Icons.storefront_outlined,
          size: 30,
          color: AppColors.brandLemonPressed,
        ),
      ),
    );
  }
}
