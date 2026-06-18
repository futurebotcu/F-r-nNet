// B2B Pazar — ürün detay ekranı.
//
// Ürün kartından açılır (/pazar/urun/:id). Görsel + bilgiler + "Teklif iste"
// (product mode, kategori sabit) + "Tedarikçi mağazasını gör". Veri yalnız
// repository (FutureProvider) üzerinden.

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

class B2bProductDetailScreen extends ConsumerWidget {
  const B2bProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bProductDetailProvider(productId));
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Ürün detayı')),
      body: SafeArea(
        top: false,
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetryState(
            onRetry: () => ref.invalidate(b2bProductDetailProvider(productId)),
          ),
          data: (p) {
            if (p == null) {
              return const ErrorRetryState(
                title: 'Ürün bulunamadı',
                subtitle: 'Bu ürün artık görüntülenemiyor.',
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
                  url: p.imageUrl,
                  height: 200,
                  placeholderIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  p.name,
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
                  name: p.supplierName,
                  onTap: p.supplierId.isEmpty
                      ? null
                      : () => context.push(
                            AppRoutes.b2bStoreDetail(p.supplierId),
                          ),
                ),
                const SizedBox(height: AppSpacing.l),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (p.category.isNotEmpty)
                      B2bMetaPill(
                        icon: Icons.category_outlined,
                        label: p.category,
                      ),
                    if (p.minOrder.isNotEmpty && p.minOrder != 'Belirtilmedi')
                      B2bMetaPill(
                        icon: Icons.inventory_outlined,
                        label: 'Min: ${p.minOrder}',
                      ),
                    if (p.deliveryRegion.isNotEmpty &&
                        p.deliveryRegion != 'Belirtilmedi')
                      B2bMetaPill(
                        icon: Icons.local_shipping_outlined,
                        label: p.deliveryRegion,
                      ),
                    B2bMetaPill(
                      icon: Icons.sell_outlined,
                      label: p.priceType,
                    ),
                  ],
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  B2bDetailDescription(text: p.description),
                ],
                const SizedBox(height: AppSpacing.xl),
                B2bPrimaryAction(
                  icon: Icons.request_quote_rounded,
                  label: 'Teklif iste',
                  onTap: () => showB2bOfferFlow(
                    context,
                    kind: B2bOfferKind.requestQuote,
                    targetType: 'product',
                    targetId: p.id,
                    presetCategory: p.category,
                    contextLine: '${p.supplierName} · ${p.name}',
                  ),
                ),
                if (p.supplierId.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s),
                  B2bSecondaryAction(
                    icon: Icons.storefront_outlined,
                    label: 'Tedarikçi mağazasını gör',
                    onTap: () =>
                        context.push(AppRoutes.b2bStoreDetail(p.supplierId)),
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
