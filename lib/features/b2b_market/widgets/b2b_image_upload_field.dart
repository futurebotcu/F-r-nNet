// B2B Pazar — canlı görsel upload alanı (V1).
//
// Mağaza logo/kapak, ürün ve kampanya görselleri için. Galeriden seç →
// Supabase storage'a yükle (B2bMediaUploadService) → public URL'i [onChanged]
// ile forma bildir. Yükleme sırasında spinner; hata SnackBar ile, form çökmez.
//
// Supabase yoksa (guest/no-config) servis null → "girişte aktif" uyarısı,
// no-op. Video YOK.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../auth/providers/auth_providers.dart';
import '../services/b2b_media_upload_service.dart';

class B2bImageUploadField extends ConsumerStatefulWidget {
  const B2bImageUploadField({
    super.key,
    required this.kind,
    required this.label,
    required this.currentUrl,
    required this.onChanged,
    this.height = 132,
  });

  final B2bMediaKind kind;
  final String label;
  final String? currentUrl;
  final ValueChanged<String?> onChanged;
  final double height;

  @override
  ConsumerState<B2bImageUploadField> createState() =>
      _B2bImageUploadFieldState();
}

class _B2bImageUploadFieldState extends ConsumerState<B2bImageUploadField> {
  bool _uploading = false;

  Future<void> _pick() async {
    final service = ref.read(b2bMediaUploadServiceProvider);
    final uid = ref.read(currentAuthUserProvider.select((u) => u?.id));
    if (service == null || uid == null) {
      _snack('Görsel yükleme giriş yaptıktan sonra aktif olur.');
      return;
    }
    final file = await service.pickFromGallery();
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await service.upload(
        userId: uid,
        kind: widget.kind,
        file: file,
      );
      widget.onChanged(url);
    } on B2bMediaTooLargeException {
      _snack('Görsel 5MB sınırını aşıyor. Daha küçük bir görsel seçin.');
    } catch (_) {
      _snack('Görsel yüklenemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.currentUrl;
    final hasImage = url != null && url.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (hasImage && !_uploading)
              GestureDetector(
                onTap: () => widget.onChanged(null),
                child: const Text(
                  'Kaldır',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _uploading ? null : _pick,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: widget.height,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.borderHairline, width: 0.8),
            ),
            child: _uploading
                ? const Center(child: CircularProgressIndicator())
                : hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: const Text(
                                'Değiştir',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _placeholder(),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 26,
            color: AppColors.brandLemonPressed,
          ),
          SizedBox(height: 6),
          Text(
            'Görsel ekle',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'jpg / png / webp · en çok 5MB',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
