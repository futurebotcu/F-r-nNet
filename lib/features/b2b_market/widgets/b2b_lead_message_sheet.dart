// B2B Pazar — lead bağlamında mini görüşme bottom-sheet'i (paylaşılan).
//
// Genel chat DEĞİL: yalnız ilgili lead üzerinden alıcı ↔ tedarikçi kısa takip.
// Hem alıcı (teklif detayı) hem tedarikçi (İlgilenenler) kullanır; balon
// hizalaması [viewerIsBuyer] ile belirlenir. Telefon/kişisel bilgi otomatik
// paylaşılmaz; gönderen rolü sunucuda lead üyeliğinden türetilir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/b2b_lead_message.dart';
import '../providers/b2b_providers.dart';

Future<void> showB2bLeadMessageSheet(
  BuildContext context, {
  required String leadId,
  required String title,
  required bool viewerIsBuyer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeadMessageSheet(
      leadId: leadId,
      title: title,
      viewerIsBuyer: viewerIsBuyer,
    ),
  );
}

class _LeadMessageSheet extends ConsumerStatefulWidget {
  const _LeadMessageSheet({
    required this.leadId,
    required this.title,
    required this.viewerIsBuyer,
  });
  final String leadId;
  final String title;
  final bool viewerIsBuyer;

  @override
  ConsumerState<_LeadMessageSheet> createState() => _LeadMessageSheetState();
}

class _LeadMessageSheetState extends ConsumerState<_LeadMessageSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(b2bMarketControllerProvider.notifier)
          .sendLeadMessage(leadId: widget.leadId, message: text);
      _input.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj gönderilemedi. Tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(b2bLeadMessagesProvider(widget.leadId));
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
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Bu görüşme sadece bu teklif üzerinden yürür. Kişisel '
                'bilgilerini paylaşmak zorunda değilsin.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: msgs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.l),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text('Mesajlar yüklenemedi.'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                        child: Text(
                          'Henüz mesaj yok. İlk takip notunu yaz.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s),
                      itemBuilder: (_, i) => _Bubble(
                        msg: list[i],
                        viewerIsBuyer: widget.viewerIsBuyer,
                        otherName: widget.title,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Kısa takip mesajı…',
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
                  ),
                  const SizedBox(width: AppSpacing.s),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brandLemon,
                      foregroundColor: AppColors.brandInk,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.viewerIsBuyer,
    required this.otherName,
  });
  final B2bLeadMessage msg;
  final bool viewerIsBuyer;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final mine = viewerIsBuyer ? msg.isBuyer : msg.isSupplier;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.brandLemonPale : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: AppColors.borderHairline, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Sen' : otherName,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.message,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
