import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
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
  final _roleTitle = TextEditingController();
  final _description = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _shiftType = TextEditingController();
  final _experience = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  bool _loaded = false;

  /// M6B — il + ilçe picker (eski city/district TextField'lar kaldırıldı).
  TurkeyProvince? _selectedProvince;
  TurkeyDistrict? _selectedDistrict;

  @override
  void initState() {
    super.initState();
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
    _roleTitle.text = p.roleTitle;
    // M6B — code öncelikli; yoksa legacy text label'dan çevir.
    _selectedProvince = TurkeyLocations.findProvinceByCode(p.cityCode) ??
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
    _shiftType.text = p.shiftType ?? '';
    _experience.text = p.experienceRequired ?? '';
    _isActive = p.isActive;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _roleTitle.dispose();
    _description.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _shiftType.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(jobOfferRepositoryProvider);
    // M6B — dual-write: label + code.
    final province = _selectedProvince;
    final district = _selectedDistrict;
    final post = JobOfferPost(
      id: widget.postId,
      title: _title.text.trim(),
      roleTitle: _roleTitle.text.trim(),
      city: province?.name,
      district: district?.name,
      cityCode: province?.code,
      districtCode: district?.code,
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      salaryMin: double.tryParse(_salaryMin.text.trim()),
      salaryMax: double.tryParse(_salaryMax.text.trim()),
      shiftType:
          _shiftType.text.trim().isEmpty ? null : _shiftType.text.trim(),
      experienceRequired:
          _experience.text.trim().isEmpty ? null : _experience.text.trim(),
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
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldTitle,
                        hintText: AppStrings.jobOfferFieldTitleHint,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? AppStrings.jobOfferFieldTitleRequired
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _roleTitle,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldRole,
                        hintText: AppStrings.jobOfferFieldRoleHint,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? AppStrings.jobOfferFieldRoleRequired
                              : null,
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
                                : () => setState(
                                    () => _selectedDistrict = null),
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
                    TextFormField(
                      controller: _shiftType,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldShift,
                        hintText: AppStrings.jobOfferFieldShiftHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _experience,
                      decoration: const InputDecoration(
                        labelText: AppStrings.jobOfferFieldExperience,
                        hintText: AppStrings.jobOfferFieldExperienceHint,
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
                      subtitle: const Text(AppStrings.jobOfferFieldIsActiveHint),
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
                        label: const Text(AppStrings.jobOfferFormSaveCta),
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
