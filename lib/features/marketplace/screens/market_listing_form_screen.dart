// FırınNet Market V1 M2 — Market ilan formu (genişletilmiş).
//
// Donor pattern: Bagisto `add_to_cart_bottom_sheet.dart` + product form
// pattern (multi-image picker, conditional fields, sticky CTA). FırınNet
// adaptasyonu:
//   * listing_type 2-value (equipment_sale / bakery_transfer) — 'product' YOK.
//   * Equipment_sale → equipment_category + brand/model/year + condition.
//   * Bakery_transfer → rent_price/transfer_price/area_m2 + has_license +
//     equipment_included.
//   * Multi-photo picker (max 6) — galeri + kamera, ext fallback.
//   * Contact_preference (in_app / phone / whatsapp) + phone/whatsapp alanları.
//   * Negotiable switch.
//   * Sticky bottom Publish CTA (Scaffold.bottomNavigationBar).
//   * Photos post-create upload (storage rollback repository tarafında).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';
import '../../../core/widgets/location_picker.dart';

class _PickedPhoto {
  _PickedPhoto({required this.bytes, required this.ext});
  final Uint8List bytes;
  final String ext;
}

class MarketListingFormScreen extends ConsumerStatefulWidget {
  const MarketListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<MarketListingFormScreen> createState() =>
      _MarketListingFormScreenState();
}

