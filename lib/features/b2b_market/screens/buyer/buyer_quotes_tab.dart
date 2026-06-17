// B2B Pazar — Fırıncı > Tekliflerim.
//
// Kullanıcının açtığı (mock) teklif talepleri ve durumları
// (Bekliyor / Cevap geldi / Kapandı). "Yeni teklif aç" sade bottom sheet
// ile açılır (mock; persist yok). Teklif Ver butonu YOK (bunlar kendi
// taleplerimiz).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_quote_request_card.dart';

class BuyerQuotesTab extends ConsumerWidget {
  const BuyerQuotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(b2bRepositoryProvider).listMyQuoteRequests();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () => showB2bOfferFlow(
                context,
                kind: B2bOfferKind.newRequest,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Yeni teklif aç'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandLemon,
                foregroundColor: AppColors.brandInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: requests.isEmpty
              ? const EmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'Henüz teklif talebin yok',
                  subtitle:
                      '"Yeni teklif aç" ile tedarikçilerden fiyat iste.',
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
                  itemCount: requests.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.m),
                  itemBuilder: (_, i) =>
                      B2bQuoteRequestCard(request: requests[i]),
                ),
        ),
      ],
    );
  }
}
