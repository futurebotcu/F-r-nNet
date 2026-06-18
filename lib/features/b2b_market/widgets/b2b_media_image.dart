// B2B Pazar — görsel render yardımcısı.
//
// Yüklenmiş public URL'i (logo/cover/ürün/kampanya) gösterir; URL yoksa veya
// yüklenemezse kategori/tip ikonlu şık placeholder. Kart ve detay ekranları
// aynı görünümü paylaşsın diye tek yerde.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class B2bMediaImage extends StatelessWidget {
  const B2bMediaImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.radius = AppRadius.m,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String? url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double radius;
  final IconData placeholderIcon;

  bool get _has => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: width,
        child: _has
            ? Image.network(
                url!,
                fit: fit,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _Placeholder(icon: placeholderIcon, loading: true);
                },
                errorBuilder: (_, __, ___) =>
                    _Placeholder(icon: placeholderIcon),
              )
            : _Placeholder(icon: placeholderIcon),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, this.loading = false});
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 30, color: AppColors.borderHairline),
    );
  }
}
