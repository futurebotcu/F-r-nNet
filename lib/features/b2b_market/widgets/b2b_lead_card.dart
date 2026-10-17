// B2B Pazar — tedarikçi lead kartı ("İlgilenenler").
//
// Alıcı, tedarikçinin cevabına "İlgileniyorum" dedi → lead. Telefon YALNIZ
// alıcı açık onay verdiyse görünür. Kimlik (ad/adres) yine paylaşılmaz.
// S2: supplier_offer_network_tab içinden ayrı dosyaya taşındı; renkler
// AppColors token'larına bağlandı; CTA 44px.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_quote_lead.dart';
import 'b2b_lead_message_sheet.dart';
import 'b2b_meta_pill.dart';

class B2bLeadCard extends StatelessWidget {
  const B2bLeadCard({super.key, required this.lead});
  final B2bQuoteLead lead;

  @override
  Widget build(BuildContext context) {
    final loc = lead.requestCity;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 16,
                color: AppColors.successInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.supReqInterestedLine,
                  style: AppTypography.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              if (lead.createdAtLabel.isNotEmpty)
                Text(
                  lead.createdAtLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (lead.requestCategory.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.category_outlined,
                  label: lead.requestCategory,
                ),
              if (lead.requestQuantity.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.scale_outlined,
                  label: lead.requestQuantity,
                ),
              if (loc.isNotEmpty)
                B2bMetaPill(icon: Icons.location_on_outlined, label: loc),
            ],
          ),
          if ((lead.buyerMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              lead.buyerMessage!,
              style: AppTypography.body.copyWith(fontSize: 13.5, height: 1.4),
            ),
          ],
          if (lead.replyAccepted) ...[
            const SizedBox(height: AppSpacing.m),
            const B2bOutcomeChip(
              icon: Icons.verified_rounded,
              label: AppStrings.supReqWon,
              tone: B2bOutcomeTone.success,
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          _PhoneRow(lead: lead),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => showB2bLeadMessageSheet(
                context,
                leadId: lead.id,
                title: 'Alıcı',
                viewerIsBuyer: false,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text(AppStrings.supReqInterestedCta),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderHairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.lead});
  final B2bQuoteLead lead;

  @override
  Widget build(BuildContext context) {
    final shared = lead.phoneShared && (lead.sharedPhone ?? '').isNotEmpty;
    final fg = shared ? AppColors.successInk : AppColors.textSecondary;
    final bg = shared
        ? AppColors.success.withValues(alpha: 0.08)
        : AppColors.surfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(
            shared ? Icons.phone_in_talk_rounded : Icons.phone_disabled_rounded,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shared
                  ? '${AppStrings.supReqPhoneShared}: ${lead.sharedPhone}'
                  : AppStrings.supReqPhoneNotShared,
              style: AppTypography.infoLabel.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum B2bOutcomeTone { success, warning, muted }

/// Sonuç çipi: "Teklifin seçildi" / "Alıcı kararı bekleniyor" / "Başka teklif
/// seçildi". Semantik renkler token'dan.
class B2bOutcomeChip extends StatelessWidget {
  const B2bOutcomeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final B2bOutcomeTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      B2bOutcomeTone.success => (
        AppColors.success.withValues(alpha: 0.08),
        AppColors.successInk,
      ),
      B2bOutcomeTone.warning => (
        AppColors.warning.withValues(alpha: 0.10),
        AppColors.warningInk,
      ),
      B2bOutcomeTone.muted => (AppColors.surfaceVariant, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
