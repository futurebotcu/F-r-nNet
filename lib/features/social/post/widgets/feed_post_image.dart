import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// Feed ve detay ekranının ORTAK post görseli. Kutu görselin GERÇEK
/// oranında çizilir ve `BoxFit.contain` kullanılır: üzerinde yazı olan
/// Akademi kartları dahil hiçbir görsel kırpılmaz.
///
/// Oran sınırları: en dikey 4:5 (telefon ekranını kaplayan dev kart
/// olmasın), en yatay 1.91:1. Sınıra takılan görsel yine kırpılmaz;
/// boşluk nötr zeminle doldurulur. Boyut meta verisi yoksa (eski kullanıcı
/// yüklemeleri) görsel çözümlenince gerçek oran ölçülür.
class FeedPostImage extends StatefulWidget {
  const FeedPostImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.memCacheWidth,
  });

  final String imageUrl;
  final int? width;
  final int? height;
  final int? memCacheWidth;

  static const double minAspect = 4 / 5;
  static const double maxAspect = 1.91;
  static const double fallbackAspect = 4 / 3;

  static double clampAspect(double raw) =>
      raw.clamp(minAspect, maxAspect).toDouble();

  @override
  State<FeedPostImage> createState() => _FeedPostImageState();
}

class _FeedPostImageState extends State<FeedPostImage> {
  double? _resolvedAspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  double? get _metaAspect {
    final w = widget.width;
    final h = widget.height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_metaAspect == null && _stream == null) _resolveIntrinsicSize();
  }

  void _resolveIntrinsicSize() {
    final stream = CachedNetworkImageProvider(widget.imageUrl)
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        final img = info.image;
        if (!mounted || img.height == 0) return;
        setState(() => _resolvedAspect = img.width / img.height);
      },
      onError: (_, __) {},
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw =
        _metaAspect ?? _resolvedAspect ?? FeedPostImage.fallbackAspect;
    return AspectRatio(
      aspectRatio: FeedPostImage.clampAspect(raw),
      child: ColoredBox(
        color: AppColors.surface,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          memCacheWidth: widget.memCacheWidth,
          // Yüklenirken spinner yerine sakin nötr yüzey (akışta her kartta
          // dönen çark gürültü yapıyordu).
          placeholder: (_, __) => const ColoredBox(
            key: ValueKey('feed_image_placeholder'),
            color: AppColors.surfaceLine,
            child: SizedBox.expand(),
          ),
          errorWidget: (_, __, ___) => const FeedImageErrorState(),
        ),
      ),
    );
  }
}

/// Görsel yüklenemediğinde nötr zemin + ikon + kısa açıklama.
class FeedImageErrorState extends StatelessWidget {
  const FeedImageErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceLine,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textMuted,
              size: 26,
            ),
            SizedBox(height: 6),
            Text(
              AppStrings.feedPostImageLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
