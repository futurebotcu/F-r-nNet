// Profile Visual Placement Sprint — referans profil yapısındaki YAN YANA
// yatay kategori seçimi: [ Gönderiler ] [ Reçeteler ] [ Mesleki Bilgi ].
//
// Alt alta kart DEĞİL — üç segment tek satırda Expanded ile eşit genişlikte;
// aktif segment bakır/softGold vurgulu, pasifler sade. Provider'sız, stateless,
// doğrudan widget-test edilebilir.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';

class ProfileCategoryTabs extends StatelessWidget {
  const ProfileCategoryTabs({
    super.key,
    required this.index,
    required this.onChanged,
  });

  /// Seçili sekme (0: Gönderiler, 1: Reçeteler, 2: Mesleki Bilgi).
  final int index;
  final ValueChanged<int> onChanged;

  static const List<String> labels = <String>[
    AppStrings.profileTabPosts,
    AppStrings.profileTabRecipes,
    AppStrings.profileTabCv,
  ];

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
          // Track: hafif surface zemin; seçili segment üstte yumuşak yükselir.
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderHairline, width: 0.6),
        ),
        // Tek satır, yan yana — üç segment Expanded ile eşit genişlik.
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
          // Seçili segment hafif bakır halo ile zarifçe yükselir; pasifler düz.
          boxShadow: selected ? AppShadow.subtle : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
