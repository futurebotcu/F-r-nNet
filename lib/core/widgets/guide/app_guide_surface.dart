import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import 'guide_message.dart';

/// FırınNet yönlendirme yüzeyi — [GuideMessage] modelini çizer.
///
/// İki ana yerleşim:
/// - [GuidePlacement.topBanner]: üstte ince şerit; marka ikon alanı + kısa
///   başlık + kısa açıklama. Kullanıcıyı bölmez, kapatılabilir.
/// - [GuidePlacement.bottomGuide] / [GuidePlacement.floatingBottom]: altta
///   geniş işlem rehberi paneli; adım anlatımı taşır, formu kilitlemez.
///
/// Davranış kuralları:
/// - Kapatma/küçültme durumu widget örneğine aittir → ekrana her yeni
///   girişte rehber yeniden görünür (kalıcı gizleme yok).
/// - Klavye açıkken alt rehber otomatik küçülür; form alanlarını ezmez.
/// - [forceCollapsed] ile ekran, hata/validasyon anlarında rehberi geri
///   plana alabilir (hata mesajı önceliklidir).
/// - İçerik dar ekranda ve büyük yazı ölçeğinde taşmaz: panel içeriği
///   yükseklik sınırlı + kaydırılabilirdir.
class AppGuideSurface extends StatefulWidget {
  const AppGuideSurface({
    super.key,
    required this.message,
    this.forceCollapsed = false,
    this.onDismissed,
    this.onCta,
  });

  final GuideMessage message;

  /// Ekran, rehberi geçici olarak küçültmek istediğinde (örn. form hatası
  /// gösterilirken) `true` verir. Kullanıcının kendi küçültmesinden
  /// bağımsızdır; `false` olunca kullanıcı tercihi geçerli kalır.
  final bool forceCollapsed;

  final VoidCallback? onDismissed;
  final VoidCallback? onCta;

  @override
  State<AppGuideSurface> createState() => _AppGuideSurfaceState();
}

class _AppGuideSurfaceState extends State<AppGuideSurface> {
  bool _dismissed = false;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.message.shouldShow) {
      return const SizedBox.shrink();
    }
    switch (widget.message.placement) {
      case GuidePlacement.topBanner:
      case GuidePlacement.inlineGuide:
        return _TopBanner(
          message: widget.message,
          onClose: widget.message.dismissible ? _dismiss : null,
        );
      case GuidePlacement.bottomGuide:
      case GuidePlacement.floatingBottom:
        // Klavye açıkken rehber form alanlarını ezmesin: otomatik küçül.
        // Scaffold, body içinde viewInsets'i sıfırladığı için ham View
        // inset'i okunur; MediaQuery bağımlılığı metrik değişiminde
        // rebuild'i garanti eder (Scaffold padding'e çevirir).
        final mqInset = MediaQuery.viewInsetsOf(context).bottom;
        final view = View.of(context);
        final rawInset = view.viewInsets.bottom / view.devicePixelRatio;
        final keyboardOpen = mqInset > 0 || rawInset > 0;
        final collapsed = _collapsed || widget.forceCollapsed || keyboardOpen;
        return _BottomGuidePanel(
          message: widget.message,
          collapsed: collapsed,
          onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
          onClose: widget.message.dismissible ? _dismiss : null,
          onCta: widget.onCta,
        );
    }
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    widget.onDismissed?.call();
  }
}

/// Üst ince bilgilendirme şeridi: marka ikon alanı + başlık + kısa açıklama.
class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.message, this.onClose});

  final GuideMessage message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = _GuideColors.of(message.variant);
    return Material(
      color: Colors.transparent,
      child: Container(
        key: ValueKey('guide_${message.id}'),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.s + 2,
          AppSpacing.s,
          AppSpacing.s + 2,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: colors.border, width: 0.8),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BrandIconChip(
              icon: message.icon ?? colors.defaultIcon,
              colors: colors,
              size: 32,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.title,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message.body,
                      style: TextStyle(
                        color: colors.text.withValues(alpha: 0.85),
                        fontSize: 12.25,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 2),
              IconButton(
                key: ValueKey('guide_close_${message.id}'),
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
          ],
        ),
      ),
    );
  }
}

/// Alt geniş işlem rehberi paneli — adım anlatımı; modal değildir,
/// formu kilitlemez. Küçültülebilir/kapatılabilir.
class _BottomGuidePanel extends StatelessWidget {
  const _BottomGuidePanel({
    required this.message,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.onClose,
    this.onCta,
  });

