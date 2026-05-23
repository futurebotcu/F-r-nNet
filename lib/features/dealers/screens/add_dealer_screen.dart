import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/turkey_locations.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

class AddDealerScreen extends ConsumerStatefulWidget {
  const AddDealerScreen({
    super.key,
    this.customerType = DealerCustomerType.bakeryDealer,
  });

  /// Bayi mi (ticari) yoksa toptan müşteri mi (toptancı). UI etiketleri ve
  /// kaydedilen `customer_type` sütunu bu değerden türetilir.
  final DealerCustomerType customerType;

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

  /// M6B — eski `_area` TextField yerine il + ilçe picker.
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
    final now = DateTime.now();
    // M6B — dual-write: label + code.
    final province = _selectedProvince;
    final district = _selectedDistrict;
    try {
      await repo.upsertDealer(
        Dealer(
          id: 'd_${now.microsecondsSinceEpoch}',
          name: _name.text.trim(),
          contactName: _contact.text.trim(),
          phone: _phone.text.trim(),
          area: district?.name ?? '',
          city: province?.name ?? '',
          cityCode: province?.code,
          districtCode: district?.code,
          workingType: _wt,
          note: _note.text.trim(),
          customerType: widget.customerType,
          createdAt: now,
        ),
      );
    } catch (e) {
      // V1.3.5 — Supabase/network/validator hatasını kullanıcıya göster.
      // (Önceden unhandled exception düşüyor, kullanıcı boşta kalıyordu.)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bayi kaydedilemedi. Lütfen tekrar deneyin.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    final what = widget.customerType == DealerCustomerType.wholesaleCustomer
        ? 'Müşteri eklendi: '
        : AppStrings.dealerSaveSnack;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what${_name.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.customerType == DealerCustomerType.wholesaleCustomer
        ? 'Müşteri Ekle'
        : AppStrings.dealerAddTitle;
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldArea),
              const SizedBox(height: 6),
              // M6B — il + ilçe picker (eski free-text `_area` kaldırıldı).
              Row(
                children: [
                  Expanded(
                    child: LocationPickerField(
                      label: 'İl',
                      value: _selectedProvince?.name,
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
                      label: 'İlçe',
                      value: _selectedDistrict?.name,
                      enabled: _selectedProvince != null,
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
                          : () => setState(() => _selectedDistrict = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.dealerFieldWorkingType),
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
                label: AppStrings.dealerSaveButton,
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
