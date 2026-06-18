// B2B Pazar — Alıcı > Teklif detayı.
//
// Tekliflerim'deki bir talebe basınca açılır (/pazar/tekliflerim/:id).
// Talep özeti + gelen teklifler (tedarikçi cevapları). Tedarikçi kimliği
// (cevaplayan mağaza adı) görünür; ALICI kimliği zaten yok. Veri yalnız
// repository (FutureProvider) üzerinden; UI Supabase'i doğrudan görmez.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/error_retry_state.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';
import '../../models/b2b_lead_message.dart';
import '../../models/b2b_quote_lead.dart';
import '../../models/b2b_quote_reply.dart';
import '../../models/b2b_quote_request.dart';
import '../../providers/b2b_providers.dart';
import '../../widgets/b2b_lead_message_sheet.dart';
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
                _Replies(
                  quoteRequestId: quoteRequestId,
                  requestActive: req.status.isActive,
                ),
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
  const _Replies({required this.quoteRequestId, required this.requestActive});
  final String quoteRequestId;
  final bool requestActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(b2bRepliesProvider(quoteRequestId));
    final leadsAsync = ref.watch(b2bRequestLeadsProvider(quoteRequestId));
    final leadByReply = <String, B2bQuoteLead>{
      for (final l in (leadsAsync.valueOrNull ?? const <B2bQuoteLead>[]))
        l.quoteReplyId: l,
    };
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
        final hasAccepted = list.any((r) => r.accepted);
        return Column(
          children: [
            for (final r in list) ...[
              _ReplyCard(
                reply: r,
                lead: leadByReply[r.id],
                requestActive: requestActive,
                requestHasAccepted: hasAccepted,
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
              ),
              child: const Text(
                'Bu teklif üzerinden ilerlemek için tedarikçi mağazasını '
                'inceleyin. FırınNet içinde güvenli teklif akışı; iletişim '
                'bilgileri sonraki sürümde yönetilecek.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReplyCard extends ConsumerWidget {
  const _ReplyCard({
    required this.reply,
    required this.lead,
    required this.requestActive,
    required this.requestHasAccepted,
  });
  final B2bQuoteReply reply;
  final B2bQuoteLead? lead;
  final bool requestActive;
  final bool requestHasAccepted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: AppSpacing.m),
          _LeadArea(
            reply: reply,
            lead: lead,
            requestActive: requestActive,
            requestHasAccepted: requestHasAccepted,
          ),
        ],
      ),
    );
  }
}

/// Teklif kartının aksiyon/durum bölümü: kabul + ilgi + takip mesajı + mağaza.
class _LeadArea extends ConsumerWidget {
  const _LeadArea({
    required this.reply,
    required this.lead,
    required this.requestActive,
    required this.requestHasAccepted,
  });
  final B2bQuoteReply reply;
  final B2bQuoteLead? lead;
  final bool requestActive;
  final bool requestHasAccepted;

  Widget _storeButton(BuildContext context) {
    if ((reply.supplierShopId ?? '').isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            context.push(AppRoutes.b2bStoreDetail(reply.supplierShopId!)),
        icon: const Icon(Icons.storefront_outlined, size: 16),
        label: const Text('Tedarikçi mağazasını gör'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(b2bMarketControllerProvider.notifier)
          .rejectQuoteReply(reply.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarısız. Tekrar deneyin.')),
        );
      }
    }
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(b2bMarketControllerProvider.notifier)
          .acceptQuoteReply(reply.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu teklifle ilerliyorsun. Tedarikçiye iletildi.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarısız. Tekrar deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = lead;
    final rows = <Widget>[];

    // 1) Anlaşma / kabul durumu.
    if (reply.accepted) {
      rows.add(const _LeadChip(
        icon: Icons.verified_rounded,
        label: 'Seçilen teklif',
        tone: _ChipTone.success,
      ));
    } else if (requestHasAccepted) {
      rows.add(const _LeadChip(
        icon: Icons.info_outline_rounded,
        label: 'Başka teklif seçildi',
        tone: _ChipTone.muted,
      ));
    } else if (requestActive) {
      rows.add(SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _accept(context, ref),
          icon: const Icon(Icons.handshake_outlined, size: 17),
          label: const Text('Bu teklifle ilerle'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandLemon,
            foregroundColor: AppColors.brandInk,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ),
      ));
    }

    // 2) İlgi durumu / aksiyonları.
    if (l != null && l.isInterested) {
      rows.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          const _LeadChip(
            icon: Icons.check_circle_rounded,
            label: 'İlgilenildi',
            tone: _ChipTone.success,
          ),
          _LeadChip(
            icon: l.phoneShared
                ? Icons.phone_in_talk_rounded
                : Icons.phone_disabled_rounded,
            label:
                l.phoneShared ? 'Telefon paylaşıldı' : 'Telefon paylaşılmadı',
            tone: l.phoneShared ? _ChipTone.success : _ChipTone.muted,
          ),
        ],
      ));
      // 3) Lead takip mesajı (mini görüşme).
      rows.add(_LeadThread(leadId: l.id, supplierName: reply.supplierName));
    } else if (l != null && l.isRejected) {
      rows.add(const _LeadChip(
        icon: Icons.cancel_outlined,
        label: 'Uygun değil olarak işaretlendi',
        tone: _ChipTone.muted,
      ));
    } else if (requestActive) {
      rows.add(Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showInterestDialog(context, reply.id),
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
              label: const Text('İlgileniyorum'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandLemonPale,
                foregroundColor: AppColors.brandInk,
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          OutlinedButton(
            onPressed: () => _reject(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderHairline),
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            child: const Text('Uygun değil'),
          ),
        ],
      ));
    }

    // 4) Tedarikçi mağazası.
    rows.add(_storeButton(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s),
          rows[i],
        ],
      ],
    );
  }
}

