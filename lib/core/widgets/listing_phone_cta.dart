// FırınNet — Listing Contact Phone Sprint.
//
// Ortak "Ara" CTA widget'ı. Telefon numarası varsa görünür; tıklanınca
// url_launcher ile `tel:<phone>` URI'sini açar. Hata olursa Türkçe
// snackbar gösterir.
//
// Doğrulama yok. Sahibinin rızasıyla ilana eklenmiş public telefon
// numarasıdır. Guest kullanıcı da arayabilir.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../constants/app_strings.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.listingContactCallError)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.listingContactCallError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPhone(phone)) return const SizedBox.shrink();
    return SizedBox(
      height: compact ? 36 : 44,
      child: OutlinedButton.icon(
        onPressed: () => _onTap(context),
        icon: const Icon(Icons.phone_rounded, size: 16),
        label: const Text(
          AppStrings.listingContactCallCta,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.softGold,
          side: BorderSide(
            color: AppColors.softGold.withValues(alpha: 0.55),
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
