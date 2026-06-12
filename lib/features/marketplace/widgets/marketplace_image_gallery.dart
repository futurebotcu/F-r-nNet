// FırınNet Market V1 M2 — Image gallery widget.
//
// Donor pattern: Bagisto `product_image_carousel.dart` + `fullscreen_image_viewer.dart`.
// PageView + dot indicator; tap → full-screen InteractiveViewer zoom.
// FırınNet'te video yok V1 (sadece image), Bagisto'nun gallery_media_picker
// alınmadı.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class MarketplaceImageGallery extends StatefulWidget {
  const MarketplaceImageGallery({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 4 / 3,
  });

  final List<String> imageUrls;
  final double aspectRatio;

  @override
  State<MarketplaceImageGallery> createState() =>
      _MarketplaceImageGalleryState();
}

class _MarketplaceImageGalleryState extends State<MarketplaceImageGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.imageUrls.length,
            itemBuilder: (_, i) {
              final url = widget.imageUrls[i];
              return GestureDetector(
                onTap: () => _openFullscreen(url),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  // Perf: carousel görseli ekran boyutunda decode edilir.
                  memCacheWidth: 720,
                  placeholder: (_, __) => Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (i) {
                final selected = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.copper
                        : AppColors.borderHairline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  void _openFullscreen(String url) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.imageScrimDark,
      builder: (_) =>
          _FullscreenViewer(imageUrls: widget.imageUrls, initialIndex: _index),
    );
  }
}

class _FullscreenViewer extends StatefulWidget {
  const _FullscreenViewer({
    required this.imageUrls,
    required this.initialIndex,
  });
  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.imageScrimDark,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: widget.imageUrls.length,
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[i],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.surface,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.surface54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.surface),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_index + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
