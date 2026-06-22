// B2B Pazar — mağaza yönetim formları için ortak alan widget'ları.
//
// Mevcut FırınNet token diliyle uyumlu; yeni tasarım dili icat etmez.
// Dashboard/panel havası vermez — sade, mobil-first form alanları.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Etiketli metin alanı (validate destekli).
class B2bTextField extends StatelessWidget {
  const B2bTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          textInputAction: textInputAction,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            enabledBorder: _border(AppColors.borderHairline, 0.8),
            focusedBorder: _border(AppColors.brandLemonPressed, 1.2),
            errorBorder: _border(AppColors.danger, 0.8),
            focusedErrorBorder: _border(AppColors.danger, 1.2),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: BorderSide(color: c, width: w),
      );
}

/// Etiketli tarih seçici alanı (opsiyonel — boş = "Süresiz"). Serbest metin
/// yerine DatePicker kullanılır (FN-AUDIT-006: serbest metin sessizce kaybolup
/// kampanya "süresiz" oluyordu).
class B2bDateField extends StatelessWidget {
  const B2bDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.placeholder = 'Süresiz (belirtilmedi)',
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String placeholder;

  static String formatTr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final has = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    has ? formatTr(value!) : placeholder,
                    style: TextStyle(
                      fontSize: 14,
                      color: has ? AppColors.textPrimary : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (has)
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Yayında / Taslak durum seçici (kompakt segmented).
class B2bStatusField extends StatelessWidget {
  const B2bStatusField({
    super.key,
    required this.published,
    required this.onChanged,
  });

  final bool published;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Durum'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderHairline, width: 0.8),
          ),
          child: Row(
            children: [
              _seg('Yayında', published, () => onChanged(true)),
              _seg('Taslak', !published, () => onChanged(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLemon : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.brandInk : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek seçimli chip alanı (ör. kategori — zorunlu). [errorText] doluysa
/// altında kırmızı hata gösterir.
class B2bSingleSelectChips extends StatelessWidget {
  const B2bSingleSelectChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.errorText,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              _SelectChip(
                label: o,
                selected: selected == o,
                onTap: () => onSelect(o),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Çok seçimli chip alanı (ör. hizmet bölgeleri, kategoriler).
class B2bMultiSelectChips extends StatelessWidget {
  const B2bMultiSelectChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              _SelectChip(
                label: o,
                selected: selected.contains(o),
                onTap: () => onToggle(o),
              ),
          ],
        ),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLemon : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: selected ? AppColors.brandLemonPressed : AppColors.borderHairline,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.brandInk : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Form altında tam-genişlik birincil kaydet butonu (sarı vurgu).
class B2bSaveButton extends StatelessWidget {
  const B2bSaveButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandLemon,
          foregroundColor: AppColors.brandInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}
