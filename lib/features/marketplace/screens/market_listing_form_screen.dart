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
//   * Sticky bottom Publish CTA (Scaffold.bottomNavigationBar →
//     ListingStickyBar: SafeArea + klavye üstünde kalır).
//   * Photos post-create upload (storage rollback repository tarafında).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/permissions/app_permission_service.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/dirty_form_guard.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/interactions.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../listings/utils/listing_format.dart';
import '../../listings/widgets/listing_ui.dart';
import '../../subscriptions/models/listing_fee.dart';
import '../../subscriptions/widgets/listing_fee_notice.dart';
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
  const MarketListingFormScreen({
    super.key,
    this.listingId,
    this.initialListingType,
  });

  final String? listingId;

  /// Yeni ilanda önceden seçili tip ('bakery_transfer' / 'equipment_sale').
  /// Verilmezse route'un `?type=` sorgu parametresi okunur (İlanlar
  /// segmentinden gelen "+").
  final String? initialListingType;

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

  /// V1 eski `category` kolonu (zorunlu wire alanı). Formda artık seçtirilmez;
  /// yeni ilanda tipten türetilir, düzenlemede tip değişmedikçe korunur.
  String? _loadedCategory;
  String? _loadedListingType;
  String _listingType = MarketplaceTaxonomy.defaultListingType;
  List<String> _existingPhotoUrls = const [];
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
  bool _loadFailed = false;
  // PR-UI-2 — kaydedilmemiş değişiklik koruması. `_hydrating` _loadExisting
  // sırasında Form.onChanged'in false-dirty üretmesini engeller.
  bool _dirty = false;
  bool _hydrating = false;
  void _markDirty() {
    if (_hydrating || _dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.listingId != null) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  bool _typeResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_typeResolved || widget.listingId != null) return;
    _typeResolved = true;
    var type = widget.initialListingType;
    if (type == null) {
      try {
        type = GoRouterState.of(context).uri.queryParameters['type'];
      } catch (_) {
        // Router dışında (test/doğrudan) açıldı → varsayılan tip.
      }
    }
    if (MarketplaceTaxonomy.isValidListingType(type)) _listingType = type!;
  }

  /// Eski V1 `category` değerini tipten türetir (wire sözleşmesi korunur).
  static String _categoryForType(String listingType) =>
      listingType == MarketplaceTaxonomy.listingTypeBakeryTransfer
      ? 'devren_firin'
      : 'ekipman';

  /// Bilinmeyen durum değeri dropdown'u çökertmesin → güvenli 'paused'.
  static const Set<String> _knownStatuses = {
    'active',
    'paused',
    'sold',
    'expired',
  };

  Future<void> _loadExisting() async {
    _hydrating = true;
    if (_loadFailed) setState(() => _loadFailed = false);
    final MarketListing? m;
    try {
      m = await ref
          .read(marketListingRepositoryProvider)
          .getListing(widget.listingId!);
    } catch (_) {
      // Ağ hatası: sonsuz yükleme yerine hata durumu + Tekrar dene / Geri.
      _hydrating = false;
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    if (!mounted) return;
    if (m == null) {
      _hydrating = false;
      setState(() => _loaded = true);
      return;
    }
    _title.text = m.title;
    _description.text = m.description ?? '';
    _price.text = ListingFormat.editText(m.price);
    _unit.text = m.unit ?? '';
    _brand.text = m.brand ?? '';
    _model.text = m.model ?? '';
    _year.text = m.year?.toString() ?? '';
    _rentPrice.text = m.rentPrice?.toStringAsFixed(0) ?? '';
    _transferPrice.text = m.transferPrice?.toStringAsFixed(0) ?? '';
    _existingPhotoUrls = m.mediaList
        .map((e) => e.publicUrl)
        .where((u) => u.isNotEmpty)
        .toList(growable: false);
    _areaM2.text = m.areaM2?.toString() ?? '';
    _contactPhone.text = m.contactPhone ?? '';
    _contactWhatsapp.text = m.contactWhatsapp ?? '';
    _loadedCategory = m.category;
    _listingType = MarketplaceTaxonomy.isValidListingType(m.listingType)
        ? m.listingType
        : MarketplaceTaxonomy.defaultListingType;
    _loadedListingType = _listingType;
    _condition = m.condition;
    _equipmentCategory = m.equipmentCategory;
    _contactPreference = m.contactPreference;
    _currency = MarketplaceTaxonomy.isValidCurrency(m.currency)
        ? m.currency
        : MarketplaceTaxonomy.defaultCurrency;
    _negotiable = m.negotiable;
    _equipmentIncluded = m.equipmentIncluded;
    _hasLicense = m.hasLicense;
    _status = _knownStatuses.contains(m.status) ? m.status : 'paused';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hydrating = false;
    });
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
    // Kamera ÇEKİMİ → izin iste (galeri seçimi istemez).
    if (source == ImageSource.camera &&
        !await AppPermissionService.requestCameraForCapture(context)) {
      return;
    }
    if (!mounted) return;
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
        _dirty = true;
      });
    } catch (e) {
      debugPrint('[FirinNet][MarketForm] pickPhoto error: $e');
      if (mounted) {
        AppFeedback.error(context, AppStrings.listingsPhotoPickError);
      }
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
    setState(() {
      _newPhotos.removeAt(index);
      _dirty = true;
    });
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
    // Eski `category` kolonu: tip değişmediyse yüklenen değer korunur.
    final category =
        (_loadedCategory != null && _loadedListingType == _listingType)
        ? _loadedCategory!
        : _categoryForType(_listingType);
    final listing = MarketListing(
      id: widget.listingId,
      title: _title.text.trim(),
      category: category,
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
      price: isEquip ? ListingFormat.parseAmount(_price.text) : null,
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
      rentPrice: isTransfer ? ListingFormat.parseAmount(_rentPrice.text) : null,
      transferPrice: isTransfer
          ? ListingFormat.parseAmount(_transferPrice.text)
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
      AppHaptics.success();
      AppFeedback.success(
        context,
        listingSavedMessage(
          isEdit: widget.listingId != null,
          isPendingPayment: saved.isPendingPayment,
        ),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][MarketForm] publish error: $e');
      if (mounted) {
        setState(() => _error = AppStrings.marketListingErrorGeneric);
        AppFeedback.error(context, AppStrings.listingsSaveError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) => AppFeedback.info(context, msg);

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
      _dirty = true;
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
    setState(() {
      _selectedDistrict = picked;
      _dirty = true;
    });
  }

  void _clearProvince() {
    setState(() {
      _selectedProvince = null;
      _selectedDistrict = null;
      _dirty = true;
    });
  }

  void _clearDistrict() {
    setState(() {
      _selectedDistrict = null;
      _dirty = true;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return PremiumScaffold(
        appBar: AppBar(),
        body: Center(
          child: ErrorRetryState(
            key: const ValueKey('market_form_load_error'),
            title: AppStrings.listingsDetailLoadError,
            onRetry: _loadExisting,
          ),
        ),
      );
    }
    if (!_loaded) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isEquip = _listingType == 'equipment_sale';
    final isTransfer = _listingType == 'bakery_transfer';
    // Polish 2 — bölümlü form: Temel bilgi / Fiyat / Detaylar / Konum /
    // Fotoğraf / İletişim (+ düzenlemede Yayın durumu). Sabit CTA klavye
    // açıkken de klavyenin üstünde kalır (ListingStickyBar).
    final scaffold = PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
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
                    // ── İlan Ücretlendirme V1 — ücret bilgilendirmesi ──
                    if (widget.listingId == null)
                      const ListingFeeNotice(kind: ListingKind.market),

                    // ── Temel bilgi ──
                    const ListingSectionHeader(
                      AppStrings.listingsSectionBasics,
                    ),
                    // Listing type (controlled-vocabulary)
                    DropdownButtonFormField<String>(
                      initialValue: _listingType,
                      isExpanded: true,
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
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldTitle,
                        hintText: AppStrings.marketListingFieldTitleHint,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.marketListingFieldTitleRequired
                          : null,
                    ),

                    // (V1 "Kategori" alanı kaldırıldı — ilan tipinden
                    // türetilir; bkz. _categoryForType.)
                    if (isEquip) ...[
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<String?>(
                        initialValue: _equipmentCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText:
                              AppStrings.marketListingFieldEquipmentCategory,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(AppStrings.listingsOptionNone),
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
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldCondition,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(AppStrings.listingsOptionNone),
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
                    ],

                    // ── Fiyat ──
                    const ListingSectionHeader(AppStrings.listingsSectionPrice),
                    if (isEquip)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              inputFormatters:
                                  ListingFormat.priceInputFormatters,
                              decoration: InputDecoration(
                                labelText:
                                    '${AppStrings.listingsMarketPriceLabel} '
                                    '(${ListingFormat.currencySymbol(_currency)})',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: TextFormField(
                              controller: _unit,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldUnit,
                                hintText: AppStrings.marketListingFieldUnitHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (isTransfer)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _transferPrice,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters:
                                  ListingFormat.integerInputFormatters,
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
                              textInputAction: TextInputAction.next,
                              inputFormatters:
                                  ListingFormat.integerInputFormatters,
                              decoration: const InputDecoration(
                                labelText:
                                    AppStrings.marketListingFieldRentPrice,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.m),
                    // Currency (controlled-vocabulary)
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      isExpanded: true,
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
                    SwitchListTile(
                      value: _negotiable,
                      onChanged: (v) => setState(() {
                        _negotiable = v;
                        _dirty = true;
                      }),
                      title: Text(
                        AppStrings.marketListingFieldNegotiable,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      activeThumbColor: AppColors.brandInk,
                      activeTrackColor: AppColors.brandLemon,
                      contentPadding: EdgeInsets.zero,
                    ),

                    // ── Detaylar ──
                    const ListingSectionHeader(
                      AppStrings.listingsSectionDetails,
                    ),
                    if (isEquip) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brand,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: AppStrings.marketListingFieldBrand,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: TextFormField(
                              controller: _model,
                              textInputAction: TextInputAction.next,
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
                        textInputAction: TextInputAction.next,
                        inputFormatters: ListingFormat.integerInputFormatters,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldYear,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final y = int.tryParse(v.trim());
                          if (y == null || y < 1900 || y > 2100) {
                            return AppStrings.listingsYearInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    if (isTransfer) ...[
                      TextFormField(
                        controller: _areaM2,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: ListingFormat.integerInputFormatters,
                        decoration: const InputDecoration(
                          labelText: AppStrings.marketListingFieldAreaM2,
                          suffixText: 'm²',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final a = int.tryParse(v.trim());
                          if (a == null || a <= 0) {
                            return AppStrings.listingsAreaInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _TriSwitch(
                        title: AppStrings.marketListingFieldEquipmentIncluded,
                        value: _equipmentIncluded,
                        onChanged: (v) => setState(() {
                          _equipmentIncluded = v;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _TriSwitch(
                        title: AppStrings.marketListingFieldHasLicense,
                        value: _hasLicense,
                        onChanged: (v) => setState(() {
                          _hasLicense = v;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldDescription,
                        hintText: AppStrings.marketListingFieldDescriptionHint,
                        alignLabelWithHint: true,
                      ),
                    ),

                    // ── Konum (controlled vocabulary picker) ──
                    const ListingSectionHeader(
                      AppStrings.listingsSectionLocation,
                    ),
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

                    // ── Fotoğraf ──
                    const ListingSectionHeader(
                      AppStrings.listingsSectionPhotos,
                    ),
                    // Düzenlemede mevcut fotoğraflar (salt-okunur önizleme).
                    if (_existingPhotoUrls.isNotEmpty) ...[
                      _ExistingPhotosRow(urls: _existingPhotoUrls),
                      const SizedBox(height: AppSpacing.s),
                    ],
                    _PhotosRow(
                      photos: _newPhotos,
                      max: _maxPhotos,
                      onPickGallery: () => _pickPhoto(ImageSource.gallery),
                      onPickCamera: () => _pickPhoto(ImageSource.camera),
                      onRemove: _removePickedPhoto,
                    ),

                    // ── İletişim ──
                    const ListingSectionHeader(
                      AppStrings.listingsSectionContact,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _contactPreference,
                      isExpanded: true,
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
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.done,
                      enabled:
                          _contactPreference !=
                          MarketplaceTaxonomy.contactPreferenceInApp,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldContactWhatsapp,
                        hintText: '+90 …',
                      ),
                    ),

                    // ── (Edit only) Yayın durumu ──
                    if (widget.listingId != null) ...[
                      const ListingSectionHeader(
                        AppStrings.listingsSectionPublish,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        isExpanded: true,
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
                          DropdownMenuItem(
                            value: 'expired',
                            child: Text(AppStrings.listingsStatusExpired),
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
                        style: AppTypography.body.copyWith(
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
      bottomNavigationBar: ListingStickyBar(
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('market_form_submit'),
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
              widget.listingId != null
                  ? (_saving
                        ? AppStrings.listingsUpdatingCta
                        : AppStrings.listingsUpdateCta)
                  : (_saving
                        ? AppStrings.marketListingPublishingCta
                        : AppStrings.marketListingPublishCta),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandLemon,
              foregroundColor: AppColors.brandInk,
              textStyle: AppTypography.buttonLabel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
            ),
          ),
        ),
      ),
    );
    return DirtyFormGuard(isDirty: _dirty, child: scaffold);
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
        const SizedBox(height: 6),
        Text(
          AppStrings.marketListingPhotoMaxHint,
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

/// Düzenlemede mevcut ilan fotoğrafları — salt-okunur küçük önizleme
/// (silme backend değişikliği gerektirdiği için bu geçişte yok).
class _ExistingPhotosRow extends StatelessWidget {
  const _ExistingPhotosRow({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.listingsExistingPhotos, style: AppTypography.infoLabel),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView.separated(
            key: const ValueKey('market_form_existing_photos'),
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            // Polish 2 — ortak görsel durumları (kırık görsel ikonu yok).
            itemBuilder: (_, i) => AppNetworkImage(
              url: urls[i],
              width: 64,
              height: 64,
              memCacheWidth: 192,
              compact: true,
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
          ),
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
        // Polish 2 — 44px dokunma alanı; görsel daire küçük kalır.
        Positioned(
          right: 0,
          top: 0,
          child: Tooltip(
            message: AppStrings.listingsRemovePhotoTooltip,
            child: Semantics(
              button: true,
              label: AppStrings.listingsRemovePhotoTooltip,
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('market_form_remove_photo'),
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        // P0 hijyen — palet scrim token'ı.
                        color: AppColors.imageScrimDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.surface,
                        size: 14,
                      ),
                    ),
                  ),
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
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.chipLabel.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    // Polish 2 — başlık üstte, seçim tam genişlikte (dar ekranda taşmaz;
    // "—" yerine anlaşılır "Seçilmedi").
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTypography.infoLabel),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: -1,
              label: Text(AppStrings.listingsOptionNone, maxLines: 1),
            ),
            ButtonSegment(
              value: 1,
              label: Text(AppStrings.marketAttrYes, maxLines: 1),
            ),
            ButtonSegment(
              value: 0,
              label: Text(AppStrings.marketAttrNo, maxLines: 1),
            ),
          ],
          selected: {value == null ? -1 : (value! ? 1 : 0)},
          onSelectionChanged: (s) {
            final v = s.first;
            onChanged(v == -1 ? null : (v == 1));
          },
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(AppTypography.chipLabel),
          ),
        ),
      ],
    );
  }
}
