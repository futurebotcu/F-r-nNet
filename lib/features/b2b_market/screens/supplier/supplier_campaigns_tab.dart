// B2B Pazar — Tedarikçi > Kampanyalar.
//
// Tüm tedarikçilerin kampanyaları (ticari fırsat kartları). Kategori
// filtresi. Kendi kampanyasında "Benim kampanyam" rozeti; diğerlerinde
// "Teklif İste".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_campaign_card.dart';
import '../../widgets/b2b_category_chip_row.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';

class SupplierCampaignsTab extends ConsumerStatefulWidget {
  const SupplierCampaignsTab({super.key});

  @override
  ConsumerState<SupplierCampaignsTab> createState() =>
      _SupplierCampaignsTabState();
}

class _SupplierCampaignsTabState extends ConsumerState<SupplierCampaignsTab> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(b2bRepositoryProvider);
    final categories = repo.productCategories();
    final campaigns = repo.listCampaigns(category: _category);

    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        B2bCategoryChipRow(
          categories: categories,
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
        Expanded(
          child: campaigns.isEmpty
              ? const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Kampanya bulunamadı',
                  subtitle: 'Bu kategoride aktif kampanya yok.',
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
                  itemCount: campaigns.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.m),
                  itemBuilder: (_, i) {
                    final c = campaigns[i];
                    return B2bCampaignCard(
                      campaign: c,
                      onRequestQuote: () => showB2bOfferFlow(
                        context,
                        kind: B2bOfferKind.requestQuote,
                        contextLine: '${c.supplierName} · ${c.title}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
