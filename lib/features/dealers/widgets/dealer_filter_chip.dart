import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Bayi Defteri + Jobs ortak filter / segment chip (Polish Sprint 1).
///
/// Daha önce 4 ekranda 3 farklı görsel pattern vardı (List default
/// `ChoiceChip` ↔ Reports/Offer custom themed). Burada Reports/Offer
/// paterni standart kabul edildi — copper border + softGold label
/// vurgusu, FırınNet'in sıcak premium çizgisine uygun.
///
/// `selected=true` → copper border 1.2 + copper.alpha(0.18) bg +
/// softGold w800 label.
/// `selected=false` → hairline border 0.6 + card bg + textSecondary
/// w600 label.
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.copper.withValues(alpha: 0.18),
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected ? AppColors.copper : AppColors.borderHairline,
        width: selected ? 1.2 : 0.6,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.softGold : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
