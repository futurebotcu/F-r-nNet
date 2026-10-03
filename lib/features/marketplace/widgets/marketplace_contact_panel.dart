// FırınNet Market V1 M2 — Contact panel.
//
// Donor pattern: Bagisto `product_action_bar.dart` (sticky bottom CTA).
// FırınNet'te cart yok; classified marketplace için iletişim aksiyonları:
//   * In-app mesaj (auth gerekli) — V2.x: job_conversations benzeri
//   * Telefon (tel:)
//   * WhatsApp (https://wa.me/)
//   * Paylaş (share_plus native sheet) — detay AppBar'ında (shareListing).
//
// Auth guard: in-app mesaj + ilan kaydet auth ister; telefon/whatsapp/share
// guest için açık.
//
// Polish 2 — tek birincil CTA: kartta ve detayda aynı "Mesaj gönder"
// (marketContactInApp). "Ara" ve "WhatsApp" her zaman ikincil (outlined).
// Kaydet 48px ikon düğmesi (tooltip: marketContactSaveCta /
// marketContactSavedCta). Panel en fazla iki satır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_listing.dart';
import 'marketplace_listing_card.dart';

/// Market ilanının tek birincil eylemi (kart ve detayda aynı etiket).
const String marketPrimaryCtaLabel = AppStrings.marketContactInApp;

class MarketplaceContactPanel extends StatelessWidget {
  const MarketplaceContactPanel({
    super.key,
    required this.listing,
    required this.onInAppMessage,
    required this.onShare,
    required this.onToggleSave,
  });

  final MarketListing listing;
  final VoidCallback onInAppMessage;

  /// Paylaş artık detay AppBar'ında; geriye dönük imza için tutulur.
  final VoidCallback onShare;
  final VoidCallback onToggleSave;

  Future<void> _launchPhone(BuildContext context) async {
    final phone = listing.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      _copyAndToast(context, phone);
    }
  }

  Future<void> _launchWhatsapp(BuildContext context) async {
    final wa = listing.contactWhatsapp;
    if (wa == null || wa.isEmpty) return;
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      _copyAndToast(context, wa);
    }
  }

  void _copyAndToast(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppFeedback.info(context, AppStrings.listingsCopiedToast);
  }

  static ButtonStyle _outlined() => OutlinedButton.styleFrom(
    foregroundColor: AppColors.brandInk,
    side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: AppTypography.buttonLabel,
  );

  @override
  Widget build(BuildContext context) {
    final hasPhone = (listing.contactPhone ?? '').isNotEmpty;
    final hasWhatsapp = (listing.contactWhatsapp ?? '').isNotEmpty;
    final saved = listing.isSavedByMe;
    final saveLabel = saved
        ? AppStrings.marketContactSavedCta
        : AppStrings.marketContactSaveCta;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderHairline, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Kaydet — ikincil, ikon düğmesi (48px).
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: saveLabel,
                      child: OutlinedButton(
                        key: const ValueKey('market_detail_save'),
                        onPressed: onToggleSave,
                        style: _outlined().copyWith(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.zero,
                          ),
                        ),
                        child: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: AppColors.brandInk,
                          semanticLabel: saveLabel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  // Tek birincil CTA.
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('market_detail_primary'),
                        onPressed: onInAppMessage,
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          marketPrimaryCtaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  ),
                ],
              ),
              if (hasPhone || hasWhatsapp) ...[
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    if (hasPhone)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            key: const ValueKey('market_detail_call'),
                            onPressed: () => _launchPhone(context),
                            icon: const Icon(Icons.call_outlined, size: 16),
                            label: const Text(
                              AppStrings.marketContactPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: _outlined(),
                          ),
                        ),
                      ),
                    if (hasPhone && hasWhatsapp)
                      const SizedBox(width: AppSpacing.s),
                    if (hasWhatsapp)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _launchWhatsapp(context),
                            icon: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              AppStrings.marketContactWhatsapp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: _outlined(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Helper: share text üretici.
  static String buildShareText(MarketListing listing) {
    final buf = StringBuffer()
      ..writeln('FırınNet Market — ${listing.title}')
      ..writeln();
    final type = MarketplaceTaxonomy.listingTypeLabel(listing.listingType);
    if (type.isNotEmpty) buf.writeln(type);
    if (MarketplaceListingCard.hasPrice(listing)) {
      buf.writeln(MarketplaceListingCard.priceLabel(listing));
    }
    if (listing.city != null) buf.writeln('Konum: ${listing.city}');
    if (listing.description != null) {
      buf
        ..writeln()
        ..writeln(listing.description);
    }
    return buf.toString();
  }
}

/// Static share helper (panel dışından erişim için). Etiket:
/// [AppStrings.marketContactShareCta].
Future<void> shareListing(MarketListing listing) {
  return Share.share(
    MarketplaceContactPanel.buildShareText(listing),
    subject: 'FırınNet Market — ${listing.title}',
  );
}
