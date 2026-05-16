import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';

/// V1 Market — backend yok, mock kaldırıldı (P0).
///
/// Önceki versiyon hardcoded ürünler, sahte satıcılar ve sahte fiyatlar
/// gösteriyordu. Mağaza öncesi temizlik gereği bu içerik tamamen kaldırıldı;
/// kullanıcıya dürüst bir "yakında" ekranı sunuluyor. Bottom nav'dan da
/// kaldırıldı (`AppShell._tabs`). `/market` route'u deeplink geri uyumu için
/// korundu ve `MarketplaceScreen` yine yüklenir, ama mock veri göstermez.
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const FirinNetHeader(
              title: AppStrings.marketTitle,
              subtitle: AppStrings.marketSubtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: _ComingSoonCard(theme: theme),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.softGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  AppStrings.marketComingSoonTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.marketComingSoonBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: AppColors.borderHairline,
                width: 0.6,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.softGold,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    AppStrings.marketComingSoonHintCommercial,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
