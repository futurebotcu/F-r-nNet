import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../dealers/widgets/dealer_filter_chip.dart';
import '../../subscriptions/models/listing_fee.dart';
import '../../subscriptions/widgets/listing_fee_notice.dart';
import '../models/job_offer_post.dart';
import '../providers/job_offer_providers.dart';

/// V1 — "Usta Arıyor / İş Veriyorum" ilan formu.
///
/// Ticari + Toptancı rolündeki authenticated kullanıcılar yeni ilan açabilir.
/// `runGuardedMutation` ile guest write engellenir.
class JobOfferFormScreen extends ConsumerStatefulWidget {
  const JobOfferFormScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<JobOfferFormScreen> createState() => _JobOfferFormScreenState();
}

class _JobOfferFormScreenState extends ConsumerState<JobOfferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();

  /// Listing Contact Phone Sprint — opsiyonel telefon (doğrulama yok).
  final _contactPhone = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  bool _loaded = false;

  /// M6B — il + ilçe picker (eski city/district TextField'lar kaldırıldı).
  TurkeyProvince? _selectedProvince;
  TurkeyDistrict? _selectedDistrict;

  /// M8 — taxonomy code seçimleri. Eski role_title/shift_type/
  /// experience_required TextField'lar kaldırıldı.
  String? _roleCode;
  String? _shiftCode;
  String? _experienceCode;

  @override
  void initState() {
    super.initState();
    // M8 Cleanup P1-1: deep-link defansı — bireysel kullanıcı bu form'a
    // direkt route ile gelmiş olabilir (CTA katmanı atlanmış). Profile
    // bireyselse snackbar + post-frame pop; form hiç render edilmesin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(profileControllerProvider);
      if (profile != null &&
          profile.accountType != AccountType.commercial &&
          profile.accountType != AccountType.wholesaler) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.jobOfferCommercialOnly)),
        );
        if (context.canPop()) {
          context.pop();
        }
      }
    });
    if (widget.postId != null) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(jobOfferRepositoryProvider);
    final p = await repo.getOffer(widget.postId!);
    if (!mounted || p == null) {
      setState(() => _loaded = true);
      return;
    }
    _title.text = p.title;
    // M8 — role/shift/experience code öncelikli; yoksa legacy label'dan çevir.
    _roleCode =
        p.roleCode ?? FirinnetTaxonomy.professionCodeFromLabel(p.roleTitle);
    _shiftCode = p.shiftCode;
    if (_shiftCode == null && p.shiftType != null) {
      for (final e in FirinnetTaxonomy.shiftEntries) {
        if (e.value.toLowerCase() == p.shiftType!.trim().toLowerCase()) {
          _shiftCode = e.key;
          break;
        }
      }
    }
    _experienceCode = p.experienceCode;
    if (_experienceCode == null && p.experienceRequired != null) {
      for (final e in FirinnetTaxonomy.experienceEntries) {
        if (e.value.toLowerCase() ==
            p.experienceRequired!.trim().toLowerCase()) {
          _experienceCode = e.key;
          break;
        }
      }
    }
    // M6B — code öncelikli; yoksa legacy text label'dan çevir.
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(p.cityCode) ??
        TurkeyLocations.findProvinceByName(p.city);
    if (_selectedProvince != null) {
      _selectedDistrict = TurkeyLocations.findDistrict(
        _selectedProvince!.code,
        p.districtCode,
      );
    }
    _description.text = p.description ?? '';
    _salaryMin.text = p.salaryMin?.toStringAsFixed(0) ?? '';
    _salaryMax.text = p.salaryMax?.toStringAsFixed(0) ?? '';
    _contactPhone.text = p.contactPhone ?? '';
    _isActive = p.isActive;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  /// Telefon normalize: sadece boşlukları/tireleri temizle; aşırı validasyon
  /// yok. Boş string → null.
  static String? _normalizePhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-()]+'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.jobOfferFieldRoleRequired)),
      );
      return;
    }
    // M8 Cleanup P1-2: salary cross-field + negatif validation. Boş
    // bırakmak serbest; sadece girilmiş değerler kontrol edilir.
    final minSalary = double.tryParse(_salaryMin.text.trim());
    final maxSalary = double.tryParse(_salaryMax.text.trim());
    if ((minSalary != null && minSalary < 0) ||
        (maxSalary != null && maxSalary < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.jobOfferSalaryNegative)),
      );
      return;
    }
    if (minSalary != null && maxSalary != null && minSalary > maxSalary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.jobOfferSalaryMinGtMax)),
      );
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(jobOfferRepositoryProvider);
    // M6B — dual-write: label + code (location).
    final province = _selectedProvince;
    final district = _selectedDistrict;
    // M8 — dual-write: label + code (role/shift/experience).
    final roleLabel = FirinnetTaxonomy.professionLabel(_roleCode!) ?? '';
    final shiftLabel = FirinnetTaxonomy.shiftLabel(_shiftCode);
    final experienceLabel = FirinnetTaxonomy.experienceLabel(_experienceCode);
    final post = JobOfferPost(
      id: widget.postId,
      title: _title.text.trim(),
      roleTitle: roleLabel,
      roleCode: _roleCode,
      city: province?.name,
      district: district?.name,
      cityCode: province?.code,
      districtCode: district?.code,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      salaryMin: double.tryParse(_salaryMin.text.trim()),
      salaryMax: double.tryParse(_salaryMax.text.trim()),
      shiftType: shiftLabel,
      shiftCode: _shiftCode,
      experienceRequired: experienceLabel,
      experienceCode: _experienceCode,
      contactPhone: _normalizePhone(_contactPhone.text),
      isActive: _isActive,
    );
    try {
      await repo.upsertOffer(post);
      ref.invalidate(activeJobOffersProvider);
      ref.invalidate(myJobOffersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.jobOfferSavedSnack)),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.jobOfferErrorGeneric)),
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
                title: widget.postId == null
                    ? AppStrings.jobOfferFormTitleNew
                    : AppStrings.jobOfferFormTitleEdit,
                subtitle: AppStrings.jobOfferFormSubtitle,
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
                    if (widget.postId == null) ...[
                      const ListingFeeNotice(kind: ListingKind.jobOffer),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldTitle,
                        hintText: AppStrings.jobOfferFieldTitleHint,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.jobOfferFieldTitleRequired
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _CodeChipPicker(
                      label: AppStrings.jobOfferFieldRole,
                      entries: FirinnetTaxonomy.professionEntries,
                      selectedCode: _roleCode,
                      onChanged: _saving
                          ? null
                          : (code) => setState(() => _roleCode = code),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: LocationPickerField(
                            label: AppStrings.jobOfferFieldCity,
                            value: _selectedProvince?.name,
                            enabled: !_saving,
                            onTap: () async {
                              final picked =
                                  await LocationPicker.showProvincePicker(
                                    context,
                                    initialCode: _selectedProvince?.code,
                                  );
                              if (picked != null) {
                                setState(() {
                                  _selectedProvince = picked;
                                  _selectedDistrict = null;
                                });
                              }
                            },
                            onClear: _selectedProvince == null
                                ? null
                                : () => setState(() {
                                    _selectedProvince = null;
                                    _selectedDistrict = null;
                                  }),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: LocationPickerField(
                            label: AppStrings.jobOfferFieldDistrict,
                            value: _selectedDistrict?.name,
                            enabled: !_saving && _selectedProvince != null,
                            onTap: () async {
                              final province = _selectedProvince;
                              if (province == null) return;
                              final picked =
                                  await LocationPicker.showDistrictPicker(
                                    context,
                                    province: province,
                                    initialCode: _selectedDistrict?.code,
                                  );
                              if (picked != null) {
                                setState(() => _selectedDistrict = picked);
                              }
                            },
                            onClear: _selectedDistrict == null
                                ? null
                                : () =>
                                      setState(() => _selectedDistrict = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMin,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: AppStrings.jobOfferFieldSalaryMin,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMax,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: AppStrings.jobOfferFieldSalaryMax,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _CodeChipPicker(
                      label: AppStrings.jobOfferFieldShift,
                      entries: FirinnetTaxonomy.shiftEntries,
                      selectedCode: _shiftCode,
                      onChanged: _saving
                          ? null
                          : (code) => setState(() => _shiftCode = code),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _CodeChipPicker(
                      label: AppStrings.jobOfferFieldExperience,
                      entries: FirinnetTaxonomy.experienceEntries,
                      selectedCode: _experienceCode,
                      onChanged: _saving
                          ? null
                          : (code) => setState(() => _experienceCode = code),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _contactPhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: AppStrings.listingContactPhoneLabel,
                        hintText: AppStrings.listingContactPhoneHint,
                        helperText: AppStrings.listingContactPhoneHelper,
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldDescription,
                        hintText: AppStrings.jobOfferFieldDescriptionHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      title: const Text(AppStrings.jobOfferFieldIsActive),
                      subtitle: const Text(
                        AppStrings.jobOfferFieldIsActiveHint,
                      ),
                      activeThumbColor: AppColors.copper,
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
                                    AppColors.surface,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text(AppStrings.jobOfferFormSaveCta),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.copper,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// M8 — taxonomy code single-select chip cluster. Label üstte, chip'ler
/// altta. `onChanged(null)` toggle = seçimi kaldırır. Saving sırasında
/// disabled.
class _CodeChipPicker extends StatelessWidget {
  const _CodeChipPicker({
    required this.label,
    required this.entries,
    required this.selectedCode,
    required this.onChanged,
  });

  final String label;
  final Iterable<MapEntry<String, String>> entries;
  final String? selectedCode;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in entries)
              DealerFilterChip(
                label: e.value,
                selected: selectedCode == e.key,
                onSelected: onChanged == null
                    ? null
                    : (v) => onChanged!(v ? e.key : null),
              ),
          ],
        ),
      ],
    );
  }
}
