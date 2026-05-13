import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Yumuşak premium kart — hairline kenar + sakin gölge ile derinlik.
/// İki tür: standart (card) ve sıcak (elevatedCard).
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.onTap,
    this.warm = false,
    this.radius = AppRadius.l,
    this.bordered = true,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool warm;
  final double radius;
  final bool bordered;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final bg = warm ? AppColors.elevatedCard : AppColors.card;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    final content = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: bordered
            ? Border.all(color: AppColors.borderHairline, width: 0.6)
            : null,
        boxShadow: elevated ? AppShadow.card : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.softGold.withValues(alpha: 0.06),
        highlightColor: AppColors.softGold.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}
