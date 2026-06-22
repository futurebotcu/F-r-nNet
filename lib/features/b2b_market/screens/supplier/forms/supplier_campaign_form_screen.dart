// B2B Pazar — Tedarikçi > kampanya oluşturma formu (mock).
//
// Mağazam içinden "Kampanya oluştur" ile açılır (shell dışı full-screen route).
// Kaydet → in-memory repo'ya eklenir; Mağazam Aktif Kampanyalar'a ve (yayında
// ise) genel Kampanyalar sekmesine yansır. Ticari fırsat kartı olarak kalır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/widgets/dirty_form_guard.dart';
import '../../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../../../core/widgets/premium/premium_top_banner.dart';
import '../../../providers/b2b_providers.dart';
import '../../../services/b2b_media_upload_service.dart';
import '../../../widgets/b2b_form_field.dart';
import '../../../widgets/b2b_image_upload_field.dart';

class SupplierCampaignFormScreen extends ConsumerStatefulWidget {
  const SupplierCampaignFormScreen({super.key, this.campaignId});

  /// Dolu ise düzenleme modu (mevcut kampanya prefill edilir).
  final String? campaignId;

  @override
  ConsumerState<SupplierCampaignFormScreen> createState() =>
      _SupplierCampaignFormScreenState();
}

class _SupplierCampaignFormScreenState
    extends ConsumerState<SupplierCampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _linkedProduct = TextEditingController();
  final _minPurchase = TextEditingController();
  final _description = TextEditingController();

  /// FN-AUDIT-006: serbest metin yerine takvim tarihi. null = "Süresiz".
  DateTime? _validUntilDate;

  String? _category;
  final Set<String> _regions = <String>{};
  bool _published = true;
  bool _categoryTouched = false;
  String? _imageUrl;

  bool _editing = false;
  bool _saving = false; // FN-AUDIT-017 — çift-submit guard.
  // PR-UI-2 — kaydedilmemiş değişiklik koruması. `_hydrating` prefill sırasında
  // Form.onChanged'in false-dirty üretmesini engeller.
  bool _dirty = false;
  bool _hydrating = false;
  void _markDirty() {
    if (_hydrating || _dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    final id = widget.campaignId;
    if (id != null) {
      _editing = true;
      _prefill(id);
    }
  }

  Future<void> _prefill(String id) async {
    _hydrating = true;
    final c = await ref.read(b2bRepositoryProvider).campaignById(id);
    if (c == null || !mounted) {
      _hydrating = false;
      return;
    }
    final known = ref.read(b2bRepositoryProvider).serviceRegions().toSet();
    setState(() {
      _title.text = c.title;
      _linkedProduct.text = c.linkedProduct ?? '';
      _minPurchase.text = c.minPurchase == 'Belirtilmedi' ? '' : c.minPurchase;
      _validUntilDate =
          c.validUntil == 'Süresiz' ? null : DateTime.tryParse(c.validUntil);
      _description.text = c.description;
      _category = c.category;
      _published = c.published;
      _imageUrl = c.imageUrl;
      _regions
        ..clear()
        ..addAll(c.region
            .split(', ')
            .map((e) => e.trim())
            .where(known.contains));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hydrating = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _linkedProduct.dispose();
    _minPurchase.dispose();
    _description.dispose();
    super.dispose();
  }

  static String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _validUntilDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
      helpText: 'Geçerlilik tarihi seç',
    );
    if (picked != null) {
      setState(() {
        _validUntilDate = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final categoryOk = _category != null;
    if (!categoryOk) setState(() => _categoryTouched = true);
    if (!formOk || !categoryOk) return;

    final linked = _linkedProduct.text.trim();
    final region = _regions.isEmpty ? 'Belirtilmedi' : _regions.join(', ');
    final minPurchase = _minPurchase.text.trim().isEmpty
        ? 'Belirtilmedi'
        : _minPurchase.text.trim();
    // FN-AUDIT-006: ISO tarih (DB date kolonu) veya boş (Süresiz). Repo
    // `_tryDate` ISO'yu doğru parse eder; serbest metin belirsizliği yok.
    final validUntil =
        _validUntilDate == null ? '' : _isoDate(_validUntilDate!);
    setState(() => _saving = true);
    final controller = ref.read(b2bMarketControllerProvider.notifier);
    try {
      if (_editing) {
        await controller.updateCampaign(
          id: widget.campaignId!,
          title: _title.text.trim(),
          category: _category!,
          region: region,
          minPurchase: minPurchase,
          validUntil: validUntil,
          linkedProduct: linked.isEmpty ? null : linked,
          description: _description.text.trim(),
          published: _published,
          imageUrl: _imageUrl,
        );
      } else {
        await controller.addCampaign(
          title: _title.text.trim(),
          category: _category!,
          region: region,
          minPurchase: minPurchase,
          validUntil: validUntil,
          linkedProduct: linked.isEmpty ? null : linked,
          description: _description.text.trim(),
          published: _published,
          imageUrl: _imageUrl,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PremiumTopBannerController.show(
        context,
        message: 'Kampanya kaydedilemedi. Tekrar deneyin.',
        tone: PremiumTopBannerTone.danger,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    PremiumTopBannerController.show(
      context,
      message: _published
          ? '${_editing ? 'Kampanya güncellendi' : 'Kampanya oluşturuldu'} — Mağazam ve Kampanyalar\'da görünür.'
          : '${_editing ? 'Kampanya güncellendi' : 'Kampanya oluşturuldu'} — taslak; yalnız Mağazam\'da görünür.',
      tone: PremiumTopBannerTone.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.read(b2bRepositoryProvider).productCategories();
    final regions = ref.read(b2bRepositoryProvider).serviceRegions();

    final scaffold = PremiumScaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Kampanyayı düzenle' : 'Kampanya oluştur'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.l,
              AppSpacing.pageH,
              AppSpacing.xxl,
            ),
            children: [
              B2bTextField(
                label: 'Kampanya başlığı',
                controller: _title,
                hint: 'Ör. Toplu Un Alımında Sezon Fırsatı',
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Kampanya başlığı gerekli'
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bSingleSelectChips(
                label: 'Bağlı kategori',
                options: categories,
                selected: _category,
                onSelect: (c) => setState(() {
                  _category = c;
                  _categoryTouched = true;
                  _dirty = true;
                }),
                errorText: _categoryTouched && _category == null
                    ? 'Kategori seçin'
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Bağlı ürün (opsiyonel)',
                controller: _linkedProduct,
                hint: 'Ör. Ekmeklik Un (Tip 650)',
              ),
              const SizedBox(height: AppSpacing.l),
              B2bMultiSelectChips(
                label: 'Bölge',
                options: regions,
                selected: _regions,
                onToggle: (r) => setState(() {
                  _regions.contains(r) ? _regions.remove(r) : _regions.add(r);
                  _dirty = true;
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Minimum alım',
                controller: _minPurchase,
                hint: 'Ör. 200 çuval ve üzeri',
              ),
              const SizedBox(height: AppSpacing.l),
              B2bDateField(
                label: 'Geçerlilik tarihi (opsiyonel)',
                value: _validUntilDate,
                onTap: _pickValidUntil,
                onClear: () => setState(() {
                  _validUntilDate = null;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Kısa açıklama',
                controller: _description,
                hint: 'Kampanya hakkında kısa bilgi (opsiyonel)',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bImageUploadField(
                kind: B2bMediaKind.campaign,
                label: 'Kampanya görseli',
                currentUrl: _imageUrl,
                onChanged: (u) => setState(() {
                  _imageUrl = u;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bStatusField(
                published: _published,
                onChanged: (v) => setState(() {
                  _published = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              B2bSaveButton(
                label: _saving
                    ? 'Kaydediliyor…'
                    : (_editing ? 'Değişiklikleri kaydet' : 'Kampanyayı kaydet'),
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
    return DirtyFormGuard(isDirty: _dirty, child: scaffold);
  }
}
