import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_number_field.dart';

/// Hesaplama alanlarında kullanılan kütle / hacim birimi.
enum MassUnit { kg, gr, l }

extension MassUnitLabel on MassUnit {
  String get label {
    switch (this) {
      case MassUnit.kg:
        return 'kg';
      case MassUnit.gr:
        return 'gr';
      case MassUnit.l:
        return 'L';
    }
  }
}

/// Birim değerini kg'a çevirir (1 L ≈ 1 kg kabulü).
double massToKg(double value, MassUnit unit) {
  switch (unit) {
    case MassUnit.kg:
    case MassUnit.l:
      return value;
    case MassUnit.gr:
      return value / 1000.0;
  }
}

/// Sayı alanı + birim seçici (pill toggle) satırı.
///
/// Hesaplama araçlarında tekrar kullanılır. Matematik içermez; yalnız
/// giriş + birim seçimini yönetir, kg dönüşümünü [massToKg] sağlar.
class CalculatorQuantityRow extends StatelessWidget {
  const CalculatorQuantityRow({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
    required this.units,
    required this.onUnitChanged,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final MassUnit unit;
  final List<MassUnit> units;
  final ValueChanged<MassUnit> onUnitChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppNumberField(
            label: label,
            controller: controller,
            suffix: unit.label,
            hint: hint,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in units)
                GestureDetector(
                  onTap: () => onUnitChanged(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: o == unit
                          ? AppColors.copper.withValues(alpha: 0.30)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      o.label,
                      style: TextStyle(
                        color: o == unit
                            ? AppColors.softGold
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
