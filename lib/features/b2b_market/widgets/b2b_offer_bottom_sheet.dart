// B2B Pazar — teklif / fiyat aksiyonu bottom sheet (mock preview).
//
// Tek yüzey, dört kip: Teklif İste · Fiyat Sor · Teklif Ver · Yeni Teklif.
// Mock: bu sürümde talep backend'e yazılmaz (Supabase yok). Gönderince sheet
// kapanır, çağıran taraf PremiumTopBanner ile geri bildirim gösterir.
// Sepet / ödeme / checkout YOK.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';

enum B2bOfferKind { requestQuote, askPrice, giveOffer, newRequest }

/// Sheet'i açar, gönderilirse premium banner ile geri bildirim gösterir.
/// Tüm tab'lar tek bu akışı çağırır.
Future<void> showB2bOfferFlow(
  BuildContext context, {
  required B2bOfferKind kind,
  String? contextLine,
}) async {
  final submitted = await B2bOfferBottomSheet.show(
    context,
    kind: kind,
    contextLine: contextLine,
  );
  if (!submitted || !context.mounted) return;
  PremiumTopBannerController.show(
    context,
    message: '${kind.title} gönderildi. Yanıtlar "Tekliflerim" altında görünür.',
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

  String get noteHint {
    switch (this) {
      case B2bOfferKind.requestQuote:
        return 'Miktar, teslimat bölgesi ve notunuz…';
      case B2bOfferKind.askPrice:
        return 'Fiyat hakkında sormak istediğiniz…';
      case B2bOfferKind.giveOffer:
        return 'Fiyat ve teklif detayınız…';
      case B2bOfferKind.newRequest:
        return 'Kısa not (opsiyonel)…';
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

class B2bOfferBottomSheet extends StatefulWidget {
  const B2bOfferBottomSheet({
    super.key,
    required this.kind,
    this.contextLine,
  });

  final B2bOfferKind kind;

  /// Bağlam satırı (ör. "Anadolu Un & Maya · Tam Buğday Unu").
  final String? contextLine;

  /// Sheet'i açar; gönderildiyse `true` döner (çağıran banner gösterir).
  static Future<bool> show(
    BuildContext context, {
    required B2bOfferKind kind,
    String? contextLine,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => B2bOfferBottomSheet(kind: kind, contextLine: contextLine),
    );
    return result ?? false;
  }

  @override
  State<B2bOfferBottomSheet> createState() => _B2bOfferBottomSheetState();
}

class _B2bOfferBottomSheetState extends State<B2bOfferBottomSheet> {
  final _product = TextEditingController();
  final _quantity = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();

  bool get _isNewRequest => widget.kind == B2bOfferKind.newRequest;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _city.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
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
              if (_isNewRequest) ...[
                _Field(
                  controller: _product,
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
                _Field(
                  controller: _city,
                  label: 'İl',
                  hint: 'Ör. İstanbul',
                ),
                const SizedBox(height: AppSpacing.m),
              ],
              _Field(
                controller: _note,
                label: 'Not',
                hint: widget.kind.noteHint,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.s),
              const _PrivacyHint(),
              const SizedBox(height: AppSpacing.l),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    widget.kind.submitLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
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
