// FırınNet Market V1 M2 — Detail screen.
//
// Donor pattern: Bagisto `product_detail_page.dart` layout:
//   AppBar (back + share) + image carousel + info section (title + price)
//   + description + attributes section + sticky action bar.
// FırınNet adaptasyonu:
//   * Cart/checkout YOK → contact panel (in-app message / phone / whatsapp).
//   * Listing_type'a göre attributes farklı (equipment_sale vs bakery_transfer).
//   * Owner profili tap → /u/:userId (sosyal sprint route).
//   * Owner için ⋮ menü: Düzenle / İlanı kapat (status=paused) / Sil (soft).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';
import '../widgets/marketplace_contact_panel.dart';
import '../widgets/marketplace_image_gallery.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({super.key, required this.listingId});

  final String listingId;

  Future<void> _toggleSave(WidgetRef ref, MarketListing l) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      // UI tarafında BuildContext gerek; caller buradan değil onTap'ten çağırır.
      return;
    }
    final repo = ref.read(marketListingRepositoryProvider);
    try {
      if (l.isSavedByMe) {
        await repo.unsaveListing(l.id!);
      } else {
        await repo.saveListing(l.id!);
      }
      ref.invalidate(marketListingByIdProvider(listingId));
      ref.invalidate(savedMarketListingsProvider);
    } catch (e) {
      debugPrint('[FirinNet][MarketDetail] toggle save error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketListingByIdProvider(listingId));
    final me = ref.watch(currentAuthUserProvider);
    return PremiumScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          AppStrings.marketDetailTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17.5,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          async.maybeWhen(
            data: (l) {
              if (l == null) return const SizedBox.shrink();
              final isOwner = me != null && me.id == l.ownerId;
              if (!isOwner) {
                return IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  color: AppColors.textPrimary,
                  onPressed: () => shareListing(l),
                );
              }
              return PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textPrimary,
                ),
                color: AppColors.surface,
                onSelected: (v) => _ownerAction(context, ref, l, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text('Düzenle'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Text('İlanı duraklat'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sold',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Text('Satıldı/Devredildi olarak işaretle'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'İlanı sil',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              AppStrings.marketListingErrorGeneric,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (l) {
          if (l == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Bu ilan artık görünür değil.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return _DetailBody(listing: l);
        },
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (l) {
          if (l == null) return null;
          return MarketplaceContactPanel(
            listing: l,
            onInAppMessage: () => _onInAppMessage(context, ref, l),
            onShare: () => shareListing(l),
            onToggleSave: () => _onToggleSaveTap(context, ref, l),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Future<void> _onToggleSaveTap(
    BuildContext context,
    WidgetRef ref,
    MarketListing l,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    await _toggleSave(ref, l);
  }

  Future<void> _onInAppMessage(
    BuildContext context,
    WidgetRef ref,
    MarketListing l,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    // M1.2: generic messaging sistemine geçildi. Owner ilanına kendi
    // başlatamaz (RPC SECURITY DEFINER taraf self-DM ve owner mismatch
    // reddi yapar; UI tarafında da pre-check).
    final me = ref.read(currentAuthUserProvider);
    if (l.id == null || l.ownerId == null) return;
    if (me != null && me.id == l.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendi ilanına mesaj başlatamazsın.')),
      );
      return;
    }
    try {
      final convId = await ref
          .read(messagingRepositoryProvider)
          .findOrCreateDirectConversation(
            otherUserId: l.ownerId!,
            contextType: 'market_listing',
            contextId: l.id,
          );
      if (!context.mounted) return;
      context.push('/messages/$convId');
    } on GuestActionRequiredException {
      if (context.mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][Market] open chat error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.messagingStartError)),
        );
      }
    }
  }

  Future<void> _ownerAction(
    BuildContext context,
    WidgetRef ref,
    MarketListing l,
    String action,
  ) async {
    final repo = ref.read(marketListingRepositoryProvider);
    try {
      switch (action) {
        case 'edit':
          context.push(AppRoutes.marketListingEdit(l.id!));
          return;
        case 'pause':
          await repo.setStatus(l.id!, 'paused');
          break;
        case 'sold':
          await repo.setStatus(l.id!, 'sold');
          break;
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.surface,
              content: const Text('Bu ilanı silmek istiyor musun?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                  ),
                  child: const Text('Sil'),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await repo.softDeleteListing(l.id!);
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('İlan silindi.')));
          ref.invalidate(activeMarketListingsProvider(null));
          ref.invalidate(myMarketListingsProvider);
          context.pop();
          return;
      }
      ref.invalidate(marketListingByIdProvider(l.id!));
      ref.invalidate(activeMarketListingsProvider(null));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İlan güncellendi.')));
      }
    } catch (e) {
      debugPrint('[FirinNet][MarketDetail] owner action error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.marketListingErrorGeneric)),
        );
      }
    }
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.listing});
  final MarketListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrls = listing.mediaList
        .map((m) => m.publicUrl)
        .toList(growable: false);
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      children: [
        MarketplaceImageGallery(imageUrls: imageUrls),
        const SizedBox(height: AppSpacing.m),
        _InfoSection(listing: listing),
        if ((listing.description ?? '').trim().isNotEmpty) ...[
          const Divider(
            height: 1,
            thickness: 0.6,
            color: AppColors.borderHairline,
          ),
          _SectionLabel(label: AppStrings.marketDetailDescription),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.s,
              AppSpacing.pageH,
              AppSpacing.l,
            ),
            child: Text(
              listing.description!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
        ],
        const Divider(
          height: 1,
          thickness: 0.6,
          color: AppColors.borderHairline,
        ),
        _SectionLabel(label: AppStrings.marketDetailAttributes),
        _AttributesGrid(listing: listing),
        const Divider(
          height: 1,
          thickness: 0.6,
          color: AppColors.borderHairline,
        ),
        _OwnerSection(listing: listing),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.listing});
  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: Text(
              AppStrings.marketListingTypeLabels[listing.listingType] ?? '',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            listing.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          _PriceBlock(listing: listing),
          if ((listing.city ?? '').isNotEmpty ||
              (listing.district ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            // M3 polish: controlled-data lokasyon chip görünümü — basit
            // ikon + metin yerine yumuşak softGold rozet (B planı).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((listing.city ?? '').isNotEmpty)
                  _LocationChip(label: listing.city!),
                if ((listing.district ?? '').isNotEmpty)
                  _LocationChip(label: listing.district!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.listing});
  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.isBakeryTransfer) {
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (listing.transferPrice != null)
            _PriceLine(
              label: AppStrings.marketAttrTransferPrice,
              value: '₺ ${listing.transferPrice!.toStringAsFixed(0)}',
            ),
          if (listing.rentPrice != null)
            _PriceLine(
              label: AppStrings.marketAttrRentPrice,
              value: '₺ ${listing.rentPrice!.toStringAsFixed(0)}/ay',
            ),
        ],
      );
    }
    if (listing.price == null) {
      return const Text(
        'Fiyat belirtilmemiş',
        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
      );
    }
    final unit = (listing.unit ?? '').isEmpty ? '' : ' / ${listing.unit}';
    return Text(
      '₺ ${listing.price!.toStringAsFixed(0)}$unit',
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 22,
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _AttributesGrid extends StatelessWidget {
  const _AttributesGrid({required this.listing});
  final MarketListing listing;

  List<MapEntry<String, String>> _entries() {
    final out = <MapEntry<String, String>>[];
    out.add(
      MapEntry(
        AppStrings.marketAttrCategory,
        AppStrings.marketCategoryLabels[listing.category] ?? listing.category,
      ),
    );
    if (listing.isEquipmentSale) {
      if (listing.equipmentCategory != null) {
        out.add(
          MapEntry(
            AppStrings.marketAttrEquipmentCategory,
            AppStrings.marketEquipmentCategoryLabels[listing
                    .equipmentCategory] ??
                listing.equipmentCategory!,
          ),
        );
      }
      if (listing.brand != null && listing.brand!.isNotEmpty) {
        out.add(MapEntry(AppStrings.marketAttrBrand, listing.brand!));
      }
      if (listing.model != null && listing.model!.isNotEmpty) {
        out.add(MapEntry(AppStrings.marketAttrModel, listing.model!));
      }
      if (listing.year != null) {
        out.add(MapEntry(AppStrings.marketAttrYear, '${listing.year}'));
      }
      if (listing.condition != null) {
        out.add(
          MapEntry(
            AppStrings.marketAttrCondition,
            AppStrings.marketConditionLabels[listing.condition!] ??
                listing.condition!,
          ),
        );
      }
    }
    if (listing.isBakeryTransfer) {
      if (listing.areaM2 != null) {
        out.add(MapEntry(AppStrings.marketAttrAreaM2, '${listing.areaM2} m²'));
      }
      if (listing.equipmentIncluded != null) {
        out.add(
          MapEntry(
            AppStrings.marketAttrEquipmentIncluded,
            listing.equipmentIncluded!
                ? AppStrings.marketAttrYes
                : AppStrings.marketAttrNo,
          ),
        );
      }
      if (listing.hasLicense != null) {
        out.add(
          MapEntry(
            AppStrings.marketAttrHasLicense,
            listing.hasLicense!
                ? AppStrings.marketAttrYes
                : AppStrings.marketAttrNo,
          ),
        );
      }
    }
    if (listing.negotiable) {
      out.add(
        MapEntry(AppStrings.marketAttrNegotiable, AppStrings.marketAttrYes),
      );
    }
    // M3 polish: controlled-data taxonomy label vurgusu.
    final contactLabel = MarketplaceTaxonomy.contactPreferenceLabel(
      listing.contactPreference,
    );
    if (contactLabel.isNotEmpty) {
      out.add(MapEntry('İletişim', contactLabel));
    }
    if (listing.currency.isNotEmpty &&
        listing.currency != MarketplaceTaxonomy.defaultCurrency) {
      final cur = MarketplaceTaxonomy.currencyLabel(listing.currency);
      if (cur.isNotEmpty) {
        out.add(MapEntry(AppStrings.marketAttrCurrency, cur));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.s,
          AppSpacing.pageH,
          AppSpacing.l,
        ),
        child: Text(
          'Detay belirtilmemiş.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Column(
        children: entries
            .map((e) => _AttrRow(label: e.key, value: e.value))
            .toList(),
      ),
    );
  }
}

class _AttrRow extends StatelessWidget {
  const _AttrRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSection extends StatelessWidget {
  const _OwnerSection({required this.listing});
  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.ownerId == null) return const SizedBox.shrink();
    final name = (listing.authorName ?? '').isNotEmpty
        ? listing.authorName!
        : 'FırınNet Kullanıcısı';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: InkWell(
        onTap: () =>
            context.push('${AppRoutes.userPublicProfile}/${listing.ownerId}'),
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
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
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((listing.authorRole ?? '').isNotEmpty)
                      Text(
                        listing.authorRole!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M3 polish: detail InfoSection lokasyon vurgusu — yumuşak softGold
/// rozet (M2 type badge ile aynı görsel dil).
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
