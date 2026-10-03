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
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../listings/utils/listing_format.dart';
import '../../listings/widgets/listing_ui.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../messaging/repositories/messaging_repository.dart';
import '../../payments/widgets/listing_payment_button.dart';
import '../../safety/models/report_models.dart';
import '../../safety/widgets/block_user_dialog.dart';
import '../../safety/widgets/report_sheet.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';
import '../widgets/marketplace_contact_panel.dart';
import '../widgets/marketplace_image_gallery.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({super.key, required this.listingId});

  final String listingId;

  Future<void> _toggleSave(
    BuildContext context,
    WidgetRef ref,
    MarketListing l,
  ) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      // UI tarafında BuildContext gerek; caller buradan değil onTap'ten çağırır.
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
      ref.invalidate(marketListingByIdProvider(listingId));
      ref.invalidate(savedMarketListingsProvider);
      if (context.mounted) {
        AppFeedback.success(
          context,
          wasSaved
              ? AppStrings.listingsUnsavedToast
              : AppStrings.listingsSavedToast,
        );
      }
    } catch (e) {
      debugPrint('[FirinNet][MarketDetail] toggle save error: $e');
      if (context.mounted) {
        AppFeedback.error(context, AppStrings.listingsSaveToggleError);
      }
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
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // D2 — başlık ilan tipini söyler ("Fırın devri" / "Ekipman satışı").
        title: Text(
          async.maybeWhen(
            data: (l) {
              final t = l == null
                  ? ''
                  : MarketplaceTaxonomy.listingTypeLabel(l.listingType);
              return t.isEmpty ? AppStrings.marketDetailTitle : t;
            },
            orElse: () => AppStrings.marketDetailTitle,
          ),
          style: AppTypography.sectionTitle,
        ),
        actions: [
          async.maybeWhen(
            data: (l) {
              if (l == null) return const SizedBox.shrink();
              final isOwner = me != null && me.id == l.ownerId;
              if (!isOwner) {
                // UGC Safety V1 — ziyaretçi: paylaş + şikayet et + engelle.
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: AppStrings.marketContactShareCta,
                      icon: const Icon(Icons.ios_share_rounded),
                      color: AppColors.textPrimary,
                      onPressed: () => shareListing(l),
                    ),
                    PopupMenuButton<String>(
                      tooltip: AppStrings.listingsMoreActions,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textPrimary,
                      ),
                      color: AppColors.surface,
                      onSelected: (v) {
                        final id = l.id;
                        final ownerId = l.ownerId;
                        if (id == null) return;
                        if (v == 'report') {
                          showReportSheet(
                            context,
                            ref,
                            targetType: ReportTargetType.marketListing,
                            targetId: id,
                            reportedUserId: (ownerId == null || ownerId.isEmpty)
                                ? null
                                : ownerId,
                          );
                        }
                        if (v == 'block' &&
                            ownerId != null &&
                            ownerId.isNotEmpty) {
                          confirmAndBlockUser(context, ref, userId: ownerId);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'report',
                          child: Text(AppStrings.safetyActionReport),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text(
                            AppStrings.safetyActionBlock,
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return PopupMenuButton<String>(
                key: const ValueKey('market_owner_menu'),
                tooltip: AppStrings.listingsMoreActions,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textPrimary,
                ),
                color: AppColors.surface,
                onSelected: (v) => _ownerAction(context, ref, l, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8),
                        Flexible(child: Text(AppStrings.listingsEdit)),
                      ],
                    ),
                  ),
                  // Duraklatılmış ilan → "Yeniden yayınla" (mevcut setStatus
                  // 'active'); yayındaki ilan → "İlanı duraklat".
                  if (l.status == 'paused')
                    const PopupMenuItem(
                      value: 'republish',
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 8),
                          Flexible(child: Text(AppStrings.listingsRepublish)),
                        ],
                      ),
                    )
                  else if (l.status == 'active')
                    const PopupMenuItem(
                      value: 'pause',
                      child: Row(
                        children: [
                          Icon(
                            Icons.pause_circle_outline,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 8),
                          Flexible(child: Text('İlanı duraklat')),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'sold',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Satıldı/Devredildi olarak işaretle'),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'İlanı sil',
                            style: TextStyle(color: AppColors.danger),
                          ),
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
        // Perf: ilan sahibi aksiyonu (kaydet/duraklat) sonrası detay eski
        // içeriğini korur, spinner flash yok.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorRetryState(
          title: AppStrings.listingsDetailLoadError,
          subtitle: AppStrings.marketListingErrorGeneric,
          onRetry: () => ref.invalidate(marketListingByIdProvider(listingId)),
        ),
        data: (l) {
          if (l == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  AppStrings.listingsNotVisible,
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
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
          // Sahip kendi ilanında alıcı iletişim paneli yerine "Düzenle"
          // (+ duraklatılmışsa "Yeniden yayınla") görür.
          if (me != null && me.id == l.ownerId) {
            return _OwnerActionBar(
              listing: l,
              onEdit: () => _ownerAction(context, ref, l, 'edit'),
              onRepublish: l.status == 'paused'
                  ? () => _ownerAction(context, ref, l, 'republish')
                  : null,
            );
          }
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
    await _toggleSave(context, ref, l);
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
      AppFeedback.info(context, 'Kendi ilanına mesaj başlatamazsın.');
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
    } on BlockedConversationException {
      if (context.mounted) {
        PremiumTopBannerController.show(
          context,
          message: AppStrings.blockedMessageStartBanner,
          tone: PremiumTopBannerTone.warning,
        );
      }
    } catch (e) {
      debugPrint('[FirinNet][Market] open chat error: $e');
      if (context.mounted) {
        AppFeedback.error(context, AppStrings.messagingStartError);
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
          final okPause = await showAppConfirmDialog(
            context,
            title: AppStrings.listingsPauseConfirmTitle,
            message: AppStrings.listingsPauseConfirmBody,
            confirmLabel: AppStrings.listingsPauseCta,
            icon: Icons.pause_circle_outline_rounded,
          );
          if (!okPause || !context.mounted) return;
          await repo.setStatus(l.id!, 'paused');
          break;
        case 'sold':
          final okSold = await showAppConfirmDialog(
            context,
            title: AppStrings.listingsSoldConfirmTitle,
            message: AppStrings.listingsSoldConfirmBody,
            confirmLabel: AppStrings.listingsSoldCta,
            icon: Icons.check_circle_outline_rounded,
          );
          if (!okSold || !context.mounted) return;
          await repo.setStatus(l.id!, 'sold');
          break;
        case 'republish':
          // Mevcut status değeri; yeni backend çağrısı yok.
          await repo.setStatus(l.id!, 'active');
          break;
        case 'delete':
          final ok = await showAppConfirmDialog(
            context,
            title: AppStrings.listingsDeleteConfirmTitle,
            message: AppStrings.listingsDeleteConfirmBody,
            confirmLabel: AppStrings.listingsDeleteCta,
            destructive: true,
            icon: Icons.delete_outline_rounded,
          );
          if (!ok || !context.mounted) return;
          await repo.softDeleteListing(l.id!);
          if (!context.mounted) return;
          AppFeedback.success(context, AppStrings.listingsDeleted);
          ref.invalidate(activeMarketListingsProvider(null));
          ref.invalidate(myMarketListingsProvider);
          context.pop();
          return;
      }
      ref.invalidate(marketListingByIdProvider(l.id!));
      ref.invalidate(activeMarketListingsProvider(null));
      if (context.mounted) {
        AppFeedback.success(context, switch (action) {
          'republish' => AppStrings.listingsRepublishedToast,
          'pause' => AppStrings.listingsPausedToast,
          'sold' => AppStrings.listingsSoldToast,
          _ => AppStrings.listingsUpdated,
        });
      }
    } catch (e) {
      debugPrint('[FirinNet][MarketDetail] owner action error: $e');
      if (context.mounted) {
        AppFeedback.error(context, AppStrings.listingsActionError);
      }
    }
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.listing});
  final MarketListing listing;

  bool _isOwnPending(WidgetRef ref) {
    final me = ref.watch(currentAuthUserProvider);
    return listing.isPendingPayment &&
        listing.id != null &&
        me != null &&
        me.id == listing.ownerId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrls = listing.mediaList
        .map((m) => m.publicUrl)
        .toList(growable: false);
    final me = ref.watch(currentAuthUserProvider);
    final isOwner = me != null && me.id == listing.ownerId;
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      children: [
        MarketplaceImageGallery(
          imageUrls: imageUrls,
          placeholderIcon: listing.isBakeryTransfer
              ? Icons.storefront_outlined
              : Icons.kitchen_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        // Sahip: ilanın durumu insan diliyle (ham enum değil).
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.s,
            ),
            child: MarketOwnerStatusBanner(listing: listing),
          ),
        // Ücretli ilan (50 TL) — owner kendi pending ilanında öder ve yayınlar.
        if (_isOwnPending(ref)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.s,
            ),
            child: ListingPaymentButton(
              listingKind: 'market',
              listingId: listing.id ?? '',
            ),
          ),
        ],
        // Polish 2 sırası: başlık → fiyat → konum (InfoSection) → açıklama →
        // detaylar (etiket/değer) → ilan sahibi → tarihler. Boş bölüm çizilmez.
        _InfoSection(listing: listing),
        if ((listing.description ?? '').trim().isNotEmpty) ...[
          const _SectionDivider(),
          _SectionLabel(label: AppStrings.marketDetailDescription),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.l,
            ),
            child: Text(
              listing.description!.trim(),
              style: AppTypography.bodyLarge,
            ),
          ),
        ],
        if (_AttributesGrid.hasEntries(listing)) ...[
          const _SectionDivider(),
          _SectionLabel(label: AppStrings.marketDetailAttributes),
          _AttributesGrid(listing: listing),
        ],
        if (listing.ownerId != null) ...[
          const _SectionDivider(),
          _OwnerSection(listing: listing),
        ],
        if (_datesLabel(listing) case final dates?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.m,
            ),
            child: Text(dates, style: AppTypography.caption),
          ),
        const SizedBox(height: AppSpacing.xl),
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
            key: const ValueKey('market_detail_type_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandLemonPale,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
            ),
            child: Text(
              MarketplaceTaxonomy.listingTypeLabel(listing.listingType),
              style: AppTypography.badge,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(listing.title, style: AppTypography.detailTitle),
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

  static final TextStyle _askStyle = AppTypography.price.copyWith(
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final cur = listing.currency;
    if (listing.isBakeryTransfer) {
      if (listing.transferPrice == null && listing.rentPrice == null) {
        return Text(AppStrings.listingsPriceAsk, style: _askStyle);
      }
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (listing.transferPrice != null)
            _PriceLine(
              label: AppStrings.marketAttrTransferPrice,
              value: ListingFormat.price(listing.transferPrice!, currency: cur),
            ),
          if (listing.rentPrice != null)
            _PriceLine(
              label: AppStrings.marketAttrRentPrice,
              value:
                  '${ListingFormat.price(listing.rentPrice!, currency: cur)}/ay',
            ),
        ],
      );
    }
    if (listing.price == null) {
      return Text(AppStrings.listingsPriceAsk, style: _askStyle);
    }
    final unit = (listing.unit ?? '').isEmpty ? '' : ' / ${listing.unit}';
    return Text(
      '${ListingFormat.price(listing.price!, currency: cur)}$unit',
      style: AppTypography.priceLarge,
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
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.infoLabel),
          Text(value, style: AppTypography.priceLarge),
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
        AppSpacing.s,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: AppTypography.sectionTitle),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 0.6,
    indent: AppSpacing.pageH,
    endIndent: AppSpacing.pageH,
    color: AppColors.borderHairline,
  );
}

