// FırınNet Market V1 M2 — Image gallery widget.
//
// Donor pattern: Bagisto `product_image_carousel.dart` + `fullscreen_image_viewer.dart`.
// PageView + dot indicator; tap → full-screen InteractiveViewer zoom.
// FırınNet'te video yok V1 (sadece image), Bagisto'nun gallery_media_picker
// alınmadı.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_network_image.dart';

class MarketplaceImageGallery extends StatefulWidget {
  const MarketplaceImageGallery({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 4 / 3,
    this.placeholderIcon = Icons.image_outlined,
  });

  final List<String> imageUrls;
  final double aspectRatio;

  /// Görselsiz ilanda gösterilen tür ikonu.
  final IconData placeholderIcon;

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
      // İlanlar tasarım geçişi — görselsiz ilan: daha kısa 16:9 sakin alan +
      // tür ikonu + "Fotoğraf yok" (büyük boş gri blok yerine).
      // Polish 2 — ortak "görsel yok" durumu (AppImageState).
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: KeyedSubtree(
          key: const ValueKey('market_gallery_no_photo'),
          child: AppImageState.empty(
            icon: widget.placeholderIcon,
            label: AppStrings.listingsNoPhoto,
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
                // Detayda görsel kırpılmaz (contain); boşluk sakin zemin.
                // Yükleniyor/hata durumları AppNetworkImage'den (kırık ikon yok).
                child: ColoredBox(
                  color: AppColors.surfaceLine,
                  child: AppNetworkImage(
                    url: url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    // Perf: carousel görseli ekran boyutunda decode edilir.
                    memCacheWidth: 720,
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
                    child: AppNetworkImage(
                      url: widget.imageUrls[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                key: const ValueKey('market_gallery_close'),
                tooltip: AppStrings.listingsCloseTooltip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    style: AppTypography.chipLabel.copyWith(
                      color: AppColors.surface,
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
