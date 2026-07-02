import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/interactions.dart';

/// Hub'taki tek bir hesaplama aracı kartı.
///
/// Sade ve mobil-dostu: büyük dokunma alanı, ikon + kalın başlık + kısa
/// açıklama. Offline bilgisi hub üstündeki tek nottan gelir; kartta tekrar
/// rozet yoktur (başlık alanı ferahlar, uzun başlıklar dar ekranda sıkışmaz).
/// Saf gösterim — matematik/iş mantığı içermez.
class CalculatorToolCard extends StatelessWidget {
  const CalculatorToolCard({
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
    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.l),
            splashColor: AppColors.softGold.withValues(alpha: 0.06),
            highlightColor: AppColors.softGold.withValues(alpha: 0.04),
            child: ConstrainedBox(
              // Rahat dokunma alanı — kart en az 72 px yüksekliğinde.
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.m,
                  AppSpacing.m,
                  AppSpacing.m,
                ),
                child: Row(
                  children: [
                    _IconChip(icon: icon),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              letterSpacing: -0.1,
                            ),
                            // Küçük ekranda (320px) uzun başlıklar kırpılmasın;
                            // tam genişlik + 2 satıra kadar açılabilir.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.brandLemonPale,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
          width: 0.7,
        ),
      ),
      child: Icon(icon, color: AppColors.brandInk, size: 21),
    );
  }
}