class _AttributesGrid extends StatelessWidget {
  const _AttributesGrid({required this.listing});
  final MarketListing listing;

  static bool hasEntries(MarketListing l) =>
      _AttributesGrid(listing: l)._entries().isNotEmpty;

  List<MapEntry<String, String>> _entries() {
    // İlanlar tasarım geçişi — eski V1 "Kategori" satırı kaldırıldı: tip
    // rozetiyle çelişebiliyordu ("Fırın devri" + "Kategori: Ekipman").
    final out = <MapEntry<String, String>>[];
    if (listing.isEquipmentSale) {
      if (listing.equipmentCategory != null) {
        out.add(
          MapEntry(
            AppStrings.marketAttrEquipmentCategory,
            MarketplaceTaxonomy.equipmentCategories[listing
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
            MarketplaceTaxonomy.conditions[listing.condition!] ??
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
    // Boş detay bölümü hiç çizilmez (bkz. hasEntries); "—" yok.
    final entries = _entries();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        0,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Column(
        children: entries
            .map((e) => ListingInfoRow(label: e.key, value: e.value))
            .toList(),
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
    final name = (listing.authorName ?? '').trim().isNotEmpty
        ? listing.authorName!.trim()
        : AppStrings.listingsOwnerFallback;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: InkWell(
        key: const ValueKey('market_detail_owner'),
        onTap: () =>
            context.push('${AppRoutes.userPublicProfile}/${listing.ownerId}'),
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          child: Row(
            children: [
              FirinNetAvatar(name: name, size: FirinNetAvatarSize.m),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.listingsDetailOwner,
                      style: AppTypography.infoLabel,
                    ),
                    Text(
                      name,
                      style: AppTypography.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((listing.authorRole ?? '').trim().isNotEmpty)
                      Text(
                        listing.authorRole!.trim(),
                        style: AppTypography.meta.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.place_outlined,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.chipLabel.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Yayın: 12 Eyl 2026 · Bitiş: 12 Eki 2026" (tarih yoksa null).
String? _datesLabel(MarketListing l) {
  final parts = [
    if (l.createdAt != null)
      '${AppStrings.listingsPublishedOn}: ${ListingFormat.date(l.createdAt!)}',
    if (l.expiresAt != null)
      '${AppStrings.listingsExpiresOn}: ${ListingFormat.date(l.expiresAt!)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// İlan durumu (insan dili). Ödeme bekleyen ilan önceliklidir; yayında
/// görünen ama bitiş tarihi geçmiş ilan "Süresi doldu" sayılır.
enum MarketOwnerStatus { active, paused, sold, expired, pendingPayment }

MarketOwnerStatus marketOwnerStatusOf(MarketListing l, {DateTime? now}) {
  if (l.isPendingPayment) return MarketOwnerStatus.pendingPayment;
  switch (l.status) {
    case 'paused':
      return MarketOwnerStatus.paused;
    case 'sold':
      return MarketOwnerStatus.sold;
    case 'expired':
      return MarketOwnerStatus.expired;
  }
  final exp = l.expiresAt;
  if (exp != null && exp.isBefore(now ?? DateTime.now())) {
    return MarketOwnerStatus.expired;
  }
  return MarketOwnerStatus.active;
}

/// Sahibin detayda gördüğü durum şeridi: "Yayında", "Duraklatıldı",
/// "Satıldı", "Süresi doldu", "Ödeme bekliyor" + kısa açıklama.
class MarketOwnerStatusBanner extends StatelessWidget {
  const MarketOwnerStatusBanner({super.key, required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    const neutral = (
      AppColors.surfaceVariant,
      AppColors.borderHairline,
      AppColors.textPrimary,
    );
    final (label, hint, icon, colors) = switch (marketOwnerStatusOf(listing)) {
      MarketOwnerStatus.active => (
        AppStrings.listingsStatusActive,
        AppStrings.listingsStatusActiveHint,
        Icons.check_circle_outline_rounded,
        (
          const Color(0xFFF3FBEF),
          const Color(0xFFCDEBBF),
          const Color(0xFF166534),
        ),
      ),
      MarketOwnerStatus.paused => (
        AppStrings.listingsStatusPaused,
        AppStrings.listingsStatusPausedHint,
        Icons.pause_circle_outline_rounded,
        neutral,
      ),
      MarketOwnerStatus.sold => (
        AppStrings.listingsStatusSold,
        AppStrings.listingsStatusSoldHint,
        Icons.verified_outlined,
        neutral,
      ),
      MarketOwnerStatus.expired => (
        AppStrings.listingsStatusExpired,
        AppStrings.listingsStatusExpiredHint,
        Icons.event_busy_outlined,
        neutral,
      ),
      MarketOwnerStatus.pendingPayment => (
        AppStrings.listingFeePendingBadge,
        AppStrings.listingsPendingPayHint,
        Icons.schedule_rounded,
        (
          const Color(0xFFFFF7E6),
          const Color(0xFFFCD9A0),
          const Color(0xFF92400E),
        ),
      ),
    };
    final (bg, border, fg) = colors;
    return Container(
      key: const ValueKey('market_owner_status_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.chipLabel.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(hint, style: AppTypography.bodySmall.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sahibin alt çubuğu: "Düzenle" (+ duraklatılmışsa "Yeniden yayınla").
class _OwnerActionBar extends StatelessWidget {
  const _OwnerActionBar({
    required this.listing,
    required this.onEdit,
    this.onRepublish,
  });

  final MarketListing listing;
  final VoidCallback onEdit;
  final VoidCallback? onRepublish;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    );
    return ListingStickyBar(
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey('market_owner_edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text(AppStrings.listingsEdit),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(
                    color: AppColors.borderHairline,
                    width: 0.8,
                  ),
                  textStyle: AppTypography.buttonLabel,
                  shape: shape,
                ),
              ),
            ),
          ),
          if (onRepublish != null) ...[
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onRepublish,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    AppStrings.listingsRepublish,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    textStyle: AppTypography.buttonLabel,
                    shape: shape,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