enum _ChipTone { success, muted }

class _LeadChip extends StatelessWidget {
  const _LeadChip({required this.icon, required this.label, required this.tone});
  final IconData icon;
  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = tone == _ChipTone.success
        ? (const Color(0xFFF3FBEF), const Color(0xFF166534))
        : (AppColors.surfaceVariant, AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showInterestDialog(BuildContext context, String replyId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InterestSheet(quoteReplyId: replyId),
  );
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

/// "İlgileniyorum" akışı: kısa mesaj + opsiyonel telefon paylaşımı (onaylı).
class _InterestSheet extends ConsumerStatefulWidget {
  const _InterestSheet({required this.quoteReplyId});
  final String quoteReplyId;

  @override
  ConsumerState<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends ConsumerState<_InterestSheet> {
  final _message = TextEditingController(
    text: 'Bu teklifle ilgileniyorum, görüşmek istiyorum.',
  );
  final _phone = TextEditingController();
  bool _sharePhone = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sharePhone && _phone.text.trim().isEmpty) {
      setState(() => _error = 'Telefon paylaşmayı seçtin; numara gir veya onayı kaldır.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(b2bMarketControllerProvider.notifier).expressInterestInQuoteReply(
            quoteReplyId: widget.quoteReplyId,
            message: _message.text.trim(),
            phoneShared: _sharePhone,
            phone: _sharePhone ? _phone.text.trim() : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sharePhone
                ? 'Tedarikçiye ilgilendiğin bildirildi. Telefonun paylaşıldı.'
                : 'Tedarikçiye ilgilendiğin bildirildi.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Gönderilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bu teklifle ilgileniyor musun?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                const Text(
                  'Tedarikçiye bu teklifle ilgilendiğini ileteceğiz. İstersen '
                  'telefonunu da paylaşabilirsin.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                TextField(
                  controller: _message,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mesaj',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      borderSide: const BorderSide(
                        color: AppColors.borderHairline,
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                CheckboxListTile(
                  value: _sharePhone,
                  onChanged: (v) => setState(() => _sharePhone = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: AppColors.brandLemonPressed,
                  title: const Text(
                    'Telefonumu bu tedarikçiyle paylaş',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Telefon paylaşmadan da ilgini iletebilirsin.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ),
                if (_sharePhone) ...[
                  const SizedBox(height: AppSpacing.s),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Telefon',
                      hintText: 'Ör. 05xx xxx xx xx',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        borderSide: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: AppColors.borderHairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                        ),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandLemon,
                          foregroundColor: AppColors.brandInk,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        child: Text(_submitting ? 'Gönderiliyor…' : 'Gönder'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lead takip mesajı: son mesaj önizleme + "görüşmeyi aç". Mini görüşme.
class _LeadThread extends ConsumerWidget {
  const _LeadThread({required this.leadId, required this.supplierName});
  final String leadId;
  final String supplierName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgs = ref.watch(b2bLeadMessagesProvider(leadId));
    final list = msgs.valueOrNull ?? const <B2bLeadMessage>[];
    final last = list.isEmpty ? null : list.last;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (last != null) ...[
            Text(
              '${last.isBuyer ? 'Sen' : supplierName}: ${last.message}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showB2bLeadMessageSheet(
                context,
                leadId: leadId,
                title: supplierName,
                viewerIsBuyer: true,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: Text(last == null
                  ? 'Takip mesajı gönder'
                  : 'Görüşmeyi aç (${list.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderHairline),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
