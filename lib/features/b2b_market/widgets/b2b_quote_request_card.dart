// B2B Pazar — teklif talebi kartı.
//
// ANONİMLİK SÖZLEŞMESİ: Bu kart işletme adı, telefon, açık adres veya kişi
// adı GÖSTERMEZ. Yalnız ürün/kategori, miktar, il/ilçe, alıcı tipi, teslimat
// zamanı, kısa not ve durum görünür. (B2bQuoteRequest modelinde bu alanlar
// zaten yoktur — kart da hiçbir kimlik alanı render etmez.)
//
// İki kullanım:
//  * Teklif Ağı (tedarikçi): [onReply] dolu → "Teklif Ver" butonu.
//  * Tekliflerim (alıcı): [onReply] null → durum + cevap sayısı vurgusu.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_quote_request.dart';
import 'b2b_meta_pill.dart';

class B2bQuoteRequestCard extends StatelessWidget {
  const B2bQuoteRequestCard({
    super.key,
    required this.request,
    this.onReply,
  });

  final B2bQuoteRequest request;

  /// Dolu ise "Teklif Ver" gösterilir (tedarikçi / Teklif Ağı).
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.productOrCategory,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              B2bStatusPill(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              B2bMetaPill(
                icon: Icons.scale_outlined,
                label: request.quantity,
              ),
              B2bMetaPill(
                icon: Icons.place_outlined,
                label: '${request.city} / ${request.district}',
              ),
              B2bMetaPill(
                icon: Icons.badge_outlined,
                label: request.buyerType,
              ),
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              if (request.replyCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${request.replyCount} teklif',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              if (onReply != null)
                FilledButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.local_offer_rounded, size: 16),
                  label: const Text('Teklif Ver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
