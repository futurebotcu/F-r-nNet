import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

enum PremiumTopBannerTone { info, success, warning, danger }

class PremiumTopBanner extends StatelessWidget {
  const PremiumTopBanner({
    super.key,
    required this.message,
    this.tone = PremiumTopBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final String message;
  final PremiumTopBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = _BannerColors.fromTone(tone);
    final resolvedIcon = icon ?? colors.defaultIcon;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: colors.border, width: 0.8),
          boxShadow: AppShadow.soft,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.m,
          AppSpacing.s,
          AppSpacing.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.iconBg,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Icon(resolvedIcon, size: 18, color: colors.iconColor),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13.75,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('premium_top_banner_action'),
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 4,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('premium_top_banner_close'),
              onPressed: onClose,
              tooltip: 'Kapat',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: colors.iconColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerColors {
  const _BannerColors({
    required this.background,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.defaultIcon,
    required this.text,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final IconData defaultIcon;
  final Color text;
  final Color accent;

  static _BannerColors fromTone(PremiumTopBannerTone tone) {
    switch (tone) {
      case PremiumTopBannerTone.success:
        return const _BannerColors(
          background: Color(0xFFF3FBEF),
          border: Color(0xFFC9E7C4),
          iconBg: Color(0xFFE4F4DE),
          iconColor: AppColors.success,
          defaultIcon: Icons.check_circle_rounded,
          text: Color(0xFF14532D),
          accent: Color(0xFF166534),
        );
      case PremiumTopBannerTone.warning:
        return const _BannerColors(
          background: Color(0xFFFFF9EB),
          border: Color(0xFFF7DF9D),
          iconBg: Color(0xFFFDF1CD),
          iconColor: Color(0xFFB45309),
          defaultIcon: Icons.info_rounded,
          text: Color(0xFF92400E),
          accent: Color(0xFF92400E),
        );
      case PremiumTopBannerTone.danger:
        return const _BannerColors(
          background: Color(0xFFFFF1F2),
          border: Color(0xFFF6C3C7),
          iconBg: Color(0xFFFDE2E5),
          iconColor: AppColors.danger,
          defaultIcon: Icons.error_rounded,
          text: Color(0xFF991B1B),
          accent: Color(0xFFB91C1C),
        );
      case PremiumTopBannerTone.info:
        return const _BannerColors(
          background: AppColors.brandLemonPale,
          border: Color(0xFFE9DA93),
          iconBg: Color(0xFFFFF6C7),
          iconColor: AppColors.brandInk,
          defaultIcon: Icons.info_rounded,
          text: AppColors.brandInk,
          accent: AppColors.brandInk,
        );
    }
  }
}

class PremiumTopBannerController {
  PremiumTopBannerController._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    PremiumTopBannerTone tone = PremiumTopBannerTone.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: AppDuration.normal,
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * -12),
                      child: child,
                    ),
                  );
                },
                child: PremiumTopBanner(
                  message: message,
                  tone: tone,
                  icon: icon,
                  actionLabel: actionLabel,
                  onAction: onAction == null
                      ? null
                      : () {
                          onAction();
                          dismiss();
                        },
                  onClose: dismiss,
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);

    if (duration > Duration.zero) {
      _timer = Timer(duration, dismiss);
    }
  }
}
