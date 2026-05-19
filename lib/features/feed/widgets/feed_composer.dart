import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/post_type.dart';
import '../providers/feed_providers.dart';

/// Feed üstündeki paylaşım kompozeri.
///
/// İlk hâlinde tek satırlık bir prompt; tap edildiğinde tip chip'leri ve
/// metin alanı açılır. Paylaş → repo.addPost.
class FeedComposer extends ConsumerStatefulWidget {
  const FeedComposer({super.key});

  @override
  ConsumerState<FeedComposer> createState() => _FeedComposerState();
}

class _FeedComposerState extends ConsumerState<FeedComposer> {
  bool _expanded = false;
  PostType _type = PostType.production;
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  /// V1 Social S3 — Seçilmiş resim bytes + extension. null ise foto yok.
  Uint8List? _pickedBytes;
  String? _pickedExt;
  /// V1 Social S3 — Upload kısmen başarısızsa kullanıcıya inline uyarı.
  String? _composerError;

  static const _composerTypes = <PostType>[
    PostType.production,
    PostType.question,
    PostType.supply,
    PostType.equipment,
    PostType.job,
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    Future.microtask(() => _focus.requestFocus());
  }

  void _collapse() {
    _focus.unfocus();
    setState(() {
      _expanded = false;
      _textCtrl.clear();
      _type = PostType.production;
      _pickedBytes = null;
      _pickedExt = null;
      _composerError = null;
    });
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
        setState(() =>
            _composerError = AppStrings.feedComposerPickError);
      }
    }
  }

  void _removePickedImage() {
    setState(() {
      _pickedBytes = null;
      _pickedExt = null;
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
    // V1.3.2 — Feed post oluşturmak kullanıcı sahipliği gerektirir.
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
      final post = await repo.addPost(
        type: _type,
        author: AppStrings.feedComposerYouAuthor,
        role: AppStrings.feedComposerYouRole,
        text: text,
      );
      // V1 Social S3 — Foto eklendiyse upload at; başarısız olursa post
      // korunur, kullanıcıya uyarı verilir (kısmi başarı).
      var uploadFailed = false;
      final bytes = _pickedBytes;
      final ext = _pickedExt;
      if (bytes != null && ext != null) {
        try {
          await repo.uploadFeedImage(
            postId: post.id,
            bytes: bytes,
            fileExtension: ext,
          );
        } catch (_) {
          uploadFailed = true;
        }
      }
      if (!mounted) return;
      setState(() {
        _expanded = false;
        _textCtrl.clear();
        _type = PostType.production;
        _pickedBytes = null;
        _pickedExt = null;
      });
      _focus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadFailed
              ? AppStrings.feedComposerUploadError
              : AppStrings.feedComposerSavedSnack),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _composerError = AppStrings.feedPostCreateError);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.s,
        AppSpacing.pageH,
        AppSpacing.s,
      ),
      child: _expanded
          ? PremiumCard(
              padding: EdgeInsets.zero,
              child: _buildExpanded(context),
            )
          : PremiumCard(
              padding: EdgeInsets.zero,
              onTap: _expand,
              child: _buildCollapsed(context),
            ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softGold, AppColors.copperMuted],
                ),
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              alignment: Alignment.center,
              child: const Text(
                'M',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            const Expanded(
              child: Text(
                AppStrings.feedComposerPrompt,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.copper.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(
                  color: AppColors.copper.withValues(alpha: 0.32),
                  width: 0.6,
                ),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.softGold,
                size: 18,
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                AppStrings.feedComposerTypeLabel,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: AppStrings.feedComposerCancel,
                onPressed: _saving ? null : _collapse,
                icon: const Icon(Icons.close_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _composerTypes)
                ChoiceChip(
                  avatar: Icon(
                    t.icon,
                    size: 14,
                    color: _type == t ? AppColors.textPrimary : t.accent,
                  ),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _textCtrl,
            focusNode: _focus,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: AppStrings.feedComposerExpandHint,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // V1 Social S3 — Resim preview (varsa) + foto ekle/kaldır CTA.
          if (_pickedBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Image.memory(
                _pickedBytes!,
                fit: BoxFit.cover,
                height: 180,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _removePickedImage,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(AppStrings.feedComposerRemovePhoto),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text(AppStrings.feedComposerAddPhoto),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.softGold,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          if (_composerError != null) ...[
            const SizedBox(height: AppSpacing.s),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: 8,
              ),
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
                    size: 16,
                    color: AppColors.danger,
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
          const SizedBox(height: AppSpacing.m),
          // Sağa hizalı paylaş butonu. Önceki sürüm `Row(Spacer + SizedBox(height: 44, child: FilledButton.icon))`
          // kullanıyordu — SizedBox height-only olduğundan FilledButton'a Row'dan gelen width-constraint'i
          // intrinsic-width fazında olduğu gibi geçiyor ve "BoxConstraints forces an infinite width" atıyordu.
          // Yeni düzen: Row mainAxisAlignment.end + ButtonStyle minimumSize: (0, 44). Tasarım aynı, hatayı kapatır.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text(AppStrings.feedComposerSubmit),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
