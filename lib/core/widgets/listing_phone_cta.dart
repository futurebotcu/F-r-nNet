// FırınNet — Listing Contact Phone Sprint.
//
// Ortak "Ara" CTA widget'ı. Telefon numarası varsa görünür; tıklanınca
// url_launcher ile `tel:<phone>` URI'sini açar. Hata olursa Türkçe
// AppFeedback gösterir.
//
// Doğrulama yok. Sahibinin rızasıyla ilana eklenmiş public telefon
// numarasıdır. Guest kullanıcı da arayabilir.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../constants/app_strings.dart';
import 'app_feedback.dart';

class ListingPhoneCta extends StatelessWidget {
  const ListingPhoneCta({super.key, required this.phone, this.compact = false});

  /// Opsiyonel telefon. null/boş ise widget boş `SizedBox.shrink()` döner.
  final String? phone;

  /// `true` → daha küçük yükseklik; list card içinde kullanılır.
  final bool compact;

  static bool hasPhone(String? p) => p != null && p.trim().isNotEmpty;

  static Uri telUri(String phone) => Uri(scheme: 'tel', path: phone.trim());

  Future<void> _onTap(BuildContext context) async {
    final p = phone;
    if (p == null || p.trim().isEmpty) return;
    final uri = telUri(p);
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        AppFeedback.error(context, AppStrings.listingContactCallError);
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(context, AppStrings.listingContactCallError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPhone(phone)) return const SizedBox.shrink();
    // Polish 2 — "Ara" her yerde ikincil (outlined) ve ≥ 44px yükseklik;
    // mürekkep metin (limon asla metin rengi değil).
    return SizedBox(
      height: compact ? 44 : 48,
      child: OutlinedButton.icon(
        key: const ValueKey('listing_phone_cta'),
        onPressed: () => _onTap(context),
        icon: const Icon(Icons.call_outlined, size: 16),
        label: const Text(
          AppStrings.listingContactCallCta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandInk,
          textStyle: AppTypography.buttonLabel,
          side: const BorderSide(color: AppColors.borderHairline, width: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
