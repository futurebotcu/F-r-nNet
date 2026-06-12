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
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final String? subtitle;
  final VoidCallback onTap;
  final Color accent;
  final bool featured;

  /// M-10 — > 0 ise trailing chevron öncesinde premium okunmamış rozeti
  /// gösterir (lemon zemin + brandInk sayı). 0 ise hiç render edilmez.
  final int badgeCount;

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
            splashColor: accent.withValues(alpha: 0.06),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              padding: EdgeInsets.fromLTRB(
                featured ? AppSpacing.m : AppSpacing.l,
                AppSpacing.m,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: Row(
                children: [
                  if (featured) ...[
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.softGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                  ],
                  Container(
                    width: featured ? 38 : 36,
                    height: featured ? 38 : 36,
                    // Faz 2 Pass 4 — eskiden ink accent @0.08 ile çip neredeyse
                    // görünmez (donuk gri) idi. Artık sıcak pale-lemon çip + ink
                    // ikon: premium, marka, okunur.
                    decoration: BoxDecoration(
                      color: AppColors.brandLemonPale,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: AppColors.brandLemonPressed.withValues(alpha: 0.28),
                        width: 0.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandLemonPressed.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.brandInk,
                      size: featured ? 19 : 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: featured
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: featured ? 15.5 : 15,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
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
                  if (badgeCount > 0) ...[
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandLemon,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.brandLemonPressed.withValues(
                            alpha: 0.45,
                          ),
                          width: 0.6,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: AppColors.brandInk,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                  ],
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.l),
            splashColor: accent.withValues(alpha: 0.06),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.16),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accent, size: 17),
                  ),
                  const SizedBox(height: AppSpacing.s),
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
