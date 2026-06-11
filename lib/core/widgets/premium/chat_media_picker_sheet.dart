// FırınNet Chat Media V1.1 — medya seçim bottom sheet (image + video).
//
// Composer'daki medya ikonuna basınca açılır. Lemon-white premium kimlik.
// 4 seçenek: Galeriden seç / Fotoğraf çek / Video seç / Video çek.
// Kapatırsa null döner; akış bozulmadan devam eder.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/messaging/services/chat_media_upload_service.dart'
    show ChatMediaKind;
import '../../constants/app_strings.dart';

/// Sheet sonucu: kaynak (galeri/kamera) + medya türü (image/video).
class ChatMediaPick {
  const ChatMediaPick({required this.source, required this.kind});

  final ImageSource source;
  final ChatMediaKind kind;

  bool get isVideo => kind == ChatMediaKind.video;
}

class ChatMediaPickerSheet {
  const ChatMediaPickerSheet._();

  /// Sheet'i açar; kullanıcı bir seçenek seçerse [ChatMediaPick] döner,
  /// kapatırsa null.
  static Future<ChatMediaPick?> show(BuildContext context) {
    return showModalBottomSheet<ChatMediaPick>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: AppSpacing.s),
                child: Text(
                  AppStrings.chatMediaSheetTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _MediaOption(
                icon: Icons.photo_library_rounded,
                label: AppStrings.chatMediaPickGallery,
                onTap: () => Navigator.of(ctx).pop(
                  const ChatMediaPick(
                    source: ImageSource.gallery,
                    kind: ChatMediaKind.image,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MediaOption(
                icon: Icons.photo_camera_rounded,
                label: AppStrings.chatMediaTakePhoto,
                onTap: () => Navigator.of(ctx).pop(
                  const ChatMediaPick(
                    source: ImageSource.camera,
                    kind: ChatMediaKind.image,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MediaOption(
                icon: Icons.video_library_rounded,
                label: AppStrings.chatMediaPickVideoGallery,
                onTap: () => Navigator.of(ctx).pop(
                  const ChatMediaPick(
                    source: ImageSource.gallery,
                    kind: ChatMediaKind.video,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MediaOption(
                icon: Icons.videocam_rounded,
                label: AppStrings.chatMediaRecordVideo,
                onTap: () => Navigator.of(ctx).pop(
                  const ChatMediaPick(
                    source: ImageSource.camera,
                    kind: ChatMediaKind.video,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  const _MediaOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.brandLemonPressed.withValues(alpha: 0.4),
                    width: 0.6,
                  ),
                ),
                child: Icon(icon, size: 19, color: AppColors.brandInk),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
