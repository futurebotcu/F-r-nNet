// B2B Pazar — Tedarikçi > Kampanyalar.
//
// Tüm tedarikçilerin kampanyaları (ticari fırsat kartları). Kategori
// filtresi. Kendi kampanyasında "Benim kampanyam" rozeti + yönetim menüsü;
// diğerlerinde "Teklif İste".
// Veri repository'den FutureProvider ile gelir (loading/error/empty/data).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../models/b2b_campaign.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_async_list.dart';
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
    final categories = ref.watch(b2bRepositoryProvider).productCategories();
    final async = ref.watch(b2bCampaignsProvider(_category));

    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        B2bCategoryChipRow(
          categories: categories,
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
        Expanded(
          child: B2bAsyncList<B2bCampaign>(
            async: async,
            onRetry: () => ref.invalidate(b2bCampaignsProvider(_category)),
            empty: const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Kampanya bulunamadı',
              subtitle: 'Bu kategoride aktif kampanya yok.',
              compact: true,
            ),
            itemBuilder: (context, c) => B2bCampaignCard(
              campaign: c,
              onTap: () => context.push(AppRoutes.b2bCampaignDetail(c.id)),
              onRequestQuote: () => showB2bOfferFlow(
                context,
                kind: B2bOfferKind.requestQuote,
                contextLine: '${c.supplierName} · ${c.title}',
                targetType: 'campaign',
                targetId: c.id,
                presetCategory: c.category,
              ),
              onEdit: () => context.push(AppRoutes.b2bCampaignEdit(c.id)),
              onTogglePublish: () => ref
                  .read(b2bMarketControllerProvider.notifier)
                  .setCampaignPublished(c.id, !c.published),
            ),
          ),
        ),
      ],
    );
  }
}
