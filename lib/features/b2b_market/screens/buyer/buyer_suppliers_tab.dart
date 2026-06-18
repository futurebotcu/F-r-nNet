// B2B Pazar — Fırıncı > Tedarikçiler.
//
// B2B mağaza profillerinin listesi: firma adı, kategori, hizmet bölgesi,
// ürün/kampanya sayısı. "Profili gör" (detay yakında) / "Teklif iste".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/premium/premium_top_banner.dart';
import '../../models/b2b_store.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_store_card.dart';

class BuyerSuppliersTab extends ConsumerWidget {
  const BuyerSuppliersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(b2bMarketControllerProvider); // mağaza güncellenince yenilen
    final stores = ref.watch(b2bRepositoryProvider).listStores();

    if (stores.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Tedarikçi bulunamadı',
        subtitle: 'Mağaza vitrinleri burada listelenir.',
        compact: true,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      itemCount: stores.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (_, i) {
        final s = stores[i];
        return B2bStoreCard(
          store: s,
          onViewProfile: () => _openStoreProfile(context, s),
          onRequestQuote: () => showB2bOfferFlow(
            context,
            kind: B2bOfferKind.requestQuote,
            contextLine: s.name,
          ),
        );
      },
    );
  }

  void _openStoreProfile(BuildContext context, B2bStore store) {
    PremiumTopBannerController.show(
      context,
      message: '${store.name}: Mağaza detay sayfası yakında.',
      tone: PremiumTopBannerTone.info,
      duration: const Duration(seconds: 2),
    );
  }
}
