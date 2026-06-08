import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import 'premium_card.dart';

/// Büyük rakamı öne çıkaran metrik kartı. Editorial hiyerarşi:
///  - üstte küçük, sakin etiket (uppercase)
///  - büyük rakam
///  - ufak yardımcı metin (delta vs.)
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.icon,
    this.accent,
    this.warm = false,
    this.hero = false,
  });

  final String label;
  final String value;
  final String? helper;
  final IconData? icon;
  final Color? accent;
  final bool warm;

  /// `true` ise daha buyuk rakam, ek padding, brand accent helper.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = accent ?? AppColors.softGold;
    return PremiumCard(
      warm: warm,
      padding: EdgeInsets.all(hero ? AppSpacing.xl : AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: a, size: hero ? 20 : 18),
                const SizedBox(width: AppSpacing.s),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: hero ? 12 : 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: hero ? AppSpacing.l : AppSpacing.m),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              // Premium card trio sprint — hero variant rakam vurgusu:
              // letterSpacing -0.8 → -1.0 + fontSize 32 → 34 ile gün sonu
              // ve dealer overview KPI'larında daha güçlü "AAA hiyerarşi"
              // hissi. Default variant (26 / -0.8) dokunulmaz.
              letterSpacing: hero ? -1.0 : -0.8,
              fontSize: hero ? 34 : 26,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hero ? AppColors.softGold : AppColors.textMuted,
                fontWeight: hero ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
