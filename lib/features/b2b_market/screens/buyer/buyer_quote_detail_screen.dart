// B2B Pazar — Alıcı > Teklif detayı.
//
// Tekliflerim'deki bir talebe basınca açılır (/pazar/tekliflerim/:id).
// Talep özeti + gelen teklifler (tedarikçi cevapları). Tedarikçi kimliği
// (cevaplayan mağaza adı) görünür; ALICI kimliği zaten yok. Veri yalnız
// repository (FutureProvider) üzerinden; UI Supabase'i doğrudan görmez.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/error_retry_state.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../models/b2b_quote_reply.dart';
import '../../models/b2b_quote_request.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_meta_pill.dart';

class BuyerQuoteDetailScreen extends ConsumerWidget {
  const BuyerQuoteDetailScreen({super.key, required this.quoteRequestId});

  final String quoteRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(b2bQuoteDetailProvider(quoteRequestId));
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Teklif detayı')),
      body: SafeArea(
        top: false,
        child: detail.when(
          skipLoadingOnReload: true,
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => ErrorRetryState(
            onRetry: () =>
                ref.invalidate(b2bQuoteDetailProvider(quoteRequestId)),
          ),
          data: (req) {
            if (req == null) {
              return const ErrorRetryState(
                title: 'Talep bulunamadı',
                subtitle: 'Bu teklif talebi görüntülenemiyor.',
              );
            }
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                _RequestSummary(req: req),
                const SizedBox(height: AppSpacing.m),
                _QuoteActions(quoteRequestId: quoteRequestId, status: req.status),
                const SizedBox(height: AppSpacing.l),
                _SectionHeader(
                  title: 'Gelen teklifler',
                  count: req.replyCount,
                ),
                const SizedBox(height: AppSpacing.s),
                _Replies(quoteRequestId: quoteRequestId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.req});
  final B2bQuoteRequest req;

  @override
  Widget build(BuildContext context) {
    final loc = [req.city, req.district].where((e) => e.isNotEmpty).join(' / ');
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  req.productOrCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              B2bStatusPill(status: req.status),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (req.quantity.isNotEmpty)
                B2bMetaPill(icon: Icons.scale_outlined, label: req.quantity),
              if (loc.isNotEmpty)
                B2bMetaPill(icon: Icons.place_outlined, label: loc),
              if (req.buyerType.isNotEmpty)
                B2bMetaPill(icon: Icons.badge_outlined, label: req.buyerType),
              if (req.deliveryTime.isNotEmpty)
                B2bMetaPill(
                  icon: Icons.schedule_rounded,
                  label: req.deliveryTime,
                ),
            ],
          ),
          if (req.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              req.note,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteActions extends ConsumerWidget {
  const _QuoteActions({required this.quoteRequestId, required this.status});

  final String quoteRequestId;
  final B2bQuoteStatus status;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String confirmLabel,
    required Future<void> Function() action,
    required String done,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('Bu işlem talebin durumunu değiştirir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarısız. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status.isTerminal) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.borderHairline, width: 0.8),
        ),
        child: Text(
          status == B2bQuoteStatus.closed
              ? 'Bu talep kapatıldı. Yeni teklif kabul edilmiyor.'
              : 'Bu talep iptal edildi.',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final ctrl = ref.read(b2bMarketControllerProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirm(
              context,
              ref,
              title: 'Talebi kapat',
              confirmLabel: 'Kapat',
              action: () => ctrl.closeQuoteRequest(quoteRequestId),
              done: 'Talep kapatıldı.',
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
            label: const Text('Talebi kapat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderHairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirm(
              context,
              ref,
              title: 'Talebi iptal et',
              confirmLabel: 'İptal et',
              action: () => ctrl.cancelQuoteRequest(quoteRequestId),
              done: 'Talep iptal edildi.',
            ),
            icon: const Icon(Icons.cancel_outlined, size: 17),
            label: const Text('İptal et'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0x33991B1B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Replies extends ConsumerWidget {
  const _Replies({required this.quoteRequestId});
  final String quoteRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(b2bRepliesProvider(quoteRequestId));
    return replies.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ErrorRetryState(
        compact: true,
        onRetry: () => ref.invalidate(b2bRepliesProvider(quoteRequestId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.l,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: const Text(
              'Henüz teklif gelmedi. Tedarikçiler talebini Teklif Ağı\'nda '
              'görebilir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final r in list) ...[
              _ReplyCard(reply: r),
              const SizedBox(height: AppSpacing.m),
            ],
          ],
        );
      },
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});
  final B2bQuoteReply reply;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: AppColors.brandLemonPressed,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reply.supplierName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Text(
                reply.createdAtLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (reply.message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              reply.message,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if ((reply.priceHint ?? '').isNotEmpty ||
              (reply.deliveryNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((reply.priceHint ?? '').isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.request_quote_rounded,
                    label: reply.priceHint!,
                  ),
                if ((reply.deliveryNote ?? '').isNotEmpty)
                  B2bMetaPill(
                    icon: Icons.local_shipping_outlined,
                    label: reply.deliveryNote!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.forum_outlined,
          size: 17,
          color: AppColors.brandLemonPressed,
        ),
        const SizedBox(width: 6),
        Text(
          count > 0 ? '$title ($count)' : title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
