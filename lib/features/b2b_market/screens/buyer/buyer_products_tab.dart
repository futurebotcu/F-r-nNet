// B2B Pazar — Fırıncı > Ürünler.
//
// Genel B2B ürün pazarı (tedarikçi görünümüyle aynı pazar). Ürün ekleme/
// düzenleme YOK. Alıcı hiçbir ürünün sahibi değil → "Teklif İste" + "Fiyat
// Sor". (ownerContext: false → "Benim ürünüm" rozeti gösterilmez.)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/b2b_providers.dart';
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
    ref.watch(b2bMarketControllerProvider); // tedarikçi yeni ürün ekleyince yenilen
    final repo = ref.watch(b2bRepositoryProvider);
    final categories = repo.productCategories();
    final products = repo.listProducts(category: _category, query: _query);

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
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Ürün bulunamadı',
                  subtitle: 'Farklı bir kategori veya arama deneyin.',
                  compact: true,
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.xxl,
                  ),
                  itemCount: products.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.m),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return B2bProductCard(
                      product: p,
                      ownerContext: false,
                      onRequestQuote: () => showB2bOfferFlow(
                        context,
                        kind: B2bOfferKind.requestQuote,
                        contextLine: '${p.supplierName} · ${p.name}',
                      ),
                      onAskPrice: () => showB2bOfferFlow(
                        context,
                        kind: B2bOfferKind.askPrice,
                        contextLine: '${p.supplierName} · ${p.name}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
