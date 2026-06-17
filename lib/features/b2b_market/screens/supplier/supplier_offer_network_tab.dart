// B2B Pazar — Tedarikçi > Teklif Ağı.
//
// Alıcıların açtığı ANONİM teklif talepleri. Kart işletme adı / telefon /
// açık adres / kişi adı GÖSTERMEZ (B2bQuoteRequest'te bu alanlar yoktur).
// Tedarikçi "Teklif Ver" ile cevap verir (mock; persist yok).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../models/b2b_quote_request.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_quote_request_card.dart';

class SupplierOfferNetworkTab extends ConsumerWidget {
  const SupplierOfferNetworkTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(b2bRepositoryProvider).listOpenQuoteRequests();

    if (requests.isEmpty) {
      return const EmptyState(
        icon: Icons.hub_outlined,
        title: 'Açık teklif talebi yok',
        subtitle: 'Yeni talepler burada anonim olarak listelenir.',
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
      itemCount: requests.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
      itemBuilder: (_, i) {
        if (i == 0) return const _AnonymityNote();
        final r = requests[i - 1];
        return B2bQuoteRequestCard(
          request: r,
          onReply: r.status == B2bQuoteStatus.closed
              ? null
              : () => showB2bOfferFlow(
                    context,
                    kind: B2bOfferKind.giveOffer,
                    contextLine: '${r.productOrCategory} · ${r.city}',
                  ),
        );
      },
    );
  }
}

/// Anonimliği açıkça belirten bilgi şeridi.
class _AnonymityNote extends StatelessWidget {
  const _AnonymityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Talepler anonimdir. Alıcı kimliği ve iletişim bilgisi '
              'paylaşılmaz.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
