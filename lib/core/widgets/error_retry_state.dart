import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../constants/app_strings.dart';

/// Faz 2 UI — tüm uygulamada tek tip hata + yeniden dene durumu.
///
/// Eskiden çok yerde `Text('Hata: $e')` / `Center(child: Text('Hata: $e'))`
/// gibi çıplak hata metinleri vardı. Bu component [EmptyState] ile aynı
/// premium dili konuşur: yumuşak ikon kutusu + başlık + opsiyonel açıklama +
/// "Yeniden dene" aksiyonu. Ham exception kullanıcıya gösterilmez.
class ErrorRetryState extends StatelessWidget {
  const ErrorRetryState({
    super.key,
    this.title = AppStrings.errorGenericTitle,
    this.subtitle = AppStrings.errorGenericSubtitle,
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel = AppStrings.retry,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Liste/section içine gömüldüğünde dikey alanı kısar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBox = Container(
      width: compact ? 56 : 68,
      height: compact ? 56 : 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.elevatedCard, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(compact ? AppRadius.l : AppRadius.xl),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
        boxShadow: AppShadow.subtle,
      ),
      child: Icon(icon, size: compact ? 23 : 27, color: AppColors.textMuted),
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBox,
          const SizedBox(height: AppSpacing.m),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(retryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copper,
                foregroundColor: AppColors.brandInk,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
          vertical: AppSpacing.m,
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
