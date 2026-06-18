// B2B Pazar — Fırıncı > Tekliflerim.
//
// Kullanıcının açtığı teklif talepleri ve durumları (Bekliyor / Cevap geldi /
// Kapandı). "Yeni teklif aç" bottom sheet ile açılır. Teklif Ver butonu YOK.
// Veri repository'den FutureProvider ile gelir (loading/error/empty/data).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../models/b2b_quote_request.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_async_list.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_quote_request_card.dart';

class BuyerQuotesTab extends ConsumerWidget {
  const BuyerQuotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bMyQuoteRequestsProvider);

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
          child: B2bAsyncList<B2bQuoteRequest>(
            async: async,
            onRetry: () => ref.invalidate(b2bMyQuoteRequestsProvider),
            empty: const EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'Henüz teklif talebin yok',
              subtitle: '"Yeni teklif aç" ile tedarikçilerden fiyat iste.',
              compact: true,
            ),
            itemBuilder: (context, r) => B2bQuoteRequestCard(
              request: r,
              onTap: () => context.push(AppRoutes.b2bQuoteDetail(r.id)),
            ),
          ),
        ),
      ],
    );
  }
}
