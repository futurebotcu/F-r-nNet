// B2B Pazar — Fırıncı > Ürünler.
//
// Genel B2B ürün pazarı (tedarikçi görünümüyle aynı pazar). Ürün ekleme/
// düzenleme YOK. Alıcı hiçbir ürünün sahibi değil → "Teklif İste" + "Fiyat
// Sor". (ownerContext: false → "Benim ürünüm" rozeti gösterilmez.)
// Veri repository'den FutureProvider ile gelir (loading/error/empty/data).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../models/b2b_product.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_async_list.dart';
import '../../widgets/b2b_category_chip_row.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_product_card.dart';
import '../../widgets/b2b_search_field.dart';

class BuyerProductsTab extends ConsumerStatefulWidget {
  const BuyerProductsTab({super.key});

  @override
  ConsumerState<BuyerProductsTab> createState() => _BuyerProductsTabState();
}

class _BuyerProductsTabState extends ConsumerState<BuyerProductsTab> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(b2bRepositoryProvider).productCategories();
    final q = (category: _category, query: _query);
    final async = ref.watch(b2bProductsProvider(q));

    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        B2bSearchField(
          hint: 'Ürün veya tedarikçi ara',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.s),
        B2bCategoryChipRow(
          categories: categories,
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
        Expanded(
          child: B2bAsyncList<B2bProduct>(
            async: async,
            onRetry: () => ref.invalidate(b2bProductsProvider(q)),
            empty: const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Ürün bulunamadı',
              subtitle: 'Farklı bir kategori veya arama deneyin.',
              compact: true,
            ),
            itemBuilder: (context, p) => B2bProductCard(
              product: p,
              ownerContext: false,
              onTap: () => context.push(AppRoutes.b2bProductDetail(p.id)),
              onRequestQuote: () => showB2bOfferFlow(
                context,
                kind: B2bOfferKind.requestQuote,
                contextLine: '${p.supplierName} · ${p.name}',
                targetType: 'product',
                targetId: p.id,
                presetCategory: p.category,
              ),
              onAskPrice: () => showB2bOfferFlow(
                context,
                kind: B2bOfferKind.askPrice,
                contextLine: '${p.supplierName} · ${p.name}',
                targetType: 'product',
                targetId: p.id,
                presetCategory: p.category,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
