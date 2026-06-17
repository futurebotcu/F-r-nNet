// B2B Pazar — Tedarikçi > kampanya oluşturma formu (mock).
//
// Mağazam içinden "Kampanya oluştur" ile açılır (shell dışı full-screen route).
// Kaydet → in-memory repo'ya eklenir; Mağazam Aktif Kampanyalar'a ve (yayında
// ise) genel Kampanyalar sekmesine yansır. Ticari fırsat kartı olarak kalır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../../../core/widgets/premium/premium_top_banner.dart';
import '../../../providers/b2b_providers.dart';
import '../../../widgets/b2b_form_field.dart';

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
  final _validUntil = TextEditingController();
  final _description = TextEditingController();

  String? _category;
  final Set<String> _regions = <String>{};
  bool _published = true;
  bool _categoryTouched = false;

  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final id = widget.campaignId;
    if (id == null) return;
    final c = ref.read(b2bRepositoryProvider).campaignById(id);
    if (c == null) return;
    _editing = true;
    _title.text = c.title;
    _linkedProduct.text = c.linkedProduct ?? '';
    _minPurchase.text = c.minPurchase == 'Belirtilmedi' ? '' : c.minPurchase;
    _validUntil.text = c.validUntil == 'Süresiz' ? '' : c.validUntil;
    _description.text = c.description;
    _category = c.category;
    _published = c.published;
    final known = ref.read(b2bRepositoryProvider).serviceRegions().toSet();
    for (final r in c.region.split(', ')) {
      if (known.contains(r.trim())) _regions.add(r.trim());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _linkedProduct.dispose();
    _minPurchase.dispose();
    _validUntil.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final formOk = _formKey.currentState?.validate() ?? false;
    final categoryOk = _category != null;
    if (!categoryOk) setState(() => _categoryTouched = true);
    if (!formOk || !categoryOk) return;

    final linked = _linkedProduct.text.trim();
    final region = _regions.isEmpty ? 'Belirtilmedi' : _regions.join(', ');
    final minPurchase = _minPurchase.text.trim().isEmpty
        ? 'Belirtilmedi'
        : _minPurchase.text.trim();
    final validUntil =
        _validUntil.text.trim().isEmpty ? 'Süresiz' : _validUntil.text.trim();
    final controller = ref.read(b2bMarketControllerProvider.notifier);
    if (_editing) {
      controller.updateCampaign(
        id: widget.campaignId!,
        title: _title.text.trim(),
        category: _category!,
        region: region,
        minPurchase: minPurchase,
        validUntil: validUntil,
        linkedProduct: linked.isEmpty ? null : linked,
        description: _description.text.trim(),
        published: _published,
      );
    } else {
      controller.addCampaign(
        title: _title.text.trim(),
        category: _category!,
        region: region,
        minPurchase: minPurchase,
        validUntil: validUntil,
        linkedProduct: linked.isEmpty ? null : linked,
        description: _description.text.trim(),
        published: _published,
      );
    }

    Navigator.of(context).pop();
    PremiumTopBannerController.show(
      context,
      title: _editing ? 'Kampanya güncellendi' : 'Kampanya oluşturuldu',
      message: _published
          ? 'Kampanya yayında; Mağazam ve Kampanyalar\'da görünür.'
          : 'Kampanya taslak; yalnız Mağazam\'da görünür.',
      tone: PremiumTopBannerTone.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.read(b2bRepositoryProvider).productCategories();
    final regions = ref.read(b2bRepositoryProvider).serviceRegions();

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Kampanyayı düzenle' : 'Kampanya oluştur'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
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
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Minimum alım',
                controller: _minPurchase,
                hint: 'Ör. 200 çuval ve üzeri',
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Geçerlilik tarihi',
                controller: _validUntil,
                hint: 'Ör. 30 Haziran 2026',
              ),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Kısa açıklama',
                controller: _description,
                hint: 'Kampanya hakkında kısa bilgi (opsiyonel)',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bStatusField(
                published: _published,
                onChanged: (v) => setState(() => _published = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              B2bSaveButton(
                label: _editing ? 'Değişiklikleri kaydet' : 'Kampanyayı kaydet',
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
