import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../models/partner_business.dart';
import '../models/partner_business_application.dart';
import '../providers/partner_business_providers.dart';

/// "Anlaşmalı iş yeri olmak istiyorum" başvuru formu.
///
/// Zorunlu alan validasyonu client'ta UX içindir (asıl denetim RPC'de).
/// Çift-submit guard'lı; DB kaydı başarılıysa mail durumundan BAĞIMSIZ
/// başarı gösterilir (mail best-effort — repo yutar). DB hatasında form
/// açık kalır, hata + tekrar dene gösterilir.
class PartnerApplicationForm extends ConsumerStatefulWidget {
  const PartnerApplicationForm({super.key, this.onSubmitted});

  /// Başarılı başvuru sonrası (örn. ekranı kapatma) callback'i.
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<PartnerApplicationForm> createState() =>
      _PartnerApplicationFormState();
}

class _PartnerApplicationFormState
    extends ConsumerState<PartnerApplicationForm> {
  final _businessName = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _message = TextEditingController();
  String? _category;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _businessName.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _district.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final draft = PartnerBusinessApplicationDraft(
      businessName: _businessName.text,
      contactName: _contactName.text,
      phone: _phone.text,
      city: _city.text,
      district: _district.text,
      category: _category ?? '',
      email: _email.text,
      message: _message.text,
    );
    if (!draft.isValid) {
      setState(() => _error = AppStrings.partnersApplyRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(partnerBusinessRepositoryProvider)
          .submitApplication(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.partnersApplySuccess)),
      );
      widget.onSubmitted?.call();
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppStrings.partnersApplyError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          keyName: 'partner_apply_business',
          controller: _businessName,
          label: AppStrings.partnersApplyBusinessName,
        ),
        _Field(
          keyName: 'partner_apply_contact',
          controller: _contactName,
          label: AppStrings.partnersApplyContactName,
        ),
        _Field(
          keyName: 'partner_apply_phone',
          controller: _phone,
          label: AppStrings.partnersApplyPhone,
          keyboardType: TextInputType.phone,
        ),
        _Field(
          keyName: 'partner_apply_email',
          controller: _email,
          label: AppStrings.partnersApplyEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        Row(
          children: [
            Expanded(
              child: _Field(
                keyName: 'partner_apply_city',
                controller: _city,
                label: AppStrings.partnersApplyCity,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: _Field(
                keyName: 'partner_apply_district',
                controller: _district,
                label: AppStrings.partnersApplyDistrict,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          AppStrings.partnersApplyCategory,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in kPartnerApplicationCategories)
              ChoiceChip(
                key: ValueKey('partner_category_$c'),
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.brandLemonPale,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        _Field(
          keyName: 'partner_apply_message',
          controller: _message,
          label: AppStrings.partnersApplyMessage,
          maxLines: 3,
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        FilledButton(
          key: const ValueKey('partner_apply_submit'),
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandLemon,
            foregroundColor: AppColors.brandInk,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          child: Text(
            _saving
                ? AppStrings.partnersApplySubmitting
                : AppStrings.partnersApplySubmit,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.keyName,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String keyName;
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextField(
        key: ValueKey(keyName),
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
