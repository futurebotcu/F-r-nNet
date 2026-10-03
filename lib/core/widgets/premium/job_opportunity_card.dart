import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/tr_case.dart';

/// İş ilanı türü: işletme personel arıyor (offer) / kişi iş arıyor (seek).
enum JobListingKind { hiring, seeking }

/// İlanlar tasarım geçişi — iş ilanı kartı.
///
/// Hiyerarşi: tür rozeti → güçlü başlık → ana bilgi (ücret) → konum →
/// ilan sahibi · göreli tarih → kısa etiketler → CTA. Türler ayrı ama sakin
/// görünür: "PERSONEL ARANIYOR" (çanta ikonu, limon zemin) / "İŞ ARIYOR"
/// (kişi-arama ikonu, nötr-teal zemin). Tüm metinler ellipsize olur;
/// etiketler Wrap ile akar (320px + 1.3x yazı ölçeğinde taşma yok).
class JobOpportunityCard extends StatelessWidget {
  const JobOpportunityCard({
    super.key,
    required this.kind,
    required this.title,
    required this.keyFact,
    this.location,
    this.owner,
    this.timeLabel,
    this.tags = const <String>[],
    this.statusBadge,
    this.onTap,
    this.onMore,
    this.onApply,
    this.applyLabel,
    this.applyIcon,
    this.applyEnabled = true,
    this.secondaryAction,
    this.footer,
  });

  final JobListingKind kind;
  final String title;

  /// Ana bilgi (ücret / beklenti). Fallback metni çağıran seçer.
  final String keyFact;
  final String? location;
  final String? owner;
  final String? timeLabel;

  /// Yalnız dolu etiketler (tecrübe, vardiya, meslek…). Boşlar atlanır.
  final List<String> tags;

  /// Owner'a özel durum rozeti (örn. "Ödeme bekliyor"). Public kartta null.
  final Widget? statusBadge;

  /// Kart dokunuşu → detay.
  final VoidCallback? onTap;

  /// ⋮ menü (şikayet/engelle). null → ikon gösterilmez.
  final VoidCallback? onMore;

  /// Birincil CTA. `null` ise CTA hiç render edilmez.
  final VoidCallback? onApply;
  final String? applyLabel;
  final IconData? applyIcon;
  final bool applyEnabled;

  /// Kart içi ikincil aksiyon (örn. "Ara").
  final Widget? secondaryAction;

  /// Kart altı ek içerik (örn. owner için ödeme butonu).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final visibleTags = tags.where((t) => t.trim().isNotEmpty).toList();
    final hasLocation = (location ?? '').trim().isNotEmpty;
    final ownerText = (owner ?? '').trim();
    final time = (timeLabel ?? '').trim();
    final hasCta = onApply != null || secondaryAction != null;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: JobKindBadge(kind: kind)),
              if (statusBadge != null) ...[
                const SizedBox(width: 6),
                Flexible(child: statusBadge!),
              ],
              const Spacer(),
              if (onMore == null) const SizedBox(height: 44),
              if (onMore != null)
                // Polish 2 — 44px dokunma alanı (görsel ikon küçük kalır).
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    key: const ValueKey('job_card_more'),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tooltip: AppStrings.listingsMoreActions,
                    onPressed: onMore,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            keyFact,
            style: AppTypography.price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasLocation) ...[
            const SizedBox(height: 6),
            _MetaRow(icon: Icons.place_outlined, text: location!.trim()),
          ],
          if (ownerText.isNotEmpty || time.isNotEmpty) ...[
            const SizedBox(height: 4),
            _MetaRow(
              icon: kind == JobListingKind.hiring
                  ? Icons.storefront_outlined
                  : Icons.person_outline_rounded,
              text: ownerText,
              trailing: time,
            ),
          ],
          if (visibleTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in visibleTags) _Tag(label: t)],
            ),
          ],
          if (hasCta) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                if (onApply != null)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: applyEnabled ? onApply : null,
                        icon: Icon(applyIcon ?? Icons.send_rounded, size: 16),
                        label: Text(
                          applyLabel ?? AppStrings.jobsApply,
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
                if (onApply != null && secondaryAction != null)
                  const SizedBox(width: AppSpacing.s),
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.m),
            footer!,
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.l),
            border: Border.all(
              color: AppColors.borderHairline.withValues(alpha: 0.7),
              width: 0.6,
            ),
            boxShadow: AppShadow.card,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// İş ilanı tür rozeti — kartta ve detay sayfasında ortak.
class JobKindBadge extends StatelessWidget {
  const JobKindBadge({super.key, required this.kind});

  final JobListingKind kind;

  // Tek nötr-teal vurgu: "İş arıyor" türünü limon "Personel aranıyor"dan
  // ayırır; düşük doygunluk, koyu metin (kontrast ≥ 7:1).
  static const Color _seekBg = Color(0xFFEDF5F4);
  static const Color _seekBorder = Color(0xFFCFE3E0);
  static const Color _seekFg = Color(0xFF134E4A);

  @override
  Widget build(BuildContext context) {
    final hiring = kind == JobListingKind.hiring;
    final label =
        (hiring
                ? AppStrings.listingsBadgeHiring
                : AppStrings.listingsBadgeSeeking)
            .trUpper;
    final bg = hiring ? AppColors.brandLemonPale : _seekBg;
    final border = hiring ? AppColors.brandLemonSoft : _seekBorder;
    final fg = hiring ? AppColors.brandInk : _seekFg;
    return Container(
      key: ValueKey(hiring ? 'job_badge_hiring' : 'job_badge_seeking'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hiring ? Icons.work_outline_rounded : Icons.person_search_outlined,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          // Tür etiketi kesilmez ("PERSONEL …" olmaz): dar ekran / büyük
          // yazıda tamamı sığacak şekilde küçülür.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: AppTypography.badge.copyWith(color: fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konum / sahip satırı. Sahip adı okunur (textSecondary) ve gerekirse
/// kısalır; göreli tarih sağda sakin `caption` olarak kalır (baskın değil).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.trailing});
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
        if (text.isNotEmpty) ...[
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
        ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.meta.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
