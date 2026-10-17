// S3 — Mağaza iletişim aksiyonları (Ara · WhatsApp · Web) + adres satırı.
//
// Gizlilik: b2b_supplier_shops yalnız oturum açmış kullanıcılara okunur
// (RLS, anon'a grant yok); bu widget zaten yüklenmiş mağaza verisini
// gösterir, ek sorgu yapmaz. Alanlar boşsa hiçbir şey çizilmez.
// Dokunma hedefleri 44px; başarısız launch'ta değer panoya kopyalanır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
import '../models/b2b_store.dart';

class B2bStoreContact extends StatelessWidget {
  const B2bStoreContact({super.key, required this.store});
  final B2bStore store;

  static String digitsOf(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static Uri? websiteUri(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    final withScheme = t.startsWith('http://') || t.startsWith('https://')
        ? t
        : 'https://$t';
    final u = Uri.tryParse(withScheme);
    if (u == null || u.host.isEmpty) return null;
    return u;
  }

  Future<void> _open(BuildContext context, Uri uri, String fallback) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // aşağıda kopyala
    }
    await Clipboard.setData(ClipboardData(text: fallback));
    if (context.mounted) {
      AppFeedback.info(context, AppStrings.listingsCopiedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = (store.phone ?? '').trim();
    final wa = (store.whatsapp ?? '').trim();
    final web = websiteUri(store.website);
    final address = (store.address ?? '').trim();
    if (phone.isEmpty && wa.isEmpty && web == null && address.isEmpty) {
      return const SizedBox.shrink();
    }
    final buttons = <Widget>[
      if (phone.isNotEmpty)
        _ContactButton(
          key: const ValueKey('b2b_store_call'),
          icon: Icons.call_outlined,
          label: AppStrings.b2bContactCall,
          onTap: () => _open(context, Uri(scheme: 'tel', path: phone), phone),
        ),
      if (wa.isNotEmpty)
        _ContactButton(
          key: const ValueKey('b2b_store_whatsapp'),
          icon: Icons.chat_outlined,
          label: AppStrings.b2bContactWhatsapp,
          onTap: () =>
              _open(context, Uri.parse('https://wa.me/${digitsOf(wa)}'), wa),
        ),
      if (web != null)
        _ContactButton(
          key: const ValueKey('b2b_store_website'),
          icon: Icons.language_outlined,
          label: AppStrings.b2bContactWebsite,
          onTap: () => _open(context, web, web.toString()),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buttons.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}
