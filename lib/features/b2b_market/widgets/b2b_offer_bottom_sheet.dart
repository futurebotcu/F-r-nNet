// B2B Pazar — teklif / fiyat aksiyonu bottom sheet.
//
// Tek yüzey, dört kip:
//   * Teklif İste / Fiyat Sor / Yeni Teklif (ALICI) → addQuoteRequest
//   * Teklif Ver (TEDARİKÇİ)                         → addQuoteReply
// Repository write controller üzerinden yapılır (UI doğrudan Supabase görmez).
// Gönderim sırasında buton loading/disabled; hata sheet içinde kısa metinle
// gösterilir (ekran çökmez). Sepet / ödeme / checkout YOK.
//
// ANONİMLİK: bu yüzey alıcı kimliği (buyer_id/telefon/adres/kişi) TOPLAMAZ ve
// GÖSTERMEZ. addQuoteRequest yalnız güvenli alanları yollar; buyer_id repo
// içinde auth.uid()'den set edilir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../providers/b2b_providers.dart';

enum B2bOfferKind { requestQuote, askPrice, giveOffer, newRequest }

/// Sheet'i açar; gönderilirse premium banner ile geri bildirim gösterir.
/// Tüm tab'lar tek bu akışı çağırır.
Future<void> showB2bOfferFlow(
  BuildContext context, {
  required B2bOfferKind kind,
  String? contextLine,
  String targetType = 'category',
  String? targetId,
  String? presetCategory,
  String? quoteRequestId,
}) async {
  final submitted = await B2bOfferBottomSheet.show(
    context,
    kind: kind,
    contextLine: contextLine,
    targetType: targetType,
    targetId: targetId,
    presetCategory: presetCategory,
    quoteRequestId: quoteRequestId,
  );
  if (!submitted || !context.mounted) return;
  PremiumTopBannerController.show(
    context,
    message: kind == B2bOfferKind.giveOffer
        ? 'Teklifin gönderildi.'
        : 'Talebin alındı. Yanıtlar "Tekliflerim" altında görünür.',
    tone: PremiumTopBannerTone.success,
    duration: const Duration(seconds: 2),
  );
}

extension _B2bOfferKindMeta on B2bOfferKind {
  String get title {
    switch (this) {
      case B2bOfferKind.requestQuote:
        return 'Teklif İste';
      case B2bOfferKind.askPrice:
        return 'Fiyat Sor';
      case B2bOfferKind.giveOffer:
        return 'Teklif Ver';
      case B2bOfferKind.newRequest:
        return 'Yeni Teklif Talebi';
    }
  }

  String get submitLabel {
    switch (this) {
      case B2bOfferKind.requestQuote:
        return 'Teklif iste';
      case B2bOfferKind.askPrice:
        return 'Soruyu gönder';
      case B2bOfferKind.giveOffer:
        return 'Teklifi gönder';
      case B2bOfferKind.newRequest:
        return 'Talebi yayınla';
    }
  }

  IconData get icon {
    switch (this) {
      case B2bOfferKind.requestQuote:
        return Icons.request_quote_rounded;
      case B2bOfferKind.askPrice:
        return Icons.help_outline_rounded;
      case B2bOfferKind.giveOffer:
        return Icons.local_offer_rounded;
      case B2bOfferKind.newRequest:
        return Icons.add_business_rounded;
    }
  }
}

class B2bOfferBottomSheet extends ConsumerStatefulWidget {
  const B2bOfferBottomSheet({
    super.key,
    required this.kind,
    this.contextLine,
    this.targetType = 'category',
    this.targetId,
    this.presetCategory,
    this.quoteRequestId,
  });

  final B2bOfferKind kind;
  final String? contextLine;
  final String targetType;
  final String? targetId;
  final String? presetCategory;
  final String? quoteRequestId;

  /// Sheet'i açar; başarıyla gönderildiyse `true` döner.
  static Future<bool> show(
    BuildContext context, {
    required B2bOfferKind kind,
    String? contextLine,
    String targetType = 'category',
    String? targetId,
    String? presetCategory,
    String? quoteRequestId,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => B2bOfferBottomSheet(
        kind: kind,
        contextLine: contextLine,
        targetType: targetType,
        targetId: targetId,
        presetCategory: presetCategory,
        quoteRequestId: quoteRequestId,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<B2bOfferBottomSheet> createState() =>
      _B2bOfferBottomSheetState();
}

class _B2bOfferBottomSheetState extends ConsumerState<B2bOfferBottomSheet> {
  // Alıcı talebi alanları.
  late final TextEditingController _category =
      TextEditingController(text: widget.presetCategory ?? '');
  final _quantity = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();
  // Tedarikçi cevap alanları.
  final _message = TextEditingController();
  final _priceNote = TextEditingController();

  bool _submitting = false;
  String? _error;

  bool get _isReply => widget.kind == B2bOfferKind.giveOffer;

  @override
  void dispose() {
    _category.dispose();
    _quantity.dispose();
    _city.dispose();
    _note.dispose();
    _message.dispose();
    _priceNote.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Basit zorunlu alan kontrolü.
    final missing = _isReply
        ? _message.text.trim().isEmpty
        : (_category.text.trim().isEmpty ||
            _quantity.text.trim().isEmpty ||
            _city.text.trim().isEmpty);
    if (missing) {
      setState(() => _error = 'Lütfen gerekli alanları doldurun.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(b2bMarketControllerProvider.notifier);
      if (_isReply) {
        await ctrl.addQuoteReply(
          quoteRequestId: widget.quoteRequestId ?? '',
          message: _message.text.trim(),
          priceNote: _priceNote.text.trim().isEmpty
              ? null
              : _priceNote.text.trim(),
        );
      } else {
        await ctrl.addQuoteRequest(
          targetType: widget.targetType,
          targetId: widget.targetId,
          category: _category.text.trim(),
          quantity: _quantity.text.trim(),
          city: _city.text.trim(),
          note: _note.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderHairline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandLemonPale,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(
                          color: AppColors.brandLemonSoft,
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        widget.kind.icon,
                        size: 20,
                        color: AppColors.brandLemonPressed,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(
                        widget.kind.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.contextLine != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    widget.contextLine!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                if (_isReply) ...[
                  _Field(
                    controller: _message,
                    label: 'Mesaj',
                    hint: 'Teklif detayınız…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _Field(
                    controller: _priceNote,
                    label: 'Fiyat notu (opsiyonel)',
                    hint: 'Ör. ≈ ₺640 / çuval',
                  ),
                ] else ...[
                  _Field(
                    controller: _category,
                    label: 'Ürün / kategori',
                    hint: 'Ör. Ekmeklik Un',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _Field(
                    controller: _quantity,
                    label: 'Miktar',
                    hint: 'Ör. 150 çuval',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _Field(controller: _city, label: 'İl', hint: 'Ör. İstanbul'),
                  const SizedBox(height: AppSpacing.m),
                  _Field(
                    controller: _note,
                    label: 'Not (opsiyonel)',
                    hint: 'Teslimat zamanı, ek istekler…',
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: AppSpacing.s),
                const _PrivacyHint(),
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
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandInk,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Gönderiliyor…' : widget.kind.submitLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandLemon,
                      foregroundColor: AppColors.brandInk,
                      disabledBackgroundColor: AppColors.brandLemonSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              borderSide: const BorderSide(
                color: AppColors.borderHairline,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              borderSide: const BorderSide(
                color: AppColors.brandLemonPressed,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'İletişim bilginiz karşı tarafa otomatik açılmaz.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
