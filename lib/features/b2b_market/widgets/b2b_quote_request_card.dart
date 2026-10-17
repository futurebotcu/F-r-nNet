// B2B Pazar — teklif talebi kartı.
//
// ANONİMLİK SÖZLEŞMESİ: Bu kart işletme adı, telefon, açık adres veya kişi
// adı GÖSTERMEZ. Yalnız ürün/kategori, miktar, il/ilçe, alıcı tipi, teslimat
// zamanı, kısa not ve durum görünür. (B2bQuoteRequest modelinde bu alanlar
// zaten yoktur — kart da hiçbir kimlik alanı render etmez.)
//
// İki kullanım:
//  * Talepler (tedarikçi): [onReply] dolu → "Teklif Ver" butonu; [contextChip]
//    ile "Ürünün: X / Mağazana yönelik" bağlamı; [dateLabel] talep zamanı.
//  * Tekliflerim (alıcı): [onReply] null → durum + cevap sayısı vurgusu.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_quote_request.dart';
import 'b2b_meta_pill.dart';

class B2bQuoteRequestCard extends StatelessWidget {
  const B2bQuoteRequestCard({
    super.key,
    required this.request,
    this.onReply,
    this.onTap,
    this.contextChip,
    this.dateLabel,
  });

  final B2bQuoteRequest request;

  /// Dolu ise "Teklif Ver" gösterilir (tedarikçi / Teklif Ağı).
  final VoidCallback? onReply;

  /// Dolu ise kart tıklanabilir → teklif detayı (alıcı / Tekliflerim).
  final VoidCallback? onTap;

  /// Başlığın altında bağlam çipi (S2: "Ürünün: X", "Mağazana yönelik").
  final Widget? contextChip;

  /// Talep zamanı etiketi (S2: "3 sa önce"). Boş/null → gizli.
  final String? dateLabel;

  /// İl/ilçe etiketi — boş alanları atlar (form talepleri ilçesiz olabilir).
  String get _locationLabel {
    final c = request.city;
    final d = request.district;
    if (c.isNotEmpty && d.isNotEmpty) return '$c / $d';
    return c.isNotEmpty ? c : d;
  }

  @override
  Widget build(BuildContext context) {
    final card = PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.productOrCategory,
                  style: AppTypography.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // Row non-flex çocuğa sınırsız genişlik verir; büyük yazıda
              // durum pili taşmasın diye Flexible (pil metni ellipsis'li).
              Flexible(child: B2bStatusPill(status: request.status)),
            ],
          ),
          if (contextChip != null || (dateLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                if (contextChip != null) Flexible(child: contextChip!),
                if (contextChip != null && (dateLabel ?? '').isNotEmpty)
                  const SizedBox(width: AppSpacing.s),
                if ((dateLabel ?? '').isNotEmpty)
                  Text(
                    dateLabel!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (request.quantity.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.scale_outlined,
                  label: request.quantity,
                ),
              if (_locationLabel.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.location_on_outlined,
                  label: _locationLabel,
                ),
              if (request.buyerType.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.badge_outlined,
                  label: request.buyerType,
                ),
              if (request.deliveryTime.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.schedule_rounded,
                  label: request.deliveryTime,
                ),
            ],
          ),
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              request.note,
              style: AppTypography.body.copyWith(fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          // Alt satır: bilgi (teklif sayısı / seçilen) + aksiyon. Wrap ile dar
          // ekranda / büyük yazıda buton alt satıra iner; taşma yok.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              if (request.replyCount > 0 || request.hasAcceptedReply)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (request.replyCount > 0) ...[
                      const Icon(
                        Icons.forum_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${request.replyCount} teklif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                    if (request.replyCount > 0 && request.hasAcceptedReply)
                      const SizedBox(width: 8),
                    if (request.hasAcceptedReply) ...[
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.successInk,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Seçilen teklif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.successInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (onReply != null)
                FilledButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.local_offer_rounded, size: 16),
                  label: const Text('Teklif Ver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    // Erişilebilir dokunma alanı (S2): 38 → 44.
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
                  ),
                )
              else if (onTap != null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detayı gör',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.brandInk,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}
