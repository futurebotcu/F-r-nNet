// B2B Pazar — kampanya detay ekranı.
//
// Kampanya kartından açılır (/pazar/kampanya/:id). Görsel + bilgiler +
// "Teklif iste" (campaign mode, kategori sabit) + "Tedarikçi mağazasını gör".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/error_retry_state.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_meta_pill.dart';
import '../../widgets/b2b_media_image.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import 'b2b_detail_widgets.dart';

class B2bCampaignDetailScreen extends ConsumerWidget {
  const B2bCampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bCampaignDetailProvider(campaignId));
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Kampanya detayı')),
      body: SafeArea(
        top: false,
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetryState(
            onRetry: () =>
                ref.invalidate(b2bCampaignDetailProvider(campaignId)),
          ),
          data: (c) {
            if (c == null) {
              return const ErrorRetryState(
                title: 'Kampanya bulunamadı',
                subtitle: 'Bu kampanya artık görüntülenemiyor.',
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
                B2bMediaImage(
                  url: c.imageUrl,
                  height: 200,
                  placeholderIcon: Icons.campaign_outlined,
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  c.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                B2bSupplierLine(
                  name: c.supplierName,
                  onTap: c.supplierId.isEmpty
                      ? null
                      : () => context.push(
                            AppRoutes.b2bStoreDetail(c.supplierId),
                          ),
                ),
                const SizedBox(height: AppSpacing.l),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (c.category.isNotEmpty)
                      B2bMetaPill(
                        icon: Icons.category_outlined,
                        label: c.category,
                      ),
                    if (c.minPurchase.isNotEmpty &&
                        c.minPurchase != 'Belirtilmedi')
                      B2bMetaPill(
                        icon: Icons.inventory_outlined,
                        label: 'Min: ${c.minPurchase}',
                      ),
                    if (c.region.isNotEmpty && c.region != 'Belirtilmedi')
                      B2bMetaPill(
                        icon: Icons.place_outlined,
                        label: c.region,
                      ),
                    B2bMetaPill(
                      icon: Icons.event_outlined,
                      label: 'Geçerlilik: ${c.validUntil}',
                    ),
                  ],
                ),
                if (c.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  B2bDetailDescription(text: c.description),
                ],
                const SizedBox(height: AppSpacing.xl),
                B2bPrimaryAction(
                  icon: Icons.request_quote_rounded,
                  label: 'Teklif iste',
                  onTap: () => showB2bOfferFlow(
                    context,
                    kind: B2bOfferKind.requestQuote,
                    targetType: 'campaign',
                    targetId: c.id,
                    presetCategory: c.category,
                    contextLine: '${c.supplierName} · ${c.title}',
                  ),
                ),
                if (c.supplierId.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s),
                  B2bSecondaryAction(
                    icon: Icons.storefront_outlined,
                    label: 'Tedarikçi mağazasını gör',
                    onTap: () =>
                        context.push(AppRoutes.b2bStoreDetail(c.supplierId)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