  final GuideMessage message;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onClose;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final colors = _GuideColors.of(message.variant);
    // Dar ekran + büyük yazı ölçeğinde içerik taşmasın: adım listesi
    // ekranın en fazla ~%40'ı kadar yer tutar, gerekirse içinde kayar.
    final maxBodyHeight = math.min(
      340.0,
      MediaQuery.sizeOf(context).height * 0.4,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        key: ValueKey('guide_${message.id}'),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.xs,
          AppSpacing.m,
          AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: colors.border, width: 0.9),
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık şeridi — her durumda görünür; küçültme/kapatma burada.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s + 2,
                AppSpacing.xs,
                AppSpacing.s + 2,
              ),
              child: Row(
                children: [
                  _BrandIconChip(
                    icon: message.icon ?? colors.defaultIcon,
                    colors: colors,
                    size: 34,
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      message.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('guide_collapse_${message.id}'),
                    onPressed: onToggleCollapsed,
                    tooltip: collapsed ? 'Genişlet' : 'Küçült',
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      collapsed
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      key: ValueKey('guide_close_${message.id}'),
                      onPressed: onClose,
                      tooltip: 'Kapat',
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (!collapsed)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    0,
                    AppSpacing.m,
                    AppSpacing.m,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.body.isNotEmpty) ...[
                        Text(
                          message.body,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.75,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (message.steps.isNotEmpty)
                          const SizedBox(height: AppSpacing.m),
                      ],
                      for (var i = 0; i < message.steps.length; i++) ...[
                        _GuideStepRow(index: i + 1, step: message.steps[i]),
                        if (i != message.steps.length - 1)
                          const SizedBox(height: AppSpacing.s + 2),
                      ],
                      if (message.ctaLabel != null && onCta != null) ...[
                        const SizedBox(height: AppSpacing.m),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: ValueKey('guide_cta_${message.id}'),
                            onPressed: onCta,
                            child: Text(
                              message.ctaLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepRow extends StatelessWidget {
  const _GuideStepRow({required this.index, required this.step});

  final int index;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandLemonPale,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.brandLemonPressed.withValues(alpha: 0.3),
              width: 0.7,
            ),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.brandInk,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                step.body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Limon zeminli marka ikon alanı — guide ailesinin ortak görsel imzası.
class _BrandIconChip extends StatelessWidget {
  const _BrandIconChip({
    required this.icon,
    required this.colors,
    required this.size,
  });

  final IconData icon;
  final _GuideColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.iconBg,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Icon(icon, size: size * 0.52, color: colors.iconColor),
    );
  }
}

/// Varyant → renk ailesi (PremiumTopBanner tone paletiyle aynı dil).
class _GuideColors {
  const _GuideColors({
    required this.background,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.defaultIcon,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final IconData defaultIcon;
  final Color text;

  static _GuideColors of(GuideVariant variant) {
    switch (variant) {
      case GuideVariant.success:
        return const _GuideColors(
          background: Color(0xFFF3FBEF),
          border: Color(0xFFC9E7C4),
          iconBg: Color(0xFFE4F4DE),
          iconColor: AppColors.success,
          defaultIcon: Icons.check_circle_rounded,
          text: Color(0xFF14532D),
        );
      case GuideVariant.warning:
        return const _GuideColors(
          background: Color(0xFFFFF9EB),
          border: Color(0xFFF7DF9D),
          iconBg: Color(0xFFFDF1CD),
          iconColor: Color(0xFFB45309),
          defaultIcon: Icons.info_rounded,
          text: Color(0xFF92400E),
        );
      case GuideVariant.tip:
      case GuideVariant.info:
        return const _GuideColors(
          background: AppColors.brandLemonPale,
          border: Color(0xFFE9DA93),
          iconBg: Color(0xFFFFF6C7),
          iconColor: AppColors.brandInk,
          defaultIcon: Icons.tips_and_updates_outlined,
          text: AppColors.brandInk,
        );
    }
  }
}

/// Geçici üst guide banner'ı overlay olarak gösterir (tek örnek kuralı:
/// yeni banner öncekini kapatır — üst üste binme olmaz).
class AppGuideOverlay {
  AppGuideOverlay._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  /// [message] topBanner yerleşiminde üstte gösterilir; [duration] sonunda
  /// kendiliğinden kapanır (Duration.zero → kullanıcı kapatana dek kalır).
  static void showTopBanner(
    BuildContext context, {
    required GuideMessage message,
    Duration duration = const Duration(seconds: 4),
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
                child: AppGuideSurface(message: message, onDismissed: dismiss),
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
