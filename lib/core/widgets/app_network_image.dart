import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'firinnet_avatar.dart';

/// Ana görsel alanlarının (ilan, işletme, feed, Akademi) ortak dört durumu:
/// yükleniyor · başarılı · hata · görsel yok. Kırık ağ resmi ikonu yerine
/// sakin nötr yüzey + küçük ikon (+ isteğe bağlı kısa etiket).
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.borderRadius,
    this.emptyIcon = Icons.image_outlined,
    this.emptyLabel,
    this.errorLabel = 'Görsel yüklenemedi',
    this.compact = false,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final BorderRadius? borderRadius;
  final IconData emptyIcon;

  /// "Fotoğraf yok" gibi; null → yalnız ikon.
  final String? emptyLabel;
  final String? errorLabel;

  /// Küçük küçük-resimlerde (≤ 72px) etiket gizlenir, ikon küçülür.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final Widget child = FirinNetAvatar.isUsableUrl(u)
        ? CachedNetworkImage(
            imageUrl: u!,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, __) => AppImageState.loading(compact: compact),
            errorWidget: (_, __, ___) => AppImageState.error(
              label: compact ? null : errorLabel,
              compact: compact,
            ),
          )
        : AppImageState.empty(
            icon: emptyIcon,
            label: compact ? null : emptyLabel,
            compact: compact,
          );
    final sized = SizedBox(width: width, height: height, child: child);
    if (borderRadius == null) return sized;
    return ClipRRect(borderRadius: borderRadius!, child: sized);
  }
}

/// Görsel alanının görsel-dışı durumları (tek görünüm dili).
class AppImageState extends StatelessWidget {
  const AppImageState._({
    super.key,
    required this.icon,
    this.label,
    this.compact = false,
    this.showIcon = true,
  });

  /// Yükleniyor: yalnız nötr yüzey (spinner yok — liste kaydırmada sakin).
  factory AppImageState.loading({Key? key, bool compact = false}) =>
      AppImageState._(
        key: key ?? const ValueKey('app_image_loading'),
        icon: Icons.image_outlined,
        compact: compact,
        showIcon: false,
      );

  factory AppImageState.error({
    Key? key,
    String? label,
    bool compact = false,
  }) => AppImageState._(
    key: key ?? const ValueKey('app_image_error'),
    icon: Icons.image_not_supported_outlined,
    label: label,
    compact: compact,
  );

  factory AppImageState.empty({
    Key? key,
    IconData icon = Icons.image_outlined,
    String? label,
    bool compact = false,
  }) => AppImageState._(
    key: key ?? const ValueKey('app_image_empty'),
    icon: icon,
    label: label,
    compact: compact,
  );

  final IconData icon;
  final String? label;
  final bool compact;
  final bool showIcon;

  static const Color surface = Color(0xFFF4F5F7);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surface,
      alignment: Alignment.center,
      child: !showIcon
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: compact ? 20 : 28,
                      color: AppColors.textMuted,
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        label!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
