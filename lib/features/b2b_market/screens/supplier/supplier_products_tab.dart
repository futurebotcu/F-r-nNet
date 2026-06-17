// B2B Pazar — Tedarikçi > Ürünler.
//
// Sadece kendi ürünleri DEĞİL — tüm tedarikçilerin ürünlerinin olduğu genel
// B2B ürün pazarı. Kategori + arama filtresi. Kendi ürününde "Benim ürünüm"
// rozeti (aksiyon gizli); diğerlerinde "Teklif İste".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_category_chip_row.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_product_card.dart';
import '../../widgets/b2b_search_field.dart';

class SupplierProductsTab extends ConsumerStatefulWidget {
  const SupplierProductsTab({super.key});

  @override
  ConsumerState<SupplierProductsTab> createState() =>
      _SupplierProductsTabState();
}

class _SupplierProductsTabState extends ConsumerState<SupplierProductsTab> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
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
                      onRequestQuote: () => showB2bOfferFlow(
                        context,
                        kind: B2bOfferKind.requestQuote,
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
