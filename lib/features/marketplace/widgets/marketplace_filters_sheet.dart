// FırınNet Market V1 M2 — Filter bottom sheet (controlled-data).
//
// Donor pattern: Bagisto `filter_bottom_sheet.dart` (Filters title + clear
// all + apply CTA). V1 Market M2 controlled-data fix: il/ilçe LocationPicker
// üzerinden seçilir, serbest TextField yok. Listing_type, ekipman kategorisi,
// durum tek bir taxonomy'den beslenir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../data/marketplace_taxonomy.dart';
import '../models/market_filters.dart';
import '../../../core/widgets/location_picker.dart';

class MarketplaceFiltersSheet extends StatefulWidget {
  const MarketplaceFiltersSheet({
    super.key,
    required this.initial,
  });

  final MarketFilters initial;

  static Future<MarketFilters?> show(
    BuildContext context, {
    required MarketFilters initial,
  }) {
    return showModalBottomSheet<MarketFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (_) => MarketplaceFiltersSheet(initial: initial),
    );
  }

  @override
  State<MarketplaceFiltersSheet> createState() =>
      _MarketplaceFiltersSheetState();
}

class _MarketplaceFiltersSheetState extends State<MarketplaceFiltersSheet> {
  late MarketFilters _f;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  TurkeyProvince? _province;
  TurkeyDistrict? _district;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    if (_f.minPrice != null) _minCtrl.text = _f.minPrice!.toStringAsFixed(0);
    if (_f.maxPrice != null) _maxCtrl.text = _f.maxPrice!.toStringAsFixed(0);
    _province = TurkeyLocations.findProvinceByCode(_f.cityCode);
    if (_province != null) {
      _district = TurkeyLocations.findDistrict(
        _province!.code,
        _f.districtCode,
      );
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final minP = double.tryParse(_minCtrl.text.trim());
    final maxP = double.tryParse(_maxCtrl.text.trim());
    Navigator.of(context).pop(
      _f.copyWith(
        minPrice: minP,
        clearMinPrice: minP == null,
        maxPrice: maxP,
        clearMaxPrice: maxP == null,
        cityCode: _province?.code,
        city: _province?.name,
        clearCity: _province == null,
        districtCode: _district?.code,
        district: _district?.name,
        clearDistrict: _district == null,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _f = const MarketFilters();
      _minCtrl.clear();
      _maxCtrl.clear();
      _province = null;
      _district = null;
    });
  }

  Future<void> _openProvincePicker() async {
    final picked = await LocationPicker.showProvincePicker(
      context,
      initialCode: _province?.code,
    );
    if (picked == null) return;
    setState(() {
      if (_province?.code != picked.code) _district = null;
      _province = picked;
    });
  }

  Future<void> _openDistrictPicker() async {
    final p = _province;
    if (p == null) return;
    final picked = await LocationPicker.showDistrictPicker(
      context,
      province: p,
      initialCode: _district?.code,
    );
    if (picked == null) return;
    setState(() => _district = picked);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SizedBox(
          height: mq.size.height * 0.85,
          child: Column(
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.s,
                  AppSpacing.s,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        AppStrings.marketFilterTitle,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        AppStrings.marketFilterClearAll,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                  height: 1, thickness: 0.6, color: AppColors.borderHairline),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.m,
                  ),
                  children: [
                    _SectionLabel(label: AppStrings.marketFilterListingType),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          label: 'Tümü',
                          selected: _f.listingType == null,
                          onTap: () => setState(
                              () => _f = _f.copyWith(clearListingType: true)),
                        ),
                        for (final e in MarketplaceTaxonomy.listingTypes.entries)
                          _Chip(
                            label: e.value,
                            selected: _f.listingType == e.key,
                            onTap: () => setState(
                                () => _f = _f.copyWith(listingType: e.key)),
                          ),
                      ],
                    ),
                    if (_f.listingType ==
                        MarketplaceTaxonomy.listingTypeEquipmentSale) ...[
                      const SizedBox(height: AppSpacing.l),
                      _SectionLabel(
                        label: AppStrings.marketFilterEquipmentCategory,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            label: 'Tümü',
                            selected: _f.equipmentCategory == null,
                            onTap: () => setState(
                              () => _f =
                                  _f.copyWith(clearEquipmentCategory: true),
                            ),
                          ),
                          for (final e in MarketplaceTaxonomy.equipmentCategories.entries)
                            _Chip(
                              label: e.value,
                              selected: _f.equipmentCategory == e.key,
                              onTap: () => setState(
                                () => _f =
                                    _f.copyWith(equipmentCategory: e.key),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.l),
                    _SectionLabel(label: AppStrings.marketFilterCity),
                    Row(
                      children: [
                        Expanded(
                          child: LocationPickerField(
                            label: 'İl',
                            value: _province?.name,
                            hint: 'İl seç',
                            onTap: _openProvincePicker,
                            onClear: _province == null
                                ? null
                                : () => setState(() {
                                      _province = null;
                                      _district = null;
                                    }),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: LocationPickerField(
                            label: 'İlçe',
                            value: _district?.name,
                            hint: _province == null
                                ? 'Önce il seç'
                                : 'İlçe seç',
                            enabled: _province != null,
                            onTap: _openDistrictPicker,
                            onClear: _district == null
                                ? null
                                : () => setState(() => _district = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _SectionLabel(label: AppStrings.marketFilterPriceRange),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: AppStrings.marketFilterMinPrice,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: TextField(
                            controller: _maxCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: AppStrings.marketFilterMaxPrice,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _SectionLabel(label: AppStrings.marketFilterCondition),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          label: 'Tümü',
                          selected: _f.condition == null,
                          onTap: () => setState(
                              () => _f = _f.copyWith(clearCondition: true)),
                        ),
                        for (final e
                            in MarketplaceTaxonomy.conditions.entries)
                          _Chip(
                            label: e.value,
                            selected: _f.condition == e.key,
                            onTap: () => setState(
                                () => _f = _f.copyWith(condition: e.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _f.negotiableOnly,
                      onChanged: (v) =>
                          setState(() => _f = _f.copyWith(negotiableOnly: v)),
                      title: const Text(AppStrings.marketFilterNegotiable),
                      activeThumbColor: AppColors.copper,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
              const Divider(
                  height: 1, thickness: 0.6, color: AppColors.borderHairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.m,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.copper,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: Text(
                      _f.activeCount > 0
                          ? '${AppStrings.marketFilterApply} (${_f.activeCount})'
                          : AppStrings.marketFilterApply,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 14.5,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.softGold.withValues(alpha: 0.18)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(
              color: selected
                  ? AppColors.softGold
                  : AppColors.borderHairline,
              width: selected ? 1.0 : 0.6,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? AppColors.softGold : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
