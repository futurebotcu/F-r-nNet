// B2B Pazar — görsel render yardımcısı.
//
// Yüklenmiş public URL'i (logo/cover/ürün/kampanya) gösterir; URL yoksa veya
// yüklenemezse kategori/tip ikonlu sakin placeholder. Kart ve detay ekranları
// aynı görünümü paylaşsın diye tek yerde. Uygulama polish 2: ortak
// [AppNetworkImage] durum diline (yükleniyor / hata / görsel yok) bağlandı —
// kırık ağ resmi ikonu veya liste içinde spinner gösterilmez.

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/app_network_image.dart';

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

  @override
  Widget build(BuildContext context) {
    // Küçük küçük-resimlerde (logo vb.) etiket gizlenir, ikon küçülür.
    final compact =
        (height != null && height! <= 72) || (width != null && width! <= 72);
    return AppNetworkImage(
      url: url,
      fit: fit,
      height: height,
      width: width,
      borderRadius: BorderRadius.circular(radius),
      emptyIcon: placeholderIcon,
      compact: compact,
      memCacheWidth: width == null ? 900 : (width! * 3).round(),
    );
  }
}
