import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/interactions.dart';

/// Bayi Defteri + Jobs ortak filter / segment chip (Polish Sprint 1).
///
/// Daha önce 4 ekranda 3 farklı görsel pattern vardı; burada tek chip dili
/// kullanılır: beyaz yüzey, 16 px radius ve seçili durumda primary vurgu.
class DealerFilterChip extends StatelessWidget {
  const DealerFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;

  /// `null` ise chip disabled (form saving gibi durumlarda kullanılır).
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: null,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: selected ? AppColors.softGold : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
    );
  }
}
