// B2B Pazar — ürün kartı.
//
// Genel B2B ürün pazarında bir tedarikçi ürünü. Fiyat tipi "Teklif al".
// isMine → "Benim ürünüm" rozeti + aksiyon gizli (kendine teklif istenmez).
// Aksi halde "Teklif İste" (ve opsiyonel "Fiyat Sor").

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_product.dart';
import 'b2b_media_image.dart';
import 'b2b_meta_pill.dart';

class B2bProductCard extends StatelessWidget {
  const B2bProductCard({
    super.key,
    required this.product,
    this.onRequestQuote,
    this.onAskPrice,
    this.ownerContext = true,
    this.onEdit,
    this.onTogglePublish,
    this.onTap,
  });

  final B2bProduct product;
  final VoidCallback? onRequestQuote;
  final VoidCallback? onAskPrice;

  /// Karta basınca ürün detayına git.
  final VoidCallback? onTap;

  /// Sahiplik yönetim aksiyonları (yalnız kendi ürününde + supplier bağlamı).
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePublish;

  /// Tedarikçi önizlemesinde true → kendi ürününde "Benim ürünüm" rozeti +
  /// aksiyon gizli. Fırıncı (alıcı) görünümünde false → sahiplik yok sayılır
  /// (her ürün normal pazar ürünü gibi davranır).
  final bool ownerContext;

  bool get _isMine => product.isMine && ownerContext;
  bool get _canManage =>
      _isMine && (onEdit != null || onTogglePublish != null);

  bool get _hasImage =>
      product.imageUrl != null && product.imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasImage) ...[
                B2bMediaImage(
                  url: product.imageUrl,
                  height: 48,
                  width: 48,
                  radius: AppRadius.s,
                  placeholderIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: AppSpacing.m),
              ],
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
              ),
              if (!product.published && ownerContext) ...[
                const SizedBox(width: 6),
                const B2bDraftBadge(),
              ],
              if (_isMine) ...[
                const SizedBox(width: AppSpacing.s),
                const B2bOwnerBadge(label: 'Benim ürünüm'),
              ],
              if (_canManage) ...[
                const SizedBox(width: 2),
                B2bManageMenu(
                  published: product.published,
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
                  product.supplierName,
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
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              product.description,
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
              B2bMetaPill(icon: Icons.category_outlined, label: product.category),
              B2bMetaPill(
                icon: Icons.inventory_2_outlined,
                label: 'Min: ${product.minOrder}',
              ),
              B2bMetaPill(
                icon: Icons.local_shipping_outlined,
                label: product.deliveryRegion,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          // Fiyat tipi + (kendi ilanı ise) durum metni tek satır.
          Row(
            children: [
              _PriceTypePill(label: product.priceType),
              const Spacer(),
              if (_isMine)
                const Text(
                  'Senin ilanın',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          // Aksiyonlar kendi satırında, sağa yaslı — dar ekranda taşmaz.
          if (!_isMine) ...[
            const SizedBox(height: AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onAskPrice != null) ...[
                  TextButton(
                    onPressed: onAskPrice,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 38),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('Fiyat Sor'),
                  ),
                  const SizedBox(width: 4),
                ],
                FilledButton(
                  onPressed: onRequestQuote,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Teklif İste'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceTypePill extends StatelessWidget {
  const _PriceTypePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.request_quote_rounded,
            size: 13,
            color: AppColors.brandLemonPressed,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.brandInk,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
