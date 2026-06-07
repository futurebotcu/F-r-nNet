import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

class AddDealerScreen extends ConsumerStatefulWidget {
  const AddDealerScreen({
    super.key,
    this.customerType = DealerCustomerType.bakeryDealer,
    this.dealerId,
  });

  /// Bayi mi (ticari) yoksa toptan mÃ¼ÅŸteri mi (toptancÄ±). UI etiketleri ve
  /// kaydedilen `customer_type` sÃ¼tunu bu deÄŸerden tÃ¼retilir.
  final DealerCustomerType customerType;
  final String? dealerId;

  @override
  ConsumerState<AddDealerScreen> createState() => _AddDealerScreenState();
}

class _AddDealerScreenState extends ConsumerState<AddDealerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  DealerWorkingType _wt = DealerWorkingType.mixed;
  Dealer? _editingDealer;
  String? _hydratedDealerId;

  /// M6B â€” eski `_area` TextField yerine il + ilÃ§e picker.
  TurkeyProvince? _selectedProvince;
  TurkeyDistrict? _selectedDistrict;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    final repo = ref.read(dealerRepositoryProvider);
    final editing = _editingDealer;
    final isEditing = editing != null;
    final now = DateTime.now();
    // M6B â€” dual-write: label + code.
    final province = _selectedProvince;
    final district = _selectedDistrict;
    try {
      await repo.upsertDealer(
        Dealer(
          id: editing?.id ?? 'd_${now.microsecondsSinceEpoch}',
          name: _name.text.trim(),
          contactName: _contact.text.trim(),
          phone: _phone.text.trim(),
          area: district?.name ?? '',
          city: province?.name ?? '',
          cityCode: province?.code,
          districtCode: district?.code,
          workingType: _wt,
          isActive: editing?.isActive ?? true,
          note: _note.text.trim(),
          customerType: editing?.customerType ?? widget.customerType,
          createdAt: editing?.createdAt ?? now,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? AppStrings.dealerUpdateError
                : AppStrings.dealerSaveError,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    final what = isEditing
        ? AppStrings.dealerUpdateSnack
        : widget.customerType == DealerCustomerType.wholesaleCustomer
        ? 'MÃ¼ÅŸteri eklendi: '
        : AppStrings.dealerSaveSnack;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what${_name.text.trim()}')));
  }

  String? _validatePhone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return AppStrings.dealerFieldPhoneInvalid;
    return null;
  }

  void _hydrateFromDealer(Dealer dealer) {
    if (_hydratedDealerId == dealer.id) return;
    _hydratedDealerId = dealer.id;
    _editingDealer = dealer;
    _name.text = dealer.name;
    _contact.text = dealer.contactName;
    _phone.text = dealer.phone;
    _note.text = dealer.note;
    _wt = dealer.workingType;
    _selectedProvince =
        TurkeyLocations.findProvinceByCode(dealer.cityCode) ??
        TurkeyLocations.findProvinceByName(dealer.city);
    _selectedDistrict = TurkeyLocations.findDistrict(
      _selectedProvince?.code,
      dealer.districtCode,
    );
    if (_selectedDistrict == null && dealer.area.isNotEmpty) {
      for (final district
          in _selectedProvince?.districts ?? const <TurkeyDistrict>[]) {
        if (district.name == dealer.area) {
          _selectedDistrict = district;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.dealerId != null;
    final title = isEditing
        ? AppStrings.dealerEditTitle
        : widget.customerType == DealerCustomerType.wholesaleCustomer
        ? 'MÃ¼ÅŸteri Ekle'
        : AppStrings.dealerAddTitle;
    final dealerId = widget.dealerId;
    if (dealerId != null) {
      final dealerAsync = ref.watch(dealerByIdProvider(dealerId));
      return dealerAsync.when(
        loading: () => PremiumScaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => PremiumScaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: _LoadError(
              onRetry: () => ref.invalidate(dealerByIdProvider(dealerId)),
            ),
          ),
        ),
        data: (dealer) {
          if (dealer == null) {
            return PremiumScaffold(
              appBar: AppBar(title: Text(title)),
              body: const Center(child: Text(AppStrings.dealerDetailNotFound)),
            );
          }
          _hydrateFromDealer(dealer);
          return _buildForm(context, title: title, isEditing: true);
        },
      );
    }

    return _buildForm(context, title: title, isEditing: false);
  }

  Widget _buildForm(
    BuildContext context, {
    required String title,
    required bool isEditing,
  }) {
    return PremiumScaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.xxl,
            ),
            children: [
              PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: const Text(
                  AppStrings.dealerFormIntro,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldName),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: AppStrings.dealerFieldNameHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? AppStrings.dealerFieldNameRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldContact),
              const SizedBox(height: 2),
              const _Helper(AppStrings.dealerFieldContactHelper),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contact,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: AppStrings.dealerFieldContactPerson,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: AppStrings.dealerFieldPhone,
                        helperText: AppStrings.dealerFieldPhoneHelper,
                      ),
                      validator: _validatePhone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldArea),
              const SizedBox(height: 2),
              const _Helper(AppStrings.dealerFieldAreaHelper),
              const SizedBox(height: 6),
              // M6B â€” il + ilÃ§e picker (eski free-text `_area` kaldÄ±rÄ±ldÄ±).
              Row(
                children: [
                  Expanded(
                    child: LocationPickerField(
                      label: 'Ä°l',
                      value: _selectedProvince?.name,
                      onTap: () async {
                        final picked = await LocationPicker.showProvincePicker(
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
                      label: 'Ä°lÃ§e',
                      value: _selectedDistrict?.name,
                      enabled: _selectedProvince != null,
                      onTap: () async {
                        final province = _selectedProvince;
                        if (province == null) return;
                        final picked = await LocationPicker.showDistrictPicker(
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
                          : () => setState(() => _selectedDistrict = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldWorkingType),
              const SizedBox(height: 2),
              const _Helper(AppStrings.dealerFieldWorkingTypeHelper),
              const SizedBox(height: 8),
              SegmentedButton<DealerWorkingType>(
                segments: const [
                  ButtonSegment(
                    value: DealerWorkingType.cash,
                    label: Text(AppStrings.dealerWorkingCash),
                    icon: Icon(Icons.payments_rounded),
                  ),
                  ButtonSegment(
                    value: DealerWorkingType.term,
                    label: Text(AppStrings.dealerWorkingTerm),
                    icon: Icon(Icons.event_note_rounded),
                  ),
                  ButtonSegment(
                    value: DealerWorkingType.mixed,
                    label: Text(AppStrings.dealerWorkingMixed),
                    icon: Icon(Icons.sync_alt_rounded),
                  ),
                ],
                selected: {_wt},
                onSelectionChanged: (s) => setState(() => _wt = s.first),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldNote),
              const SizedBox(height: 6),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: AppStrings.dealerFieldNoteHint,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: isEditing
                    ? AppStrings.dealerUpdateButton
                    : AppStrings.dealerSaveButton,
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Helper extends StatelessWidget {
  const _Helper(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
        height: 1.3,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            AppStrings.dealerDetailLoadError,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.m),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text(AppStrings.dealerRetry),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
      ),
    );
  }
}
