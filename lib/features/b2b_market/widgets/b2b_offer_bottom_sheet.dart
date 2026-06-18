// B2B Pazar — teklif / fiyat aksiyonu bottom sheet.
//
// Tek yüzey, bağlama göre DÖRT alıcı kipi + tedarikçi cevabı:
//   * product  : ürün kartından → kategori SABİT (değiştirilemez)
//   * campaign : kampanya kartından → kategori SABİT
//   * supplier : tedarikçi kartından → tedarikçi sabit, kategori SEÇİLİR
//   * general  : genel talep → kategori seçilir + ürün/istek adı yazılabilir
//   * reply    : tedarikçi "Teklif Ver" → addQuoteReply
// Repository write controller üzerinden yapılır (UI doğrudan Supabase görmez).
//
// KONTROLLÜ ALANLAR: kategori chip/dropdown veya sabit; şehir sabit listeden
// dropdown; alıcı tipi profilden türetilir. Serbest metin yalnız miktar/not/
// ilçe/istek adı.
//
// ANONİMLİK: bu yüzey alıcı kimliği (buyer_id/telefon/adres/kişi) TOPLAMAZ ve
// GÖSTERMEZ. addQuoteRequest yalnız güvenli alanları yollar; buyer_id repo
// içinde auth.uid()'den set edilir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/b2b_providers.dart';

enum B2bOfferKind { requestQuote, askPrice, giveOffer, newRequest }

/// Teklif İste formunun bağlam kipi (targetType'tan türetilir).
enum _OfferMode { product, campaign, supplier, general, reply }

/// Şehir seçimi — küçük sabit liste (büyük veri paketi yok).
const List<String> kB2bCities = [
  'İstanbul',
  'Ankara',
  'İzmir',
  'Bursa',
  'Kocaeli',
  'Konya',
  'Antalya',
  'Gaziantep',
];

