import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// FırınNet hashtag pill chip (Visual North Star Sprint 1A).
///
/// Post tags için brand-uyumlu pill: pale lemon tint bg + soft border +
/// ink label (`AppTypography.labelLarge`).
/// `#` prefix widget içinde otomatik eklenir; caller ham `label` verir.
///
/// `onTap` opsiyonel — Sprint 1A'da `null` (placeholder). Sprint 5+'ta
/// hashtag arama eklenebilir.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.onTap});

  /// Ham hashtag adı (örn. `'ekşimaya'`). Widget içeride `#` ekler.
  final String label;

  /// İleride hashtag-arama veya filter için. Şu an genelde `null`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.brandLemonSoft, width: 0.6),
        boxShadow: AppShadow.subtle,
      ),
      child: Text(
        '#$label',
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.brandInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: pill,
      ),
    );
  }
}
