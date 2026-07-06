import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/partner_business.dart';

/// Harici bağlantı açma (tel: / map / web) — gömülü SDK YOK, yalnız launch.
/// Başarısızlıkta Türkçe snackbar (kişisel veri basılmaz).
Future<void> launchPartnerLink(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.partnersLinkError)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.partnersLinkError)),
      );
    }
  }
}

/// Liste kartı: ad + kategori etiketi + şehir/ilçe + avantaj özeti +
/// Ara / Haritada aç / Detay aksiyonları.
class PartnerBusinessCard extends StatelessWidget {
  const PartnerBusinessCard({
    super.key,
    required this.partner,
    required this.onDetail,
  });

  final PartnerBusiness partner;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final p = partner;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        key: ValueKey('partner_card_${p.id}'),
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onDetail,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.borderHairline, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandLemonPale,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: AppColors.brandInk,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.city} / ${p.district}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _CategoryChip(label: p.category),
                ],
              ),
              if (p.benefitSummary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 15,
                      color: Color(0xFF166534),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.benefitSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              // Aksiyonlar: dar ekranda Wrap ile alta iner (taşma yok).
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: 4,
                children: [
                  if (p.phone.isNotEmpty)
                    _ActionChip(
                      key: ValueKey('partner_call_${p.id}'),
                      icon: Icons.call_outlined,
                      label: AppStrings.partnersCall,
                      onTap: () => launchPartnerLink(
                        context,
                        Uri(scheme: 'tel', path: p.phone),
                      ),
                    ),
                  if (p.mapUrl.isNotEmpty)
                    _ActionChip(
                      key: ValueKey('partner_map_${p.id}'),
                      icon: Icons.map_outlined,
                      label: AppStrings.partnersOpenMap,
                      onTap: () {
                        final uri = Uri.tryParse(p.mapUrl);
                        if (uri != null) launchPartnerLink(context, uri);
                      },
                    ),
                  _ActionChip(
                    key: ValueKey('partner_detail_${p.id}'),
                    icon: Icons.chevron_right_rounded,
                    label: AppStrings.partnersDetailCta,
                    emphasized: true,
                    onTap: onDetail,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      constraints: const BoxConstraints(maxWidth: 120),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.brandLemonPale : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: emphasized
                    ? AppColors.brandInk
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: emphasized
                      ? AppColors.brandInk
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
