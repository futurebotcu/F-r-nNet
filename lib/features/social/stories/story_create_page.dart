// FırınNet Social V2 Commit 2 — Story create page.
//
// Donor `lib/stories/widgets/stories_carousel.dart` + `stories_editor`
// muadili. FırınNet adaptasyonu:
//   * Donor `stories_editor` paketi (kompleks sticker/text overlay) ALMA.
//     V1 sade: galeri'den image picker + preview + Paylaş.
//   * Instagram gradient ring zorlaması YOK; sade FırınNet kart.
//   * 24h expiry bilgisi açıkça gösterilir.
//   * Auth guard: guest → giriş CTA.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../providers/social_providers.dart';

class SocialStoryCreatePage extends ConsumerStatefulWidget {
  const SocialStoryCreatePage({super.key});

  @override
  ConsumerState<SocialStoryCreatePage> createState() =>
      _SocialStoryCreatePageState();
}

class _SocialStoryCreatePageState
    extends ConsumerState<SocialStoryCreatePage> {
  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _saving = false;
  String? _inlineError;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final name = x.name;
      final dot = name.lastIndexOf('.');
      final ext = (dot >= 0 && dot < name.length - 1)
          ? name.substring(dot + 1).toLowerCase()
          : 'jpg';
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
        actions: [
          if (hasPicked)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s),
              child: FilledButton(
                onPressed: _saving ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.xs,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        AppStrings.storyCreateShareCta,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
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
                    FilledButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text(
                        AppStrings.storyCreatePickCta,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.copper,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                          vertical: AppSpacing.s,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.m),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Image.memory(
                    _pickedBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _pickedBytes = null;
                                _pickedExt = null;
                              });
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Değiştir'),
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
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
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