/// Teslimat zamanı — kontrollü seçenekler.
const List<String> kB2bDeliveryOptions = [
  'Bu hafta',
  'Bu ay',
  'Acil',
  'Esnek / fark etmez',
];

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
  String? _selectedCategory; // dropdown (supplier/general)
  final _requestName = TextEditingController(); // genel: serbest istek adı
  final _quantity = TextEditingController();
  String? _selectedCity;
  final _district = TextEditingController();
  String? _selectedDelivery;
  final _note = TextEditingController();
  // Tedarikçi cevap alanları.
  final _message = TextEditingController();
  final _priceNote = TextEditingController();
  final _deliveryNote = TextEditingController();

  bool _submitting = false;
  String? _error;

  late final _OfferMode _mode = _resolveMode();

  _OfferMode _resolveMode() {
    if (widget.kind == B2bOfferKind.giveOffer) return _OfferMode.reply;
    switch (widget.targetType) {
      case 'product':
        return _OfferMode.product;
      case 'campaign':
        return _OfferMode.campaign;
      case 'shop':
      case 'supplier':
        return _OfferMode.supplier;
      default:
        return _OfferMode.general;
    }
  }

  bool get _isReply => _mode == _OfferMode.reply;
  bool get _categoryFixed =>
      _mode == _OfferMode.product || _mode == _OfferMode.campaign;
  bool get _categorySelectable =>
      _mode == _OfferMode.supplier || _mode == _OfferMode.general;

  @override
  void initState() {
    super.initState();
    // Sabit/önseçili kategori dropdown'da varsa seç.
    final preset = widget.presetCategory;
    if (_categorySelectable && preset != null && preset.isNotEmpty) {
      _selectedCategory = preset;
    }
  }

  @override
  void dispose() {
    _requestName.dispose();
    _quantity.dispose();
    _district.dispose();
    _note.dispose();
    _message.dispose();
    _priceNote.dispose();
    _deliveryNote.dispose();
    super.dispose();
  }

  /// Profilden güvenli alıcı tipi türetir (serbest metin değil).
  String _buyerTypeFromProfile() {
    final account = ref.read(
      profileControllerProvider.select((p) => p?.accountType),
    );
    switch (account) {
      case AccountType.individual:
        return 'Bireysel';
      case AccountType.commercial:
        return 'Ticari';
      case AccountType.wholesaler:
        return 'Tedarikçi';
      case null:
        return '';
    }
  }

  /// Gönderilecek kategori/ürün adı (kipe göre).
  String _resolvedCategory() {
    if (_categoryFixed) return (widget.presetCategory ?? '').trim();
    final name = _requestName.text.trim();
    if (_mode == _OfferMode.general && name.isNotEmpty) return name;
    return (_selectedCategory ?? '').trim();
  }

  Future<void> _submit() async {
    final bool missing;
    if (_isReply) {
      missing = _message.text.trim().isEmpty;
    } else {
      missing = _resolvedCategory().isEmpty ||
          _quantity.text.trim().isEmpty ||
          _selectedCity == null;
    }
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
          priceNote:
              _priceNote.text.trim().isEmpty ? null : _priceNote.text.trim(),
          deliveryNote: _deliveryNote.text.trim().isEmpty
              ? null
              : _deliveryNote.text.trim(),
        );
      } else {
        await ctrl.addQuoteRequest(
          targetType: widget.targetType,
          targetId: widget.targetId,
          category: _resolvedCategory(),
          quantity: _quantity.text.trim(),
          city: _selectedCity!,
          district: _district.text.trim(),
          buyerType: _buyerTypeFromProfile(),
          deliveryTime: _selectedDelivery ?? '',
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
    final categories = ref.read(b2bRepositoryProvider).productCategories();
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
                if (_isReply)
                  ..._replyFields()
                else
                  ..._requestFields(categories),
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

  // ---- Tedarikçi cevap alanları ----
  List<Widget> _replyFields() => [
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
        const SizedBox(height: AppSpacing.m),
        _Field(
          controller: _deliveryNote,
          label: 'Teslimat notu (opsiyonel)',
          hint: 'Ör. Bu hafta teslim',
        ),
      ];

  // ---- Alıcı talebi alanları (kipe göre) ----
  List<Widget> _requestFields(List<String> categories) {
    return [
      // Kategori: sabit (product/campaign) veya seçilir (supplier/general).
      if (_categoryFixed)
        _LockedField(
          label: 'Ürün / kategori',
          value: (widget.presetCategory ?? '').isNotEmpty
              ? widget.presetCategory!
              : (widget.contextLine ?? '—'),
        )
      else
        _DropdownField(
          label: 'Kategori',
          hint: 'Kategori seç',
          value: _selectedCategory,
          items: categories,
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      if (_mode == _OfferMode.general) ...[
        const SizedBox(height: AppSpacing.m),
        _Field(
          controller: _requestName,
          label: 'Ürün / istek adı (opsiyonel)',
          hint: 'Ör. Tam buğday unu (Tip 850)',
        ),
      ],
      const SizedBox(height: AppSpacing.m),
      _Field(
        controller: _quantity,
        label: 'Miktar',
        hint: 'Ör. 150 çuval',
      ),
      const SizedBox(height: AppSpacing.m),
      _DropdownField(
        label: 'İl',
        hint: 'İl seç',
        value: _selectedCity,
        items: kB2bCities,
        onChanged: (v) => setState(() => _selectedCity = v),
      ),
      const SizedBox(height: AppSpacing.m),
      _Field(
        controller: _district,
        label: 'İlçe (opsiyonel)',
        hint: 'Ör. Kadıköy',
      ),
      const SizedBox(height: AppSpacing.m),
      _DropdownField(
        label: 'Teslimat zamanı (opsiyonel)',
        hint: 'Seç',
        value: _selectedDelivery,
        items: kB2bDeliveryOptions,
        onChanged: (v) => setState(() => _selectedDelivery = v),
      ),
      const SizedBox(height: AppSpacing.m),
      _Field(
        controller: _note,
        label: 'Not (opsiyonel)',
        hint: 'Ek istekler…',
        maxLines: 2,
      ),
    ];
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
        _FieldLabel(label),
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
            enabledBorder: _border(AppColors.borderHairline, 0.8),
            focusedBorder: _border(AppColors.brandLemonPressed, 1.2),
          ),
        ),
      ],
    );
  }
}

/// Kontrollü seçim alanı (kategori / il / teslimat).
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.textMuted),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          hint: Text(
            hint,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            enabledBorder: _border(AppColors.borderHairline, 0.8),
            focusedBorder: _border(AppColors.brandLemonPressed, 1.2),
          ),
          items: [
            for (final it in items)
              DropdownMenuItem<String>(value: it, child: Text(it)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Sabit (değiştirilemez) bağlam alanı — kilit ikonlu.
class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: AppColors.brandLemonPressed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
      borderSide: BorderSide(color: color, width: width),
    );

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded,
            size: 14, color: AppColors.textMuted),
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
