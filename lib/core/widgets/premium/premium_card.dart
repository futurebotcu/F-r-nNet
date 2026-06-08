import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

enum CardTier { standard, hero, compact }

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.onTap,
    this.warm = false,
    this.tier = CardTier.standard,
    this.radius,
    this.bordered = true,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool warm;
  final CardTier tier;
  final double? radius;
  final bool bordered;
  final bool elevated;

  CardTier get _effectiveTier => warm ? CardTier.hero : tier;

  double get _resolvedRadius {
    if (radius != null) return radius!;
    switch (_effectiveTier) {
      case CardTier.standard:
        return AppRadius.l;
      case CardTier.hero:
        return AppRadius.xl;
      case CardTier.compact:
        return AppRadius.m;
    }
  }

  List<BoxShadow>? _resolvedShadow() {
    if (!elevated || _effectiveTier == CardTier.compact) return null;
    return _effectiveTier == CardTier.hero ? AppShadow.soft : AppShadow.card;
  }

  Border? _resolvedBorder() {
    if (!bordered || _effectiveTier == CardTier.compact) return null;
    return Border.all(color: AppColors.borderHairline, width: 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolvedRadius;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
    );

    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r),
        border: _resolvedBorder(),
        boxShadow: _resolvedShadow(),
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
        borderRadius: BorderRadius.circular(r),
        splashColor: AppColors.softGold.withValues(alpha: 0.06),
        highlightColor: AppColors.softGold.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}
