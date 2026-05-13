import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../interactions.dart';

/// Geniş yatay liste tile'ı — kalın border yok, soft yüzey, hairline kenar.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent = AppColors.softGold,
    this.featured = false,
  });

  final String label;
  final IconData icon;
  final String? subtitle;
  final VoidCallback onTap;
  final Color accent;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = featured ? AppColors.elevatedCard : AppColors.card;
    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: featured ? AppShadow.copper : AppShadow.card,
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.l),
            splashColor: accent.withValues(alpha: 0.06),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(
                  color: featured
                      ? AppColors.copper.withValues(alpha: 0.32)
                      : AppColors.borderHairline,
                  width: featured ? 0.8 : 0.6,
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                featured ? AppSpacing.m : AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
              ),
              child: Row(
                children: [
                  if (featured) ...[
                    Container(
                      width: 3,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.softGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: featured ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Icon(
                      icon,
                      color: accent,
                      size: featured ? 22 : 21,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight:
                                featured ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: featured ? 16 : 15.5,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: featured ? 16 : 14,
                    color: featured ? AppColors.softGold : AppColors.textMuted,
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

/// 2-col grid için kompakt aksiyon kartı — ikon üstte, etiket altta.
class QuickActionMini extends StatelessWidget {
  const QuickActionMini({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.softGold,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

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
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.l),
            splashColor: accent.withValues(alpha: 0.06),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(
                  color: AppColors.borderHairline,
                  width: 0.6,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Icon(icon, color: accent, size: 19),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      letterSpacing: -0.1,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
