// FırınNet Market V1 M2 — Listing card widget.
//
// Donor pattern: Bagisto opensource-ecommerce-mobile-app
// (product list card + image + title + price + meta). FırınNet
// classified marketplace adaptasyonu:
//   * Twitter/Facebook readability (büyük başlık + okunabilir meta).
//   * Listing_type rozet (Ekipman satışı / Fırın devri).
//   * Image thumbnail (AppNetworkImage — CachedNetworkImage sarmalayıcısı;
//     yükleniyor/hata/görsel yok durumları tek dilde).
//   * Tap → detail route. Save action sağ üst köşede.
//
// İlanlar tasarım geçişi: hiyerarşi tür rozeti → başlık → fiyat (doğru para
// birimi + binlik ayıraç) → konum → ilan sahibi · göreli tarih. Görselsiz
// ilan 4:3 gri blok yerine daha kısa 16:9 tür-özel yer tutucu
// ("Fotoğraf yok") gösterir.
//
// Polish 2: tipografi rolleri (cardTitle/price/badge/meta/caption), göreli
// tarih sakin `caption` olarak sağda, kaydet düğmesi 44px dokunma alanı +
// tooltip, kırık görsel ikonu yok (AppImageState).

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_network_image.dart';
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

  /// İlan fiyatı var mı (yoksa "Fiyat sorunuz" ikincil tonda).
  static bool hasPrice(MarketListing listing) => listing.isBakeryTransfer
      ? (listing.transferPrice != null || listing.rentPrice != null)
      : listing.price != null;

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

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.firstMedia?.publicUrl;
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    final location = _locationLabel();
    final owner = (listing.authorName ?? '').trim();
    final created = listing.createdAt;
    final time = created == null ? '' : ListingFormat.relative(created);
    final priced = hasPrice(listing);
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
                aspectRatio: hasImage ? 4 / 3 : 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      AppNetworkImage(
                        url: imageUrl,
                        memCacheWidth:
                            720, // Perf: kart görseli; decode sınırı.
                      )
                    else
                      _PlaceholderArt(
                        isBakeryTransfer: listing.isBakeryTransfer,
                      ),
                    // Listing type rozet (sol üst)
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 60,
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
                    // Save toggle (sağ üst) — 44px dokunma alanı.
                    if (onToggleSave != null)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _SaveButton(
                          saved: listing.isSavedByMe,
                          onTap: onToggleSave!,
                        ),
                      ),
                  ],
                ),
              ),
              // ── Title + price + location + owner/date ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: AppTypography.cardTitle,
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
                          style: priced
                              ? AppTypography.price
                              : AppTypography.price.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                        ),
                        if (listing.negotiable) const _NegotiableChip(),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 6),
                      _MetaLine(icon: Icons.place_outlined, text: location),
                    ],
                    if (owner.isNotEmpty || time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _MetaLine(
                        icon: Icons.person_outline_rounded,
                        text: owner,
                        trailing: time,
                      ),
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = saved
        ? AppStrings.listingsUnsaveTooltip
        : AppStrings.listingsSaveTooltip;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: saved,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          key: const ValueKey('market_card_save'),
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                // Görsel daire küçük (36px); dokunma alanı 44px.
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    // P0 token — hardcoded siyah yerine medya scrim.
                    color: AppColors.imageScrimSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    // Koyu scrim üzerinde limon ikon (beyaz/soluk zemin değil).
                    color: saved ? AppColors.brandLemon : AppColors.surface,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Konum / sahip satırı: okunur metin (textSecondary) + sağda sakin tarih.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = (trailing ?? '').trim();
    if (text.isEmpty) {
      return Text(t, style: AppTypography.caption, maxLines: 1);
    }
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
        if (t.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s),
          Text(t, style: AppTypography.caption, maxLines: 1),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // P0 token — görsel üstü okunabilirlik scrim'i (hardcoded siyah değil).
        color: AppColors.imageScrimDark,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.badge.copyWith(color: AppColors.surface),
      ),
    );
  }
}

class _NegotiableChip extends StatelessWidget {
  const _NegotiableChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.6),
      ),
      child: Text(AppStrings.marketAttrNegotiable, style: AppTypography.badge),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.isBakeryTransfer});

  final bool isBakeryTransfer;

  @override
  Widget build(BuildContext context) {
    // Görselsiz ilan — ortak "görsel yok" durumu + tür ikonu + "Fotoğraf yok"
    // (sahte görsel değil, kırık görsel ikonu değil).
    return KeyedSubtree(
      key: const ValueKey('market_card_no_photo'),
      child: AppImageState.empty(
        icon: isBakeryTransfer
            ? Icons.storefront_outlined
            : Icons.kitchen_outlined,
        label: AppStrings.listingsNoPhoto,
      ),
    );
  }
}
