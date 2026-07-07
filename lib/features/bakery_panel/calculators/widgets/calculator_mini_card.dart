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
    this.lockedTag,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Paywall UI — non-null ise üst şeritte chevron yerine kilit rozeti
  /// ("Pro"/"Premium") gösterir. null ise mevcut davranış (chevron).
  final String? lockedTag;

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
                  _TopRow(icon: icon, lockedTag: lockedTag),
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
  const _TopRow({required this.icon, this.lockedTag});
  final IconData icon;
  final String? lockedTag;

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
        const SizedBox(width: 6),
        // Kilit rozeti/chevron sağa hizalı; dar ekran + büyük yazı ölçeğinde
        // FittedBox ile küçülür (taşma-güvenli — 320dp/1.3x'te overflow yok).
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: lockedTag != null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandInk,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: AppColors.brandLemon,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            lockedTag!,
                            style: const TextStyle(
                              color: AppColors.brandLemon,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
          ),
        ),
      ],
    );
  }
}
