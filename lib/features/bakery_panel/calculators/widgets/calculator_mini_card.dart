import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/interactions.dart';

/// Hub'ın 2 kolonlu ızgarasındaki kompakt hesaplama aracı kartı.
///
/// Premium ve hızlı taranabilir: limon zeminli ikon + pasif chevron üstte,
/// altında 2 satıra kadar kalın başlık ve kısa açıklama. Izgara sabit
/// yükseklik verdiği için metinler Flexible + ellipsis ile korunur; dar
/// ekranda (320dp, 2 kolon) taşma oluşmaz. Offline bilgisi hub üstündeki
/// tek nottan gelir; kartta rozet yoktur.
/// Saf gösterim — matematik/iş mantığı içermez.
class CalculatorMiniCard extends StatelessWidget {
  const CalculatorMiniCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
      side: const BorderSide(color: AppColors.borderHairline, width: 1),
    );
    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.m),
          boxShadow: AppShadow.card,
        ),
        child: Material(
          color: AppColors.surface,
          shape: shape,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            splashColor: AppColors.softGold.withValues(alpha: 0.06),
            highlightColor: AppColors.softGold.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopRow(icon: icon),
                  const SizedBox(height: AppSpacing.s),
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Üst şerit: limon zeminli ikon solda, küçük pasif chevron sağda.
class _TopRow extends StatelessWidget {
  const _TopRow({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
              width: 0.7,
            ),
          ),
          child: Icon(icon, color: AppColors.brandInk, size: 18),
        ),
        const Spacer(),
        const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 13,
          color: AppColors.textMuted,
        ),
      ],
    );
  }
}
