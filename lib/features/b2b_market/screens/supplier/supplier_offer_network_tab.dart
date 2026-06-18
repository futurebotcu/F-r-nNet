// B2B Pazar — Tedarikçi > Teklif Ağı.
//
// İki segment:
//  * Açık Talepler — alıcıların açtığı ANONİM teklif talepleri (kimlik/iletişim
//    göstermez; RPC bu alanları döndürmez). "Teklif Ver" ile cevap verilir.
//  * İlgilenenler — verdiği tekliflere alıcının "İlgileniyorum" dediği lead'ler.
//    Telefon yalnız alıcı paylaştıysa görünür; aksi halde "Telefon paylaşılmadı".
//    Tedarikçi yalnız KENDİ mağazasına gelen lead'leri görür (RLS).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../models/b2b_quote_lead.dart';
import '../../models/b2b_quote_request.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_async_list.dart';
import '../../widgets/b2b_meta_pill.dart';
import '../../widgets/b2b_offer_bottom_sheet.dart';
import '../../widgets/b2b_quote_request_card.dart';

class SupplierOfferNetworkTab extends ConsumerStatefulWidget {
  const SupplierOfferNetworkTab({super.key});

  @override
  ConsumerState<SupplierOfferNetworkTab> createState() =>
      _SupplierOfferNetworkTabState();
}

class _SupplierOfferNetworkTabState
    extends ConsumerState<SupplierOfferNetworkTab> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.s,
          ),
          child: _Segment(
            value: _seg,
            onChanged: (v) => setState(() => _seg = v),
          ),
        ),
        Expanded(
          child: _seg == 0 ? const _OpenRequests() : const _Leads(),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Row(
        children: [
          _seg(0, 'Açık Talepler'),
          _seg(1, 'İlgilenenler'),
        ],
      ),
    );
  }

  Widget _seg(int i, String label) {
    final selected = i == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLemon : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.brandInk : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenRequests extends ConsumerWidget {
  const _OpenRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bOpenQuoteRequestsProvider);
    return B2bAsyncList<B2bQuoteRequest>(
      async: async,
      onRetry: () => ref.invalidate(b2bOpenQuoteRequestsProvider),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      leading: const _AnonymityNote(),
      empty: const EmptyState(
        icon: Icons.hub_outlined,
        title: 'Açık teklif talebi yok',
        subtitle: 'Yeni talepler burada anonim olarak listelenir.',
        compact: true,
      ),
      itemBuilder: (context, r) => B2bQuoteRequestCard(
        request: r,
        onReply: r.status.isTerminal
            ? null
            : () => showB2bOfferFlow(
                  context,
                  kind: B2bOfferKind.giveOffer,
                  contextLine: '${r.productOrCategory} · ${r.city}',
                  quoteRequestId: r.id,
                ),
      ),
    );
  }
}

class _Leads extends ConsumerWidget {
  const _Leads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(b2bSupplierLeadsProvider);
    return B2bAsyncList<B2bQuoteLead>(
      async: async.whenData(
        (list) => list.where((l) => l.isInterested).toList(growable: false),
      ),
      onRetry: () => ref.invalidate(b2bSupplierLeadsProvider),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      empty: const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Henüz ilgilenen yok',
        subtitle: 'Verdiğin tekliflere gelen ilgiler burada görünür.',
        compact: true,
      ),
      itemBuilder: (context, l) => _LeadCard(lead: l),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});
  final B2bQuoteLead lead;

  @override
  Widget build(BuildContext context) {
    final loc = lead.requestCity;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 16, color: Color(0xFF166534)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Alıcı teklifinle ilgileniyor.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  lead.createdAtLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (lead.requestCategory.isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.category_outlined,
                    label: lead.requestCategory,
                  ),
                if (lead.requestQuantity.isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.scale_outlined,
                    label: lead.requestQuantity,
                  ),
                if (loc.isNotEmpty)
                  B2bMetaPill(icon: Icons.place_outlined, label: loc),
              ],
            ),
            if ((lead.buyerMessage ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                lead.buyerMessage!,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            _PhoneRow(lead: lead),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Bu lead, verdiğin teklif üzerinden oluştu.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.lead});
  final B2bQuoteLead lead;

  @override
  Widget build(BuildContext context) {
    final shared = lead.phoneShared && (lead.sharedPhone ?? '').isNotEmpty;
    final (Color bg, Color fg) = shared
        ? (const Color(0xFFF3FBEF), const Color(0xFF166534))
        : (AppColors.surfaceVariant, AppColors.textMuted);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(
            shared ? Icons.phone_in_talk_rounded : Icons.phone_disabled_rounded,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shared
                  ? 'Alıcı telefonunu paylaştı: ${lead.sharedPhone}'
                  : 'Telefon paylaşılmadı.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: child,
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
