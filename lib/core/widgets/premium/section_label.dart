import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';

/// Editorial section başlığı: başlık + opsiyonel yan link/chevron.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
    this.topGap = AppSpacing.xl,
    this.bottomGap = AppSpacing.m,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final double topGap;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        topGap,
        AppSpacing.pageH,
        bottomGap,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.sectionTitle.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackgroundPrimary,
              ),
            ),
          ),
          if (trailingLabel != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Padding(
                // Dokunma alanı ≥ 40px yükseklik; görsel boşluk değişmesin
                // diye dikey padding negatif margin yerine sabit tutuldu.
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.brandInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.brandInk,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Editorial büyük sayfa başlığı.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 27,
              letterSpacing: -0.4,
              height: 1.12,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
