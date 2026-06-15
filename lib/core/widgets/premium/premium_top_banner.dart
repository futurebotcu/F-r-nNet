import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

enum PremiumTopBannerTone { info, success, warning, danger }

class PremiumTopBanner extends StatelessWidget {
  const PremiumTopBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = PremiumTopBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  /// Opsiyonel kısa başlık. Verilirse iki satırlı premium format:
  /// kalın başlık + altında açıklama (`message`). Boş/null ise yalnız
  /// `message` tek satır gösterilir (mevcut çağrı yerleri korunur).
  final String? title;
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
    final hasTitle = (title ?? '').trim().isNotEmpty;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTitle) ...[
                      Text(
                        title!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      // Çok uzun mesaj taşıp düzeni bozmasın.
                      maxLines: hasTitle ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: hasTitle ? 13 : 13.75,
                        height: 1.35,
                        fontWeight: hasTitle
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ],
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
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.iconColor,
              ),
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
  // Her show() bir nesil alır. Banner host'u (overlay entry) yok edildiğinde
  // yalnız kendi nesli güncelse timer'ı iptal eder — böylece widget-test
  // teardown'unda pending timer kalmaz, ama arka arkaya banner'da eski host'un
  // dispose'u yeni banner'ın timer'ını iptal etmez.
  static int _gen = 0;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    // Yalnız hâlâ ağaçta ise kaldır — çift dismiss / widget-test teardown'da
    // "not mounted" assertion'ını önler.
    if (entry != null && entry.mounted) entry.remove();
  }

  /// Banner host widget'ı yok edilince çağrılır. Yalnız hâlâ aktif nesil ise
  /// statik auto-dismiss timer'ını iptal eder.
  static void _handleHostDisposed(int gen) {
    if (gen == _gen) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    PremiumTopBannerTone tone = PremiumTopBannerTone.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();
    final gen = ++_gen;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _BannerHost(
          gen: gen,
          child: SafeArea(
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
                    title: title,
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

/// Banner overlay entry'sini saran küçük lifecycle widget'ı. Host yok
/// edildiğinde (örn. widget-test ağaç teardown'u) statik auto-dismiss
/// timer'ı pending kalmasın diye iptalini tetikler.
class _BannerHost extends StatefulWidget {
  const _BannerHost({required this.gen, required this.child});

  final int gen;
  final Widget child;

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost> {
  @override
  void dispose() {
    PremiumTopBannerController._handleHostDisposed(widget.gen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
