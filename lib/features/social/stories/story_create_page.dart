// FırınNet Social V2 Commit 2 — Story create page.
//
// Donor `lib/stories/widgets/stories_carousel.dart` + `stories_editor`
// muadili. FırınNet adaptasyonu:
//   * Donor `stories_editor` paketi (kompleks sticker/text overlay) ALMA.
//     V1 sade: galeri'den image picker + preview + Paylaş.
//   * Instagram gradient ring zorlaması YOK; sade FırınNet kart.
//   * 24h expiry bilgisi açıkça gösterilir.
//   * Auth guard: guest → giriş CTA.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/permissions/app_permission_service.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../providers/social_providers.dart';

class SocialStoryCreatePage extends ConsumerStatefulWidget {
  const SocialStoryCreatePage({super.key});

  @override
  ConsumerState<SocialStoryCreatePage> createState() =>
      _SocialStoryCreatePageState();
}

class _SocialStoryCreatePageState extends ConsumerState<SocialStoryCreatePage> {
  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _saving = false;
  String? _inlineError;

  Future<void> _pickImage() => _captureOrPick(ImageSource.gallery);
  Future<void> _capturePhoto() async {
    // Kamera ÇEKİMİ → izin iste (galeri seçimi istemez).
    if (!await AppPermissionService.requestCameraForCapture(context)) return;
    await _captureOrPick(ImageSource.camera);
  }

  /// V2 Commit 3.6 — Story camera regression fix. ImageSource.camera
  /// dönen XFile bazı Android sürümlerinde `name` field'ını ham path
  /// olarak ya da uzantısız bir geçici dosya olarak verir; bu durumda
  /// upload `.jpg` fallback ile çalışmalı.
  ///
  /// Sağlam ext çıkarma: önce x.name'den, yoksa x.path'ten dene, en son
  /// `.jpg` fallback. Kamera iptal edilirse (x==null) sessizce dön.
  Future<void> _captureOrPick(ImageSource source) async {
    debugPrint('[FirinNet][StoryCreate] pick start source=$source');
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (x == null) {
        debugPrint('[FirinNet][StoryCreate] pick cancelled');
        return;
      }
      final bytes = await x.readAsBytes();
      final ext = _extractExt(x.name, x.path);
      debugPrint(
        '[FirinNet][StoryCreate] pick got name=${x.name} ext=$ext '
        'bytes=${bytes.length}',
      );
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pickedExt = ext;
        _inlineError = null;
      });
    } catch (e) {
      debugPrint('[FirinNet][StoryCreate] pick error: $e');
      if (mounted) {
        setState(() => _inlineError = AppStrings.storyCreatePickError);
      }
    }
  }

  /// Sağlam image extension çıkarma: name → path → 'jpg' fallback.
  /// Sadece bilinen image extension'larını kabul eder; bilinmiyorsa
  /// 'jpg' (en yaygın kamera çıktısı).
  static String _extractExt(String name, String path) {
    const known = <String>{'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    String fromCandidate(String c) {
      final dot = c.lastIndexOf('.');
      if (dot <= 0 || dot >= c.length - 1) return '';
      return c
          .substring(dot + 1)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final fromName = fromCandidate(name);
    if (known.contains(fromName)) return fromName;
    final fromPath = fromCandidate(path);
    if (known.contains(fromPath)) return fromPath;
    return 'jpg';
  }

  Future<void> _share() async {
    final bytes = _pickedBytes;
    final ext = _pickedExt;
    if (bytes == null || ext == null) return;
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    debugPrint('[FirinNet][StoryCreate] share tap bytes=${bytes.length}');
    final repo = ref.read(socialStoriesRepositoryProvider);
    try {
      final story = await repo
          .createImageStory(bytes: bytes, fileExtension: ext)
          .timeout(const Duration(seconds: 60));
      debugPrint('[FirinNet][StoryCreate] share success id=${story.id}');
      if (!mounted) return;
      ref.invalidate(socialFreshStoriesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.storyCreateSavedSnack)),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][StoryCreate] share error: $e');
      if (mounted) {
        setState(() => _inlineError = AppStrings.storyCreateUploadError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPicked = _pickedBytes != null;
    return PremiumScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.elevatedCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 26),
          color: AppColors.textPrimary,
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text(
          AppStrings.storyCreateTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
        ),
      ),
      // V2 Commit 3.5 — Sticky bottom "Hikayeyi paylaş" CTA. Donor
      // `PublishPostButton` muadili.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.m,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: (hasPicked && !_saving) ? _share : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.brandInk),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _saving ? AppStrings.storySharingCta : AppStrings.storyShareCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copper,
                foregroundColor: AppColors.brandInk,
                disabledBackgroundColor: AppColors.copper.withValues(
                  alpha: 0.35,
                ),
                disabledForegroundColor: AppColors.surface.withValues(
                  alpha: 0.7,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageH,
            vertical: AppSpacing.l,
          ),
          children: [
            if (!hasPicked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.borderHairline,
                    width: 0.6,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 44,
                      color: AppColors.softGold,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const Text(
                      AppStrings.storyAddMyHint,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      AppStrings.storyExpiresInHint,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    // V2 Commit 3.5 — Foto seç + Foto çek butonları
                    // yan yana.
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              AppStrings.storyCreatePickCta,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.copper,
                              foregroundColor: AppColors.brandInk,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _capturePhoto,
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              AppStrings.storyCapturePhotoCta,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                color: AppColors.borderHairline,
                                width: 0.8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.m),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Galeriden değiştir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _capturePhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Yeniden çek'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              const Text(
                AppStrings.storyExpiresInHint,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (_inlineError != null) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.32),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
