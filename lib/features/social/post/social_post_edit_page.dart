// FırınNet — Donor-first SocialPostEditPage (V2 Social Core).
//
// Donor: `posts_repository.updatePost(id, caption)` + donor `AppRoutes.postEdit`.
// FırınNet pattern: tam ekran route /social/post/:postId/edit; mevcut metin
// dolu gelir, kullanıcı düzenler + tags düzenler + Kaydet.
//
// Twitter/Facebook UX: metin alanı 17 px, geniş + üstte avatar + altta tag
// chip'leri. Composer ile benzer dil.
//
// Hardening: `feedRepositoryProvider.updatePost` Supabase tarafında
// `.select(...)` ile boş satır kontrolü yapar → StateError fırlatır →
// catch dalı snackbar gösterir. Sahte success YOK.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../feed/providers/feed_providers.dart';

class SocialPostEditPage extends ConsumerStatefulWidget {
  const SocialPostEditPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<SocialPostEditPage> createState() =>
      _SocialPostEditPageState();
}

class _SocialPostEditPageState extends ConsumerState<SocialPostEditPage> {
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _initialized = false;
  bool _saving = false;
  String? _inlineError;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = AppStrings.postEditEmptyError);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    debugPrint('[FirinNet][PostEdit] save tap postId=${widget.postId}');
    final repo = ref.read(feedRepositoryProvider);
    try {
      await repo
          .updatePost(postId: widget.postId, text: text)
          .timeout(const Duration(seconds: 30));
      debugPrint(
        '[FirinNet][PostEdit] save success postId=${widget.postId}',
      );
      if (!mounted) return;
      // V2: feedPagedNotifier + post detail header refresh.
      ref.invalidate(feedPagedNotifierProvider);
      ref.invalidate(feedPostByIdProvider(widget.postId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.postEditSavedSnack)),
      );
      context.pop();
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugPrint('[FirinNet][PostEdit] save error: $e');
      if (mounted) {
        setState(() => _inlineError = AppStrings.postEditError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(feedPostByIdProvider(widget.postId));
    final user = ref.watch(currentAuthUserProvider);
    // Mevcut metni TextField'a dolduran tek seferlik init.
    postAsync.whenData((post) {
      if (post != null && !_initialized) {
        _textCtrl.text = post.text;
        _initialized = true;
      }
    });
    final post = postAsync.maybeWhen(data: (p) => p, orElse: () => null);
    final isOwner = user != null && post != null && user.id == post.ownerId;
    return PremiumScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.elevatedCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 26),
          color: AppColors.textPrimary,
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text(
          AppStrings.postEditTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: FilledButton(
              onPressed: (_saving || !isOwner) ? null : _save,
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
                      AppStrings.postEditSaveCta,
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
        child: postAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                AppStrings.postEditError,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (post) {
            if (post == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'Bu gönderi artık görünür değil.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              );
            }
            if (!isOwner) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'Sadece kendi gönderini düzenleyebilirsin.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
                vertical: AppSpacing.m,
              ),
              children: [
                TextField(
                  controller: _textCtrl,
                  focusNode: _focus,
                  minLines: 6,
                  maxLines: 16,
                  maxLength: 1200,
                  enabled: !_saving,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: AppStrings.feedComposerExpandHint,
                    border: OutlineInputBorder(),
                  ),
                ),
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
            );
          },
        ),
      ),
    );
  }
}
