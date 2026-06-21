import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/post_type.dart';
import '../../profile/providers/profile_provider.dart';
import 'social_composer_page.dart';

/// Feed üstündeki Twitter/Facebook tarzı inline composer (Feed Premium Sprint).
///
/// Büyük kart değil; feed'in doğal başlangıç alanı. Üst satır avatar +
/// "Bugün ne ürettin?" placeholder, alt satır aksiyonlar:
/// **Medya** (tek ikon → modal action sheet ile 4 mevcut işlev) · Soru ·
/// Tarif · Duyuru · sağda küçük **Paylaş** butonu. Soru/Tarif/Duyuru composer'a
/// tür ön-seçimiyle gider; Medya seçenekleri composer'da ilgili picker'ı açar.
///
/// Guest tap: `runGuardedMutation` paterniyle auth required sheet açılır.
class InlineComposerCard extends ConsumerWidget {
  const InlineComposerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final initial = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName[0].toUpperCase()
        : 'M';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: avatar + placeholder. Tap → metin odaklı composer.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openComposer(context, ref),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brandLemonPale,
                            border: Border.all(
                              color: AppColors.brandLemonSoft,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.brandInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.feedComposerPanelPlaceholder,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppStrings.feedComposerPanelSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Alt aksiyon satırı: Medya / Soru / Tarif / Duyuru + Paylaş.
              // Aksiyonlar yatay kaydırılabilir alanda (dar ekran/büyük yazı
              // ölçeğinde taşma yok); Paylaş her zaman sağda sabit.
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ComposerAction(
                            icon: Icons.perm_media_outlined,
                            label: AppStrings.feedComposerActionMedia,
                            onTap: () => _onMediaTap(context, ref),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ComposerAction(
                            icon: Icons.help_outline_rounded,
                            label: AppStrings.feedComposerActionQuestion,
                            onTap: () => _openComposer(
                              context,
                              ref,
                              type: PostType.question,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ComposerAction(
                            icon: Icons.menu_book_rounded,
                            label: AppStrings.feedComposerActionRecipe,
                            onTap: () => _openComposer(
                              context,
                              ref,
                              type: PostType.recipe,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ComposerAction(
                            icon: Icons.campaign_outlined,
                            label: AppStrings.feedComposerActionAnnouncement,
                            onTap: () => _openComposer(
                              context,
                              ref,
                              type: PostType.announcement,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _ShareButton(onTap: () => _openComposer(context, ref)),
                ],
              ),
            ],
          ),
        ),
        // İnce ayraç — composer'ı ilk gönderiden ayırır.
        const Divider(height: 1, color: AppColors.borderHairline),
      ],
    );
  }

  /// Medya aksiyonu → modal action sheet (Fotoğraf çek / Galeriden seç /
  /// Video çek / Galeriden video seç). Guest ise önce auth required sheet.
  Future<void> _onMediaTap(BuildContext context, WidgetRef ref) async {
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    if (!context.mounted) return;
    final intent = await showModalBottomSheet<ComposerMediaIntent>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _MediaActionSheet(),
    );
    if (intent == null || !context.mounted) return;
    await _openComposer(context, ref, media: intent);
  }
}

/// Composer'a (opsiyonel medya intent + tür ön-seçimi ile) guarded push.
/// Guest ise auth required sheet açılır; aksi halde composer route'una gider.
Future<void> _openComposer(
  BuildContext context,
  WidgetRef ref, {
  ComposerMediaIntent? media,
  PostType? type,
}) async {
  if (!AuthRequiredGuard.canWriteWithRef(ref)) {
    await showAuthRequiredSheet(context, ref);
    return;
  }
  if (!context.mounted) return;
  final params = <String, String>{};
  if (media != null) params['media'] = media.queryValue;
  if (type != null) params['type'] = type.persistKey;
  final route = Uri(
    path: AppRoutes.socialComposer,
    queryParameters: params.isEmpty ? null : params,
  ).toString();
  context.push(route);
}

/// Tek aksiyon — yatay ikon + kısa etiket. Sade, tab/buton kalabalığı yok.
class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Padding(
          // Küçük, zarif composer aksiyon etiketi — büyük dolgulu kutu yok.
          // Yükseklik ~30 px (ikon 17 + dikey 6×2 + satır).
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.brandInk),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sağdaki küçük Paylaş butonu — composer'ı (metin odaklı) açar.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandLemon,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            AppStrings.feedComposerActionShare,
            style: TextStyle(
              color: AppColors.brandInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Medya aksiyon sheet'i — 4 mevcut işlevi listeler; seçilen intent pop ile
/// döner, çağıran composer'ı ilgili picker ile açar.
class _MediaActionSheet extends StatelessWidget {
  const _MediaActionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.xs,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Text(
              AppStrings.mediaSheetTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _MediaSheetTile(
            icon: Icons.photo_camera_rounded,
            label: AppStrings.mediaSheetCapturePhoto,
            intent: ComposerMediaIntent.capturePhoto,
          ),
          _MediaSheetTile(
            icon: Icons.photo_library_rounded,
            label: AppStrings.mediaSheetPickPhoto,
            intent: ComposerMediaIntent.pickPhoto,
          ),
          _MediaSheetTile(
            icon: Icons.videocam_rounded,
            label: AppStrings.mediaSheetCaptureVideo,
            intent: ComposerMediaIntent.captureVideo,
          ),
          _MediaSheetTile(
            icon: Icons.video_library_rounded,
            label: AppStrings.mediaSheetPickVideo,
            intent: ComposerMediaIntent.pickVideo,
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }
}

class _MediaSheetTile extends StatelessWidget {
  const _MediaSheetTile({
    required this.icon,
    required this.label,
    required this.intent,
  });

  final IconData icon;
  final String label;
  final ComposerMediaIntent intent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(intent),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.brandLemonPale,
          border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
        ),
        child: Icon(icon, size: 20, color: AppColors.brandLemonPressed),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
