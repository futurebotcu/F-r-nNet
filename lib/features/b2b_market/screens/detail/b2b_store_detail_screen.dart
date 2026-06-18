// B2B Pazar — tedarikçi mağaza detay ekranı.
//
// Tedarikçiler kartından (veya ürün/kampanya/teklif cevabından) açılır
// (/pazar/tedarikciler/:id). Kapak + logo + bilgiler + mağazanın ürün/
// kampanyaları + "Teklif iste" (shop mode). Mağaza sahibi girerse yönetim
// aksiyonları (düzenle / ürün ekle / kampanya oluştur). "Yakında" YOK.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/error_retry_state.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../models/b2b_store.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_meta_pill.dart';
import '../../widgets/b2b_media_image.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import 'b2b_detail_widgets.dart';

class B2bStoreDetailScreen extends ConsumerWidget {
  const B2bStoreDetailScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bStoreDetailProvider(storeId));
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Tedarikçi mağazası')),
      body: SafeArea(
        top: false,
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetryState(
            onRetry: () => ref.invalidate(b2bStoreDetailProvider(storeId)),
          ),
          data: (store) {
            if (store == null) {
              return const ErrorRetryState(
                title: 'Mağaza bulunamadı',
                subtitle: 'Bu tedarikçi mağazası görüntülenemiyor.',
              );
            }
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
                _Header(store: store),
                const SizedBox(height: AppSpacing.l),
                if (store.categories.isNotEmpty ||
                    store.serviceRegions.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in store.categories)
                        B2bMetaPill(icon: Icons.category_outlined, label: c),
                      for (final r in store.serviceRegions)
                        B2bMetaPill(icon: Icons.place_outlined, label: r),
                    ],
                  ),
                if (store.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  B2bDetailDescription(text: store.description),
                ],
                const SizedBox(height: AppSpacing.xl),
                _Actions(store: store),
                const SizedBox(height: AppSpacing.xl),
                _StoreProducts(storeId: storeId),
                const SizedBox(height: AppSpacing.xl),
                _StoreCampaigns(storeId: storeId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store});
  final B2bStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        B2bMediaImage(
          url: store.coverUrl,
          height: 150,
          placeholderIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            B2bMediaImage(
              url: store.logoUrl,
              height: 56,
              width: 56,
              radius: AppRadius.m,
              placeholderIcon: Icons.storefront_rounded,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                store.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.store});
  final B2bStore store;

  @override
  Widget build(BuildContext context) {
    if (store.isMine) {
      return Column(
        children: [
          B2bPrimaryAction(
            icon: Icons.edit_outlined,
            label: 'Mağazayı düzenle',
            onTap: () => context.push(AppRoutes.b2bStoreEdit),
          ),
          const SizedBox(height: AppSpacing.s),
          B2bSecondaryAction(
            icon: Icons.add_box_outlined,
            label: 'Ürün ekle',
            onTap: () => context.push(AppRoutes.b2bProductNew),
          ),
          const SizedBox(height: AppSpacing.s),
          B2bSecondaryAction(
            icon: Icons.campaign_outlined,
            label: 'Kampanya oluştur',
            onTap: () => context.push(AppRoutes.b2bCampaignNew),
          ),
        ],
      );
    }
    return B2bPrimaryAction(
      icon: Icons.request_quote_rounded,
      label: 'Teklif iste',
      onTap: () => showB2bOfferFlow(
        context,
        kind: B2bOfferKind.requestQuote,
        targetType: 'shop',
        targetId: store.id,
        contextLine: store.name,
        presetCategory:
            store.categories.isNotEmpty ? store.categories.first : null,
      ),
    );
  }
}

class _StoreProducts extends ConsumerWidget {
  const _StoreProducts({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bStoreProductsProvider(storeId));
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            B2bDetailSectionHeader(title: 'Mağazanın ürünleri', count: list.length),
            const SizedBox(height: AppSpacing.s),
            for (final p in list) ...[
              _MiniTile(
                imageUrl: p.imageUrl,
                title: p.name,
                subtitle: p.category,
                icon: Icons.inventory_2_outlined,
                onTap: () => context.push(AppRoutes.b2bProductDetail(p.id)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _StoreCampaigns extends ConsumerWidget {
  const _StoreCampaigns({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bStoreCampaignsProvider(storeId));
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            B2bDetailSectionHeader(
              title: 'Mağazanın kampanyaları',
              count: list.length,
            ),
            const SizedBox(height: AppSpacing.s),
            for (final c in list) ...[
              _MiniTile(
                imageUrl: c.imageUrl,
                title: c.title,
                subtitle: c.category,
                icon: Icons.campaign_outlined,
                onTap: () => context.push(AppRoutes.b2bCampaignDetail(c.id)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String? imageUrl;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Row(
        children: [
          B2bMediaImage(
            url: imageUrl,
            height: 48,
            width: 48,
            radius: AppRadius.s,
            placeholderIcon: icon,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

