// B2B Pazar — sade arama alanı (ürün pazarı için).
//
// Mevcut nötr yüzey + token diliyle uyumlu; yeni tasarım dili icat etmez.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class B2bSearchField extends StatelessWidget {
  const B2bSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
            borderSide: const BorderSide(
              color: AppColors.borderHairline,
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
            borderSide: const BorderSide(
              color: AppColors.brandLemonPressed,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
