// B2B Pazar — Tedarikçi > Mağazam.
//
// B2B mağaza vitrini gibi görünür (FırınNet profilinin kopyası DEĞİL):
// monogram + kapak hissi, hizmet bölgeleri, kategoriler, kısa açıklama,
// öne çıkan ürünler, aktif kampanyalar. Dashboard/istatistik ile başlamaz;
// "fırıncılar mağazanı böyle görüyor" bakış açısını verir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../models/b2b_store.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_campaign_card.dart';
import '../../widgets/b2b_product_card.dart';

class SupplierStoreTab extends ConsumerWidget {
  const SupplierStoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(b2bRepositoryProvider);
    final store = repo.myStore();
    final products = repo.listMyProducts();
    final campaigns = repo.listMyCampaigns();

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        const _ViewpointStrip(),
        const SizedBox(height: AppSpacing.m),
        _StoreHero(store: store),
        if (products.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          const _SectionHeader(
            icon: Icons.star_outline_rounded,
            title: 'Öne çıkan ürünler',
          ),
          const SizedBox(height: AppSpacing.s),
          for (final p in products) ...[
            B2bProductCard(product: p),
            const SizedBox(height: AppSpacing.m),
          ],
        ],
        if (campaigns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          const _SectionHeader(
            icon: Icons.campaign_outlined,
            title: 'Aktif kampanyalar',
          ),
          const SizedBox(height: AppSpacing.s),
          for (final c in campaigns) ...[
            B2bCampaignCard(campaign: c),
            const SizedBox(height: AppSpacing.m),
          ],
        ],
      ],
    );
  }
}

class _ViewpointStrip extends StatelessWidget {
  const _ViewpointStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 15,
            color: AppColors.brandLemonPressed,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Fırıncılar mağazanı böyle görüyor.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandInk,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.store});
  final B2bStore store;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      warm: true,
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  store.monogram,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandLemonPressed,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.tagline,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _LabeledChips(
            icon: Icons.place_outlined,
            label: 'Hizmet bölgeleri',
            values: store.serviceRegions,
          ),
          const SizedBox(height: AppSpacing.m),
          _LabeledChips(
            icon: Icons.category_outlined,
            label: 'Kategoriler',
            values: store.categories,
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            store.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledChips extends StatelessWidget {
  const _LabeledChips({
    required this.icon,
    required this.label,
    required this.values,
  });
  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in values)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  v,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandInk,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.brandLemonPressed),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
