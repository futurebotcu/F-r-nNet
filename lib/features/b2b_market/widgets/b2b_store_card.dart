// B2B Pazar — tedarikçi mağaza kartı.
//
// Bireysel/Fırıncı görünümünde "Tedarikçiler" listesinde kullanılır:
// monogram + firma adı, kategori chip'leri, hizmet bölgesi, ürün/kampanya
// sayısı, "Profili gör" / "Teklif iste" aksiyonları.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../models/b2b_store.dart';
import 'b2b_meta_pill.dart';
import '../../../core/widgets/firinnet_avatar.dart';

class B2bStoreCard extends StatelessWidget {
  const B2bStoreCard({
    super.key,
    required this.store,
    this.onViewProfile,
    this.onRequestQuote,
  });

  final B2bStore store;
  final VoidCallback? onViewProfile;
  final VoidCallback? onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onViewProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FirinNetAvatar(
                name: store.name,
                imageUrl: store.logoUrl,
                size: 48,
                kind: FirinNetAvatarKind.business,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: AppTypography.cardTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      store.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in store.categories)
                B2bMetaPill(icon: Icons.category_outlined, label: c),
              B2bMetaPill(
                icon: Icons.location_on_outlined,
                label: store.serviceRegions.join(', '),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              _CountChip(
                icon: Icons.inventory_2_outlined,
                label: '${store.productCount} ürün',
              ),
              const SizedBox(width: AppSpacing.s),
              _CountChip(
                icon: Icons.campaign_outlined,
                label: '${store.campaignCount} kampanya',
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 0.8,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
                  ),
                  child: const Text('Profili gör'),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton(
                  onPressed: onRequestQuote,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: AppTypography.buttonLabel.copyWith(fontSize: 13),
                  ),
                  child: const Text('Teklif iste'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.brandLemonPressed),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
