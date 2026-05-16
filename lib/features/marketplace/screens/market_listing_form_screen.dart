import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/market_listing.dart';
import '../providers/market_listing_providers.dart';

/// V1 — Market ilan formu (yeni / düzenle).
class MarketListingFormScreen extends ConsumerStatefulWidget {
  const MarketListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<MarketListingFormScreen> createState() =>
      _MarketListingFormScreenState();
}

class _MarketListingFormScreenState
    extends ConsumerState<MarketListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController();
  String _category = 'ekipman';
  String _listingType = 'product';
  String? _condition;
  bool _isActive = true;
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
    _city.text = m.city ?? '';
    _district.text = m.district ?? '';
    _price.text = m.price?.toStringAsFixed(0) ?? '';
    _unit.text = m.unit ?? '';
    _category = m.category;
    _listingType = m.listingType;
    _condition = m.condition;
    _isActive = m.isActive;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _city.dispose();
    _district.dispose();
    _price.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(marketListingRepositoryProvider);
    final listing = MarketListing(
      id: widget.listingId,
      title: _title.text.trim(),
      category: _category,
      listingType: _listingType,
      condition: _condition,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      district: _district.text.trim().isEmpty ? null : _district.text.trim(),
      price: double.tryParse(_price.text.trim()),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      isActive: _isActive,
    );
    try {
      await repo.upsertListing(listing);
      ref.invalidate(activeMarketListingsProvider(null));
      ref.invalidate(myMarketListingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.marketListingSavedSnack)),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.marketListingErrorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const PremiumScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldCategory,
                      ),
                      items: AppStrings.marketCategoryLabels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'diger'),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    DropdownButtonFormField<String>(
                      initialValue: _listingType,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldListingType,
                      ),
                      items: AppStrings.marketListingTypeLabels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _listingType = v ?? 'product'),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    DropdownButtonFormField<String?>(
                      initialValue: _condition,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldCondition,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        ...AppStrings.marketConditionLabels.entries.map(
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
                            controller: _city,
                            decoration: const InputDecoration(
                              labelText: AppStrings.marketListingFieldCity,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: TextFormField(
                            controller: _district,
                            decoration: const InputDecoration(
                              labelText: AppStrings.marketListingFieldDistrict,
                            ),
                          ),
                        ),
                      ],
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
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: AppStrings.marketListingFieldDescription,
                        hintText:
                            AppStrings.marketListingFieldDescriptionHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      title: const Text(AppStrings.marketListingFieldIsActive),
                      subtitle: const Text(
                          AppStrings.marketListingFieldIsActiveHint),
                      activeColor: AppColors.copper,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _onSavePressed,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)))
                            : const Icon(Icons.send_rounded, size: 18),
                        label:
                            const Text(AppStrings.marketListingFormSaveCta),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.copper,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
