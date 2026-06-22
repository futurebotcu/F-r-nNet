// B2B Pazar — Tedarikçi > ürün ekleme formu (mock).
//
// Mağazam içinden "Ürün ekle" ile açılır (shell dışı full-screen route).
// Kaydet → in-memory repo'ya eklenir (b2bMarketControllerProvider), Mağazam'a
// ve (yayında ise) genel Ürünler sekmesine yansır. Backend/upload YOK.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/widgets/dirty_form_guard.dart';
import '../../../../../core/widgets/premium/premium_scaffold.dart';
import '../../../../../core/widgets/premium/premium_top_banner.dart';
import '../../../providers/b2b_providers.dart';
import '../../../services/b2b_media_upload_service.dart';
import '../../../widgets/b2b_form_field.dart';
import '../../../widgets/b2b_image_upload_field.dart';

class SupplierProductFormScreen extends ConsumerStatefulWidget {
  const SupplierProductFormScreen({super.key, this.productId});

  /// Dolu ise düzenleme modu (mevcut ürün prefill edilir).
  final String? productId;

  @override
  ConsumerState<SupplierProductFormScreen> createState() =>
      _SupplierProductFormScreenState();
}

class _SupplierProductFormScreenState
    extends ConsumerState<SupplierProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _minOrder = TextEditingController();
  final _description = TextEditingController();

  String? _category;
  final Set<String> _regions = <String>{};
  bool _published = true;
  String? _imageUrl;
  bool _categoryTouched = false;

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
    final id = widget.productId;
    if (id != null) {
      _editing = true;
      _prefill(id);
    }
  }

  Future<void> _prefill(String id) async {
    _hydrating = true;
    final p = await ref.read(b2bRepositoryProvider).productById(id);
    if (p == null || !mounted) {
      _hydrating = false;
      return;
    }
    final known = ref.read(b2bRepositoryProvider).serviceRegions().toSet();
    setState(() {
      _name.text = p.name;
      _minOrder.text = p.minOrder == 'Belirtilmedi' ? '' : p.minOrder;
      _description.text = p.description;
      _category = p.category;
      _published = p.published;
      _imageUrl = p.imageUrl;
      _regions
        ..clear()
        ..addAll(p.deliveryRegion
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
    _name.dispose();
    _minOrder.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final categoryOk = _category != null;
    if (!categoryOk) setState(() => _categoryTouched = true);
    if (!formOk || !categoryOk) return;

    final regions = _regions.isEmpty ? 'Belirtilmedi' : _regions.join(', ');
    final minOrder =
        _minOrder.text.trim().isEmpty ? 'Belirtilmedi' : _minOrder.text.trim();
    setState(() => _saving = true);
    final controller = ref.read(b2bMarketControllerProvider.notifier);
    try {
      if (_editing) {
        await controller.updateProduct(
          id: widget.productId!,
          name: _name.text.trim(),
          category: _category!,
          minOrder: minOrder,
          deliveryRegion: regions,
          description: _description.text.trim(),
          published: _published,
          imageUrl: _imageUrl,
        );
      } else {
        await controller.addProduct(
          name: _name.text.trim(),
          category: _category!,
          minOrder: minOrder,
          deliveryRegion: regions,
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
        message: 'Ürün kaydedilemedi. Tekrar deneyin.',
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
          ? '${_editing ? 'Ürün güncellendi' : 'Ürün eklendi'} — Mağazam ve Ürünler\'de görünür.'
          : '${_editing ? 'Ürün güncellendi' : 'Ürün eklendi'} — taslak; yalnız Mağazam\'da görünür.',
      tone: PremiumTopBannerTone.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.read(b2bRepositoryProvider).productCategories();
    final regions = ref.read(b2bRepositoryProvider).serviceRegions();

    final scaffold = PremiumScaffold(
      appBar: AppBar(title: Text(_editing ? 'Ürünü düzenle' : 'Ürün ekle')),
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
                label: 'Ürün adı',
                controller: _name,
                hint: 'Ör. Tam Buğday Unu (Tip 850)',
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ürün adı gerekli'
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bSingleSelectChips(
                label: 'Kategori',
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
                label: 'Minimum sipariş',
                controller: _minOrder,
                hint: 'Ör. 50 çuval',
              ),
              const SizedBox(height: AppSpacing.l),
              B2bMultiSelectChips(
                label: 'Teslimat bölgesi',
                options: regions,
                selected: _regions,
                onToggle: (r) => setState(() {
                  _regions.contains(r) ? _regions.remove(r) : _regions.add(r);
                  _dirty = true;
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              const _PriceTypeInfo(),
              const SizedBox(height: AppSpacing.l),
              B2bTextField(
                label: 'Kısa açıklama',
                controller: _description,
                hint: 'Ürün hakkında kısa bilgi (opsiyonel)',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.l),
              B2bImageUploadField(
                kind: B2bMediaKind.product,
                label: 'Ürün görseli',
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
                    : (_editing ? 'Değişiklikleri kaydet' : 'Ürünü kaydet'),
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

/// Fiyat tipi sabit "Teklif al" — bilgi amaçlı, düzenlenemez.
class _PriceTypeInfo extends StatelessWidget {
  const _PriceTypeInfo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Fiyat tipi',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
          ),
          child: const Text(
            'Teklif al',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.brandInk,
            ),
          ),
        ),
      ],
    );
  }
}