class _MarketListingFormScreenState
    extends ConsumerState<MarketListingFormScreen> {
  static const int _maxPhotos = 6;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _rentPrice = TextEditingController();
  final _transferPrice = TextEditingController();
  final _areaM2 = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactWhatsapp = TextEditingController();

  String _category = 'ekipman';
  String _listingType = MarketplaceTaxonomy.defaultListingType;
  String? _condition;
  String? _equipmentCategory;
  String _contactPreference = MarketplaceTaxonomy.defaultContactPreference;
  String _currency = MarketplaceTaxonomy.defaultCurrency;
  bool _negotiable = false;
  bool? _equipmentIncluded;
  bool? _hasLicense;
  String _status = 'active';
  String? _error;

  // V1 Market M2 controlled-data: serbest TextField yerine picker.
  TurkeyProvince? _selectedProvince;
  TurkeyDistrict? _selectedDistrict;

  // Photos: edit'te server-side mevcut, ek olarak picker'dan eklenen.
  final List<_PickedPhoto> _newPhotos = [];

  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.listingId != null) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadExisting() async {
    final m = await ref
        .read(marketListingRepositoryProvider)
        .getListing(widget.listingId!);
    if (!mounted || m == null) {
      setState(() => _loaded = true);
      return;
    }
    _title.text = m.title;
    _description.text = m.description ?? '';
    _price.text = m.price?.toStringAsFixed(0) ?? '';
    _unit.text = m.unit ?? '';
    _brand.text = m.brand ?? '';
    _model.text = m.model ?? '';
    _year.text = m.year?.toString() ?? '';
    _rentPrice.text = m.rentPrice?.toStringAsFixed(0) ?? '';
    _transferPrice.text = m.transferPrice?.toStringAsFixed(0) ?? '';
    _areaM2.text = m.areaM2?.toString() ?? '';
    _contactPhone.text = m.contactPhone ?? '';
    _contactWhatsapp.text = m.contactWhatsapp ?? '';
    _category = m.category;
    _listingType = m.listingType;
    _condition = m.condition;
    _equipmentCategory = m.equipmentCategory;
    _contactPreference = m.contactPreference;
    _currency = MarketplaceTaxonomy.isValidCurrency(m.currency)
        ? m.currency
        : MarketplaceTaxonomy.defaultCurrency;
    _negotiable = m.negotiable;
    _equipmentIncluded = m.equipmentIncluded;
    _hasLicense = m.hasLicense;
    _status = m.status;
    // Lokasyon hydrate — code → controlled-vocabulary lookup.
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(m.cityCode) ??
        TurkeyLocations.findProvinceByName(m.city);
    if (_selectedProvince != null) {
      _selectedDistrict = TurkeyLocations.findDistrict(
        _selectedProvince!.code,
        m.districtCode,
      );
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _unit.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _rentPrice.dispose();
    _transferPrice.dispose();
    _areaM2.dispose();
    _contactPhone.dispose();
    _contactWhatsapp.dispose();
    super.dispose();
  }

  // ─── Photo picker ────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    if (_newPhotos.length >= _maxPhotos) {
      _showSnack(AppStrings.marketListingPhotoMaxHint);
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final ext = _extractImageExt(x.name, x.path);
      if (!mounted) return;
      setState(() {
        _newPhotos.add(_PickedPhoto(bytes: bytes, ext: ext));
      });
    } catch (e) {
      debugPrint('[FirinNet][MarketForm] pickPhoto error: $e');
      if (mounted) _showSnack(AppStrings.marketListingErrorGeneric);
    }
  }

  static String _extractImageExt(String name, String path) {
    const known = <String>{'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    String fromCandidate(String c) {
      final dot = c.lastIndexOf('.');
      if (dot <= 0 || dot >= c.length - 1) return '';
      return c
          .substring(dot + 1)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final fromName = fromCandidate(name);
    if (known.contains(fromName)) return fromName;
    final fromPath = fromCandidate(path);
    if (known.contains(fromPath)) return fromPath;
    return 'jpg';
  }

  void _removePickedPhoto(int index) {
    setState(() => _newPhotos.removeAt(index));
  }

  // ─── Save flow ────────────────────────────────────────────────────

  Future<void> _onPublishPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(marketListingRepositoryProvider);
    final isEquip = _listingType == 'equipment_sale';
    final isTransfer = _listingType == 'bakery_transfer';
    final listing = MarketListing(
      id: widget.listingId,
      title: _title.text.trim(),
      category: _category,
      listingType: _listingType,
      condition: isEquip ? _condition : null,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      // V1 Market M2 controlled-data fix — picker'dan code + display label.
      countryCode: MarketplaceTaxonomy.defaultCountryCode,
      cityCode: _selectedProvince?.code,
      city: _selectedProvince?.name,
      districtCode: _selectedDistrict?.code,
      district: _selectedDistrict?.name,
      currency: _currency,
      price: isEquip ? double.tryParse(_price.text.trim()) : null,
      unit: isEquip && _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
      contactPreference: _contactPreference,
      status: _status,
      equipmentCategory: isEquip ? _equipmentCategory : null,
      negotiable: _negotiable,
      brand: isEquip && _brand.text.trim().isNotEmpty
          ? _brand.text.trim()
          : null,
      model: isEquip && _model.text.trim().isNotEmpty
          ? _model.text.trim()
          : null,
      year: isEquip ? int.tryParse(_year.text.trim()) : null,
      rentPrice: isTransfer ? double.tryParse(_rentPrice.text.trim()) : null,
      transferPrice: isTransfer
          ? double.tryParse(_transferPrice.text.trim())
          : null,
      equipmentIncluded: isTransfer ? _equipmentIncluded : null,
      hasLicense: isTransfer ? _hasLicense : null,
      areaM2: isTransfer ? int.tryParse(_areaM2.text.trim()) : null,
      contactPhone: _contactPhone.text.trim().isEmpty
          ? null
          : _contactPhone.text.trim(),
      contactWhatsapp: _contactWhatsapp.text.trim().isEmpty
          ? null
          : _contactWhatsapp.text.trim(),
    );
    try {
      final saved = await repo.upsertListing(listing);
      // Photo uploads (only newly picked ones).
      for (var i = 0; i < _newPhotos.length; i++) {
        final p = _newPhotos[i];
        await repo.uploadListingImage(
          listingId: saved.id!,
          bytes: p.bytes,
          fileExtension: p.ext,
          sortOrder: i,
        );
      }
      ref.invalidate(activeMarketListingsProvider(null));
      ref.invalidate(myMarketListingsProvider);
      if (saved.id != null) {
        ref.invalidate(marketListingByIdProvider(saved.id!));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.marketListingSavedSnack)),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][MarketForm] publish error: $e');
      if (mounted) {
        setState(() => _error = AppStrings.marketListingErrorGeneric);
        _showSnack(AppStrings.marketListingErrorGeneric);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Location picker handlers ────────────────────────────────────

  Future<void> _openProvincePicker() async {
    final picked = await LocationPicker.showProvincePicker(
      context,
      initialCode: _selectedProvince?.code,
    );
    if (picked == null) return;
    setState(() {
      if (_selectedProvince?.code != picked.code) {
        // İl değişti → ilçe sıfırla.
        _selectedDistrict = null;
      }
      _selectedProvince = picked;
    });
  }

  Future<void> _openDistrictPicker() async {
    final province = _selectedProvince;
    if (province == null) return;
    final picked = await LocationPicker.showDistrictPicker(
      context,
      province: province,
      initialCode: _selectedDistrict?.code,
    );
    if (picked == null) return;
    setState(() => _selectedDistrict = picked);
  }

  void _clearProvince() {
    setState(() {
      _selectedProvince = null;
      _selectedDistrict = null;
    });
  }

  void _clearDistrict() {
    setState(() => _selectedDistrict = null);
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isEquip = _listingType == 'equipment_sale';
    final isTransfer = _listingType == 'bakery_transfer';
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              FirinNetHeader(
                title: widget.listingId == null
                    ? AppStrings.marketListingFormTitleNew
                    : AppStrings.marketListingFormTitleEdit,
                subtitle: AppStrings.marketListingFormSubtitle,
              ),
              const SizedBox(height: AppSpacing.s),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Photos ──
                    _SectionLabel(label: AppStrings.marketListingFieldPhotos),
                    _PhotosRow(
                      photos: _newPhotos,
                      max: _maxPhotos,
                      onPickGallery: () => _pickPhoto(ImageSource.gallery),
                      onPickCamera: () => _pickPhoto(ImageSource.camera),
                      onRemove: _removePickedPhoto,
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Listing type (controlled-vocabulary) ──
                    DropdownButtonFormField<String>(
                      initialValue: _listingType,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldListingType,
                      ),
                      items: MarketplaceTaxonomy.listingTypes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _listingType =
                            v ?? MarketplaceTaxonomy.defaultListingType,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Title ──
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldTitle,
                        hintText: AppStrings.marketListingFieldTitleHint,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.marketListingFieldTitleRequired
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Category (V1 backward) ──
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldCategory,
                      ),
                      items: AppStrings.marketCategoryLabels.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'diger'),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Equipment-only block ──
                    if (isEquip) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: _equipmentCategory,
                        decoration: const InputDecoration(
                          labelText:
                              AppStrings.marketListingFieldEquipmentCategory,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('—'),
                          ),
                          ...MarketplaceTaxonomy.equipmentCategories.entries
                              .map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              ),
                        ],
                        onChanged: (v) =>
                            setState(() => _equipmentCategory = v),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<String?>(
                        initialValue: _condition,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldCondition,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('—'),
                          ),
                          ...MarketplaceTaxonomy.conditions.entries.map(
                            (e) => DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brand,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldBrand,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: TextFormField(
                              controller: _model,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldModel,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldYear,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final y = int.tryParse(v.trim());
                          if (y == null || y < 1900 || y > 2100) {
                            return '1900–2100 arası bir yıl gir.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _price,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldPrice,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: TextFormField(
                              controller: _unit,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldUnit,
                                hintText: AppStrings.marketListingFieldUnitHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],

                    // ── Bakery transfer-only block ──
                    if (isTransfer) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _transferPrice,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    AppStrings.marketListingFieldTransferPrice,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: TextFormField(
                              controller: _rentPrice,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    AppStrings.marketListingFieldRentPrice,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _areaM2,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldAreaM2,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final a = int.tryParse(v.trim());
                          if (a == null || a <= 0) {
                            return 'Pozitif bir m² gir.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _TriSwitch(
                        title: AppStrings.marketListingFieldEquipmentIncluded,
                        value: _equipmentIncluded,
                        onChanged: (v) =>
                            setState(() => _equipmentIncluded = v),
                      ),
                      const SizedBox(height: 4),
                      _TriSwitch(
                        title: AppStrings.marketListingFieldHasLicense,
                        value: _hasLicense,
                        onChanged: (v) => setState(() => _hasLicense = v),
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],

                    // ── Location (controlled vocabulary picker) ──
                    Row(
                      children: [
                        Expanded(
                          child: LocationPickerField(
                            label: AppStrings.marketListingFieldCity,
                            value: _selectedProvince?.name,
                            hint: 'İl seç',
                            onTap: _openProvincePicker,
                            onClear: _selectedProvince == null
                                ? null
                                : _clearProvince,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: LocationPickerField(
                            label: AppStrings.marketListingFieldDistrict,
                            value: _selectedDistrict?.name,
                            hint: _selectedProvince == null
                                ? 'Önce il seç'
                                : 'İlçe seç',
                            enabled: _selectedProvince != null,
                            onTap: _openDistrictPicker,
                            onClear: _selectedDistrict == null
                                ? null
                                : _clearDistrict,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Description ──
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldDescription,
                        hintText: AppStrings.marketListingFieldDescriptionHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Negotiable ──
                    SwitchListTile(
                      value: _negotiable,
                      onChanged: (v) => setState(() => _negotiable = v),
                      title: const Text(
                        AppStrings.marketListingFieldNegotiable,
                      ),
                      activeThumbColor: AppColors.copper,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Currency (controlled-vocabulary) ──
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Para birimi',
                      ),
                      items: MarketplaceTaxonomy.currencies.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _currency =
                            v ?? MarketplaceTaxonomy.defaultCurrency,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // ── Contact ──
                    _SectionLabel(label: 'İletişim'),
                    DropdownButtonFormField<String>(
                      initialValue: _contactPreference,
                      decoration: const InputDecoration(
                        labelText: 'Tercih edilen iletişim',
                      ),
                      items: MarketplaceTaxonomy.contactPreferences.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _contactPreference =
                            v ?? MarketplaceTaxonomy.defaultContactPreference,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _contactPhone,
                      keyboardType: TextInputType.phone,
                      enabled:
                          _contactPreference !=
                          MarketplaceTaxonomy.contactPreferenceInApp,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldContactPhone,
                        hintText: '+90 …',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _contactWhatsapp,
                      keyboardType: TextInputType.phone,
                      enabled:
                          _contactPreference !=
                          MarketplaceTaxonomy.contactPreferenceInApp,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldContactWhatsapp,
                        hintText: '+90 …',
                      ),
                    ),

                    // ── (Edit only) Status ──
                    if (widget.listingId != null) ...[
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Durum'),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: 'paused',
                            child: Text('Duraklatıldı'),
                          ),
                          DropdownMenuItem(
                            value: 'sold',
                            child: Text('Satıldı/Devredildi'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'active'),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.m,
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _onPublishPressed,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(AppColors.brandInk),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _saving
                    ? AppStrings.marketListingPublishingCta
                    : AppStrings.marketListingPublishCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copper,
                foregroundColor: AppColors.brandInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m, bottom: AppSpacing.s),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 14.5,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _PhotosRow extends StatelessWidget {
  const _PhotosRow({
    required this.photos,
    required this.max,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
  });

  final List<_PickedPhoto> photos;
  final int max;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                _PhotoThumb(
                  bytes: photos[i].bytes,
                  onRemove: () => onRemove(i),
                ),
                const SizedBox(width: 8),
              ],
              if (photos.length < max) ...[
                _PhotoAddButton(
                  icon: Icons.photo_library_outlined,
                  label: AppStrings.marketListingPickPhotoCta,
                  onTap: onPickGallery,
                ),
                const SizedBox(width: 8),
                _PhotoAddButton(
                  icon: Icons.camera_alt_outlined,
                  label: AppStrings.marketListingCapturePhotoCta,
                  onTap: onPickCamera,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.marketListingPhotoMaxHint,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.s),
          child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: Material(
            // P0 hijyen — hardcoded siyah yerine palet scrim token'ı.
            color: AppColors.imageScrimDark,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.surface,
                  size: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoAddButton extends StatelessWidget {
  const _PhotoAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        width: 96,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.m),
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.copper),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TriSwitch extends StatelessWidget {
  const _TriSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool? value;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: -1, label: Text('—')),
            ButtonSegment(value: 1, label: Text('Evet')),
            ButtonSegment(value: 0, label: Text('Hayır')),
          ],
          selected: {value == null ? -1 : (value! ? 1 : 0)},
          onSelectionChanged: (s) {
            final v = s.first;
            onChanged(v == -1 ? null : (v == 1));
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
