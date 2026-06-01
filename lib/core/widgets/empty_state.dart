import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// Editorial empty state — copper-glow ikon kutusu, başlık, alt metin
/// ve opsiyonel birincil aksiyon.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_fire_department_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Liste içine gömüldüğünde dikey alanı kısar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBox = Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.elevatedCard, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
        boxShadow: AppShadow.copper,
      ),
      child: Icon(icon, size: 38, color: AppColors.softGold),
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox,
          const SizedBox(height: AppSpacing.l),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.l),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copper,
                // P0 Design Tokens — copper primary aksiyon yazısı beyaz.
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 14,
                ),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageH,
          vertical: AppSpacing.l,
        ),
        child: Center(child: body),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: body,
      ),
    );
  }
}
