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
// V2 Commit 4 cleanup — eski FeedComposer (SliverToBoxAdapter) tamamen
// silindi; bu page donor-first composer'ın tek girişi.

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

  Future<void> _pickImage() => _captureOrPickImage(ImageSource.gallery);
  Future<void> _capturePhoto() => _captureOrPickImage(ImageSource.camera);

  Future<void> _captureOrPickImage(ImageSource source) async {
    debugPrint('[FirinNet][Composer] pickImage source=$source');
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (x == null) {
        debugPrint('[FirinNet][Composer] pickImage cancelled');
        return;
      }
      final bytes = await x.readAsBytes();
      // V2 Commit 3.6 — Sağlam ext: bilinen image extension'ları + fallback.
      final ext = _extractImageExt(x.name, x.path);
      debugPrint(
        '[FirinNet][Composer] pickImage got name=${x.name} ext=$ext '
        'bytes=${bytes.length}',
      );
      if (!mounted) return;
      // Image ve video mutually exclusive — biri seçilince diğeri sıfırlanır.
      setState(() {
        _pickedBytes = bytes;
        _pickedExt = ext;
        _pickedVideoBytes = null;
        _pickedVideoExt = null;
        _pickedVideoDurationMs = null;
        _composerError = null;
      });
    } catch (e) {
      debugPrint('[FirinNet][Composer] pickImage error: $e');
      if (mounted) {
        setState(() => _composerError = AppStrings.feedComposerPickError);
      }
    }
  }

  static String _extractImageExt(String name, String path) {
    const known = <String>{'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    String fromCandidate(String c) {
      final dot = c.lastIndexOf('.');
      if (dot <= 0 || dot >= c.length - 1) return '';
      return c.substring(dot + 1).toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
    }
    final fromName = fromCandidate(name);
    if (known.contains(fromName)) return fromName;
    final fromPath = fromCandidate(path);
    if (known.contains(fromPath)) return fromPath;
    return 'jpg';
  }

  void _removePickedImage() {
    setState(() {
      _pickedBytes = null;
      _pickedExt = null;
    });
  }

  Future<void> _pickVideo() => _captureOrPickVideo(ImageSource.gallery);
  Future<void> _captureVideo() => _captureOrPickVideo(ImageSource.camera);

  Future<void> _captureOrPickVideo(ImageSource source) async {
    debugPrint('[FirinNet][Composer] pickVideo source=$source');
    try {
      final picker = ImagePicker();
      final x = await picker.pickVideo(
        source: source,
        maxDuration: _maxVideoDuration,
      );
      if (x == null) {
        debugPrint('[FirinNet][Composer] pickVideo cancelled');
        return;
      }
      final bytes = await x.readAsBytes();
      if (bytes.length > _maxVideoBytes) {
        debugPrint(
          '[FirinNet][Composer] pickVideo too large bytes=${bytes.length}',
        );
        if (mounted) {
          setState(() =>
              _composerError = AppStrings.composerVideoTooLargeError);
        }
        return;
      }
      final ext = _extractVideoExt(x.name, x.path);
      debugPrint(
        '[FirinNet][Composer] pickVideo got name=${x.name} ext=$ext '
        'bytes=${bytes.length}',
      );
      if (!mounted) return;
      // Image ve video mutually exclusive — biri seçilince diğeri sıfırlanır.
      setState(() {
        _pickedVideoBytes = bytes;
        _pickedVideoExt = ext;
        _pickedBytes = null;
        _pickedExt = null;
        _composerError = null;
      });
    } catch (e) {
      debugPrint('[FirinNet][Composer] pickVideo error: $e');
      if (mounted) {
        setState(
          () => _composerError = AppStrings.composerVideoPickError,
        );
      }
    }
  }

  static String _extractVideoExt(String name, String path) {
    const known = <String>{'mp4', 'm4v', 'mov', 'webm', '3gp'};
    String fromCandidate(String c) {
      final dot = c.lastIndexOf('.');
      if (dot <= 0 || dot >= c.length - 1) return '';
      return c.substring(dot + 1).toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
    }
    final fromName = fromCandidate(name);
    if (known.contains(fromName)) return fromName;
    final fromPath = fromCandidate(path);
    if (known.contains(fromPath)) return fromPath;
    return 'mp4';
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

  /// V2 Commit 3.5 — Composer "share-ready" mı?
  /// Metin VEYA medya (image/video) varsa true. CTA enabled/disabled
  /// state'i bu flag'e bağlı (boş tıklamayla snackbar yerine sessiz
  /// disabled görünüm).
  bool get _canShare {
    if (_saving) return false;
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final hasMedia = _pickedBytes != null || _pickedVideoBytes != null;
    return hasText || hasMedia;
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
        ),
      ),
      // V2 Commit 3.5 — Sticky bottom "Paylaş" CTA. Donor `share_post.dart`
      // `PublishPostButton` muadili. AppBar action'da küçük buton yerine
      // ekran altında büyük, görünür, parmağa yakın primary CTA.
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
              onPressed: _canShare ? _submit : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _saving
                    ? AppStrings.composerSharingCta
                    : AppStrings.composerShareCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copper,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.copper.withValues(alpha: 0.35),
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.7),
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
            vertical: AppSpacing.m,
          ),
          children: [
            // V2 Commit 3.5 — Composer prompt headline (Twitter/Facebook
            // "What's happening?" muadili FırınNet dilinde).
            const Text(
              AppStrings.composerPromptHeadline,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
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
            if (_pickedBytes != null || _pickedVideoBytes != null)
              const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _textCtrl,
              focusNode: _focus,
              minLines: 4,
              maxLines: 12,
              maxLength: 1200,
              enabled: !_saving,
              // V2 Commit 3.5 — onChanged setState ile sticky Paylaş
              // CTA disabled→enabled state'i güncellenir.
              onChanged: (_) => setState(() {}),
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
            // V2 Commit 3.5 — Medya section label + 4-buton 2x2 grid.
            // Donor `selector` + image_picker_plus muadili: galeri seç /
            // anlık çek için ayrı butonlar (foto + video).
            const Text(
              AppStrings.composerMediaSectionLabel,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            // İlk satır: Foto seç + Foto çek
            Row(
              children: [
                Expanded(
                  child: _MediaButton(
                    icon: Icons.photo_library_outlined,
                    label: AppStrings.composerPickPhotoCta,
                    enabled: !_saving,
                    onPressed: _pickImage,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.photo_camera_outlined,
                    label: AppStrings.composerCapturePhotoCta,
                    enabled: !_saving,
                    onPressed: _capturePhoto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            // İkinci satır: Video seç + Video çek
            Row(
              children: [
                Expanded(
                  child: _MediaButton(
                    icon: Icons.video_library_outlined,
                    label: AppStrings.composerPickVideoCta,
                    enabled: !_saving,
                    onPressed: _pickVideo,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.videocam_outlined,
                    label: AppStrings.composerCaptureVideoCta,
                    enabled: !_saving,
                    onPressed: _captureVideo,
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

/// V2 Commit 3.5 — Medya seç/çek butonu. Sade outline kart, ikon
/// üstte + label altta. Touch target ≥48 px.
class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(
              color: enabled
                  ? AppColors.borderHairline
                  : AppColors.borderHairline.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled
                    ? AppColors.softGold
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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
