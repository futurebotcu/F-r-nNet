// FırınNet Market V1 M2 — Contact panel.
//
// Donor pattern: Bagisto `product_action_bar.dart` (sticky bottom CTA).
// FırınNet'te cart yok; classified marketplace için iletişim aksiyonları:
//   * In-app mesaj (auth gerekli) — V2.x: job_conversations benzeri
//   * Telefon (tel:)
//   * WhatsApp (https://wa.me/)
//   * Paylaş (share_plus native sheet)
//
// Auth guard: in-app mesaj + ilan kaydet auth ister; telefon/whatsapp/share
// guest için açık.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/market_listing.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Kopyalandı: $value')));
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = (listing.contactPhone ?? '').isNotEmpty;
    final hasWhatsapp = (listing.contactWhatsapp ?? '').isNotEmpty;
    final wantsInApp = listing.contactPreference == 'in_app';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.m,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Save / Share satırı
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleSave,
                  icon: Icon(
                    listing.isSavedByMe
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: listing.isSavedByMe
                        ? AppColors.softGold
                        : AppColors.textPrimary,
                  ),
                  label: Text(
                    listing.isSavedByMe
                        ? AppStrings.marketContactSavedCta
                        : AppStrings.marketContactSaveCta,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text(
                    AppStrings.marketContactShareCta,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          // Birincil CTA: contact_preference'a göre
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _primaryCta(context, wantsInApp, hasPhone, hasWhatsapp),
          ),
          // İkincil CTA (varsa)
          if (_hasSecondaryCta(wantsInApp, hasPhone, hasWhatsapp)) ...[
            const SizedBox(height: AppSpacing.s),
            Row(
              children: _secondaryCtas(
                context,
                wantsInApp,
                hasPhone,
                hasWhatsapp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryCta(
    BuildContext context,
    bool wantsInApp,
    bool hasPhone,
    bool hasWhatsapp,
  ) {
    if (wantsInApp) {
      return FilledButton.icon(
        onPressed: onInAppMessage,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text(
          AppStrings.marketContactInApp,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: AppColors.brandInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
    }
    if (hasWhatsapp) {
      return FilledButton.icon(
        onPressed: () => _launchWhatsapp(context),
        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
        label: const Text(
          AppStrings.marketContactWhatsapp,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: AppColors.brandInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
    }
    if (hasPhone) {
      return FilledButton.icon(
        onPressed: () => _launchPhone(context),
        icon: const Icon(Icons.phone_rounded, size: 18),
        label: const Text(
          AppStrings.marketContactPhone,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: AppColors.brandInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onInAppMessage,
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: const Text(
        AppStrings.marketContactInApp,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.copper,
        foregroundColor: AppColors.brandInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  bool _hasSecondaryCta(bool wantsInApp, bool hasPhone, bool hasWhatsapp) {
    if (wantsInApp) {
      return hasPhone || hasWhatsapp;
    }
    // Birincil zaten phone/whatsapp ise, ikincisi diğeri olabilir.
    return (hasPhone && hasWhatsapp);
  }

  List<Widget> _secondaryCtas(
    BuildContext context,
    bool wantsInApp,
    bool hasPhone,
    bool hasWhatsapp,
  ) {
    final children = <Widget>[];
    if (wantsInApp && hasWhatsapp) {
      children.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launchWhatsapp(context),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
            label: const Text(AppStrings.marketContactWhatsapp),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(
                color: AppColors.borderHairline,
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      );
    }
    if ((wantsInApp || hasWhatsapp) && hasPhone) {
      if (children.isNotEmpty)
        children.add(const SizedBox(width: AppSpacing.s));
      children.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launchPhone(context),
            icon: const Icon(Icons.phone_rounded, size: 16),
            label: const Text(AppStrings.marketContactPhone),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(
                color: AppColors.borderHairline,
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      );
    }
    return children;
  }

  /// Helper: share text üretici.
  static String buildShareText(MarketListing listing) {
    final buf = StringBuffer()
      ..writeln('FırınNet Market — ${listing.title}')
      ..writeln();
    final type = AppStrings.marketListingTypeLabels[listing.listingType] ?? '';
    if (type.isNotEmpty) buf.writeln(type);
    if (listing.price != null) {
      buf.writeln('₺ ${listing.price!.toStringAsFixed(0)}');
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

/// Static share helper (panel dışından erişim için).
Future<void> shareListing(MarketListing listing) {
  return Share.share(
    MarketplaceContactPanel.buildShareText(listing),
    subject: 'FırınNet Market — ${listing.title}',
  );
}
