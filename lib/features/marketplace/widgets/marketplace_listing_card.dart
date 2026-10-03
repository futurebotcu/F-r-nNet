// FırınNet Market V1 M2 — Listing card widget.
//
// Donor pattern: Bagisto opensource-ecommerce-mobile-app
// (product list card + image + title + price + meta). FırınNet
// classified marketplace adaptasyonu:
//   * Twitter/Facebook readability (büyük başlık + okunabilir meta).
//   * Listing_type rozet (Ekipman satışı / Fırın devri).
//   * Image thumbnail (cached_network_image); placeholder içeride.
//   * Tap → detail route. Save action sağ üst köşede.
//
// İlanlar tasarım geçişi: hiyerarşi tür rozeti → başlık → fiyat (doğru para
// birimi + binlik ayıraç) → konum → ilan sahibi · göreli tarih. Görselsiz
// ilan 4:3 gri blok yerine daha kısa 16:9 tür-özel yer tutucu
// ("Fotoğraf yok") gösterir.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../listings/utils/listing_format.dart';
import '../../subscriptions/widgets/listing_fee_notice.dart';
import '../data/marketplace_taxonomy.dart';
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

  /// Kart/paylaşım için tek satır fiyat: "₺ 850.000 devir",
  /// "€ 1.200 / adet", fiyat yoksa "Fiyat sorunuz".
  static String priceLabel(MarketListing listing) {
    final cur = listing.currency;
    if (listing.isBakeryTransfer) {
      final transfer = listing.transferPrice;
      if (transfer != null) {
        return '${ListingFormat.price(transfer, currency: cur)} '
            '${AppStrings.listingsPriceTransferSuffix}';
      }
      final rent = listing.rentPrice;
      if (rent != null) {
        return '${ListingFormat.price(rent, currency: cur)}'
            '${AppStrings.listingsPriceRentSuffix}';
      }
      return AppStrings.listingsPriceAsk;
    }
    final price = listing.price;
    if (price == null) return AppStrings.listingsPriceAsk;
    final unit = (listing.unit ?? '').trim();
    return '${ListingFormat.price(price, currency: cur)}'
        '${unit.isNotEmpty ? ' / $unit' : ''}';
  }

  String? _locationLabel() {
    final city = (listing.city ?? '').trim();
    final district = (listing.district ?? '').trim();
    if (city.isEmpty && district.isEmpty) return null;
    if (district.isEmpty) return city;
    if (city.isEmpty) return district;
    return '$city · $district';
  }

  String _typeLabel() {
    return MarketplaceTaxonomy.listingTypes[listing.listingType] ??
        listing.listingType;
  }

  String _metaLabel() {
    final owner = (listing.authorName ?? '').trim();
    final created = listing.createdAt;
    return [
      if (owner.isNotEmpty) owner,
      if (created != null) ListingFormat.relative(created),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.firstMedia?.publicUrl;
    final location = _locationLabel();
    final meta = _metaLabel();
    final hasPrice = listing.isBakeryTransfer
        ? (listing.transferPrice != null || listing.rentPrice != null)
        : listing.price != null;
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
              // Kart küçük resmi BoxFit.cover ile kırpılır (detay/tam ekran
              // contain kullanır). Görselsiz ilan daha kısa 16:9 alan.
              AspectRatio(
                aspectRatio: imageUrl != null ? 4 / 3 : 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            720, // Perf: kart görseli; decode sınırı.
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _PlaceholderArt(
                          isBakeryTransfer: listing.isBakeryTransfer,
                        ),
                      )
                    else
                      _PlaceholderArt(
                        isBakeryTransfer: listing.isBakeryTransfer,
                      ),
                    // Listing type rozet (sol üst)
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 56,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _TypeBadge(label: _typeLabel()),
                      ),
                    ),
                    // İlan Ücretlendirme V1 — owner kendi pending ilanında
                    // "Ödeme bekliyor" görür (public zaten pending görmez).
                    if (listing.isPendingPayment)
                      const Positioned(
                        left: 10,
                        top: 40,
                        child: ListingPendingBadge(),
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
                                    ? AppColors.brandLemon
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
              // ── Title + price + location + owner/date ──
              Padding(
                // Faz 2 Pass 4 — ferah dikey ritim (kart sıkışık görünmesin).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 16.5,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          priceLabel(listing),
                          style: TextStyle(
                            color: hasPrice
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: hasPrice ? 15.5 : 14,
                          ),
                        ),
                        if (listing.negotiable) const _NegotiableChip(),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 6),
                      _MetaLine(icon: Icons.place_outlined, text: location),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _MetaLine(icon: Icons.person_outline_rounded, text: meta),
                    ],
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
          color: AppColors.brandInk,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.isBakeryTransfer});

  final bool isBakeryTransfer;

  @override
  Widget build(BuildContext context) {
    // Görselsiz ilan — sakin nötr yüzey + tür ikonu + "Fotoğraf yok"
    // (sahte görsel değil).
    return Container(
      key: const ValueKey('market_card_no_photo'),
      color: AppColors.surfaceLine,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBakeryTransfer
                ? Icons.storefront_outlined
                : Icons.kitchen_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.listingsNoPhoto,
            style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
