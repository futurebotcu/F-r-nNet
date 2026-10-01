import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

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
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
