// FırınNet — Donor-first SocialComposerPage (port from
// `flutter-instagram-offline-first-clone`, MIT, see THIRD_PARTY_NOTICES.md).
//
// Donor: lib/user_profile/widgets/user_profile_create_post.dart +
// lib/feed/post/widgets/share_post.dart (CreatePostPage). Donor pattern:
//   * Step 1: media picker (PickImage().customMediaPicker())
//   * Step 2: caption editor + publish button
//   * Bottom "Share" button bar
//
// FırınNet adaptasyonu:
//   * Single page (steps birleşik, donor multi-step modal sheet'i tam ekran).
//   * `image_picker` (gallery) — donor `image_picker_plus` paketi alınmadı.
//   * `feedRepositoryProvider.addPost(...)` + `uploadFeedImage(...)`.
//   * Upload fail → text post rollback (silent text-only fallback YOK).
//   * Type chips FırınNet'e özgü (Üretim / Soru / Tedarik / Ekipman / İş).
//
// Eski `lib/features/feed/widgets/feed_composer.dart` (SliverToBoxAdapter
// olarak feed üstüne gömülüydü) artık kullanılmaz; F-cleanup commit'inde
// silinir.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/models/post_type.dart';
import '../../feed/providers/feed_providers.dart';

class SocialComposerPage extends ConsumerStatefulWidget {
  const SocialComposerPage({super.key});

  @override
  ConsumerState<SocialComposerPage> createState() =>
      _SocialComposerPageState();
}

class _SocialComposerPageState extends ConsumerState<SocialComposerPage> {
  /// V2 Commit 3 — Tek post'a tek media (image VEYA video). Multi-image
  /// veya image+video kombosu V3'e bırakıldı.
  static const int _maxVideoBytes = 50 * 1024 * 1024; // 50 MB
  static const Duration _maxVideoDuration = Duration(seconds: 60);

  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  PostType _type = PostType.production;
  bool _saving = false;

  // Image picked
  Uint8List? _pickedBytes;
  String? _pickedExt;

  // V2 Commit 3 — Video picked (image ile mutually exclusive)
  Uint8List? _pickedVideoBytes;
  String? _pickedVideoExt;
  int? _pickedVideoDurationMs;

  String? _composerError;

  static const _types = <PostType>[
    PostType.production,
    PostType.question,
    PostType.supply,
    PostType.equipment,
    PostType.job,
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

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
        _composerError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _composerError = AppStrings.feedComposerPickError);
      }
    }
  }

  void _removePickedImage() {
    setState(() {
      _pickedBytes = null;
      _pickedExt = null;
    });
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: _maxVideoDuration,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > _maxVideoBytes) {
        if (mounted) {
          setState(() =>
              _composerError = AppStrings.composerVideoTooLargeError);
        }
        return;
      }
      final name = x.name;
      final dot = name.lastIndexOf('.');
      final ext = (dot >= 0 && dot < name.length - 1)
          ? name.substring(dot + 1).toLowerCase()
          : 'mp4';
      if (!mounted) return;
      // Image ve video mutually exclusive — biri seçilince diğeri sıfırlanır.
      setState(() {
        _pickedVideoBytes = bytes;
        _pickedVideoExt = ext;
        _pickedBytes = null;
        _pickedExt = null;
        _composerError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _composerError = AppStrings.composerVideoPickError,
        );
      }
    }
  }

  void _removePickedVideo() {
    setState(() {
      _pickedVideoBytes = null;
      _pickedVideoExt = null;
      _pickedVideoDurationMs = null;
    });
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.feedComposerEmptyErr)),
      );
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _saving = true;
      _composerError = null;
    });
    final repo = ref.read(feedRepositoryProvider);
    try {
      final post = await repo
          .addPost(
            type: _type,
            author: AppStrings.feedComposerYouAuthor,
            role: AppStrings.feedComposerYouRole,
            text: text,
          )
          .timeout(const Duration(seconds: 30));
      final bytes = _pickedBytes;
      final ext = _pickedExt;
      final videoBytes = _pickedVideoBytes;
      final videoExt = _pickedVideoExt;
      if (bytes != null && ext != null) {
        try {
          await repo
              .uploadFeedImage(
                postId: post.id,
                bytes: bytes,
                fileExtension: ext,
              )
              .timeout(const Duration(seconds: 60));
        } catch (_) {
          try {
            await repo.deletePost(post.id);
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _saving = false;
            _composerError = AppStrings.feedComposerUploadError;
          });
          return;
        }
      } else if (videoBytes != null && videoExt != null) {
        // V2 Commit 3 — Video upload (image ile mutually exclusive).
        try {
          await repo
              .uploadFeedVideo(
                postId: post.id,
                bytes: videoBytes,
                fileExtension: videoExt,
                durationMs: _pickedVideoDurationMs,
              )
              .timeout(const Duration(seconds: 120));
        } catch (_) {
          try {
            await repo.deletePost(post.id);
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _saving = false;
            _composerError = AppStrings.composerVideoUploadError;
          });
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.feedComposerSavedSnack)),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _composerError = AppStrings.feedPostCreateError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.elevatedCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textPrimary,
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text(
          'Yeni Gönderi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: FilledButton(
              onPressed: _saving ? null : _submit,
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
                      AppStrings.feedComposerSubmit,
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
            vertical: AppSpacing.m,
          ),
          children: [
            if (_pickedBytes != null)
              _MediaPreview(
                bytes: _pickedBytes!,
                onRemove: _removePickedImage,
              ),
            if (_pickedVideoBytes != null)
              _VideoPickedPreview(
                bytes: _pickedVideoBytes!,
                onRemove: _removePickedVideo,
              ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _textCtrl,
              focusNode: _focus,
              minLines: 4,
              maxLines: 12,
              maxLength: 1200,
              enabled: !_saving,
              decoration: const InputDecoration(
                hintText: AppStrings.feedComposerExpandHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.feedComposerTypeLabel,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = t == _type;
                return ChoiceChip(
                  selected: selected,
                  selectedColor: t.accent.withValues(alpha: 0.20),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: selected
                        ? t.accent
                        : AppColors.borderHairline,
                    width: selected ? 1.0 : 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 14, color: t.accent),
                      const SizedBox(width: 4),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: selected
                              ? t.accent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.m),
            // V2 Commit 3 — Image ve video butonları yan yana; mutually
            // exclusive (biri seçilince diğeri sıfırlanır).
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _pickedBytes == null ? 'Foto ekle' : 'Foto değiştir',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(
                        color: AppColors.borderHairline,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickVideo,
                    icon: const Icon(
                      Icons.videocam_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _pickedVideoBytes == null
                          ? AppStrings.composerPickVideoCta
                          : AppStrings.composerPickVideoChangeCta,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(
                        color: AppColors.borderHairline,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.s),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_composerError != null) ...[
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
                        _composerError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12.5,
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

/// V2 Commit 3 — Video preview kartı. Composer'da seçilen video'nun
/// preview'ı için sade kart (thumbnail üretimi V3'e bırakıldı; şimdilik
/// dosya ikonu + bilgi).
class _VideoPickedPreview extends StatelessWidget {
  const _VideoPickedPreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: AppColors.borderHairline,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: const Icon(
              Icons.play_circle_outlined,
              color: AppColors.softGold,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video seçildi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _humanSize(bytes.length),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
            tooltip: AppStrings.composerRemoveVideoCta,
          ),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: AppSpacing.s,
            right: AppSpacing.s,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
