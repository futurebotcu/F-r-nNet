// B2B Pazar — kampanya kartı.
//
// Sosyal post değil, ticari fırsat kartı: sol accent şerit + kampanya
// ikonu, başlık, tedarikçi, kategori/bağlı ürün, bölge, min alım, geçerlilik.
// isMine → "Benim kampanyam" rozeti. Aksi halde "Teklif İste".

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_campaign.dart';
import 'b2b_meta_pill.dart';

class B2bCampaignCard extends StatelessWidget {
  const B2bCampaignCard({
    super.key,
    required this.campaign,
    this.onRequestQuote,
    this.ownerContext = true,
    this.onEdit,
    this.onTogglePublish,
  });

  final B2bCampaign campaign;
  final VoidCallback? onRequestQuote;

  /// Sahiplik yönetim aksiyonları (yalnız kendi kampanyasında + supplier).
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePublish;

  /// Tedarikçi önizlemesinde true → kendi kampanyasında "Benim kampanyam"
  /// rozeti + aksiyon gizli. Fırıncı görünümünde false → sahiplik yok sayılır.
  final bool ownerContext;

  bool get _isMine => campaign.isMine && ownerContext;
  bool get _canManage =>
      _isMine && (onEdit != null || onTogglePublish != null);

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ticari fırsat hissi veren sol accent şerit.
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.brandLemon,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.l),
                  bottomLeft: Radius.circular(AppRadius.l),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.campaign_rounded,
                          size: 18,
                          color: AppColors.brandLemonPressed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            campaign.title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (!campaign.published && ownerContext) ...[
                          const SizedBox(width: 6),
                          const B2bDraftBadge(),
                        ],
                        if (_isMine) ...[
                          const SizedBox(width: AppSpacing.s),
                          const B2bOwnerBadge(label: 'Benim kampanyam'),
                        ],
                        if (_canManage) ...[
                          const SizedBox(width: 2),
                          B2bManageMenu(
                            published: campaign.published,
                            onEdit: onEdit,
                            onTogglePublish: onTogglePublish,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            campaign.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (campaign.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        campaign.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.m),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        B2bMetaPill(
                          icon: Icons.category_outlined,
                          label: campaign.linkedProduct ?? campaign.category,
                        ),
                        B2bMetaPill(
                          icon: Icons.place_outlined,
                          label: campaign.region,
                        ),
                        B2bMetaPill(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Min: ${campaign.minPurchase}',
                        ),
                        B2bMetaPill(
                          icon: Icons.event_available_outlined,
                          label: 'Son: ${campaign.validUntil}',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _isMine
                          ? const Text(
                              'Senin kampanyan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            )
                          : FilledButton(
                              onPressed: onRequestQuote,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandLemon,
                                foregroundColor: AppColors.brandInk,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.l,
                                ),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.m),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              child: const Text('Teklif İste'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
