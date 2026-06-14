// Navigation IA Sprint — genel amaçlı premium pill segment çubuğu.
//
// ProfileCategoryTabs'in (yan yana pill, seçili = copper accent) modeli;
// Topluluk (Genel Akış / Gruplar) ve İlanlar (Eleman / İş yeri / Ekipman)
// gibi sekme-içi segmentler için tek tip. Provider'sız, stateless, doğrudan
// widget-test edilebilir.

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

class SegmentTabBar extends StatelessWidget {
  const SegmentTabBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: _Segment(
                  label: labels[i],
                  selected: i == index,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.copper : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: selected ? AppShadow.subtle : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            // Sarı/limon zemin üzerinde daima koyu ink metin (okunabilirlik).
            color: selected ? AppColors.brandInk : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
