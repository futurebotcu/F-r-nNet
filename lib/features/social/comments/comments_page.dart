import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/social_comment.dart';
import '../providers/social_providers.dart';

/// FırınNet Social — Comments Page (donor-first rebuild).
///
/// Donor (itsezlife flutter-instagram-offline-first-clone) `CommentsPage`
/// pattern'ından port: **full Scaffold + DraggableScrollableSheet**.
/// Mevcut `FeedCommentSheet` `isScrollControlled: true` modunda
/// `Column(mainAxisSize.min) + Flexible(child: list)` çakışmasından
/// dolayı layout assertion fail ediyor; sheet hiç çizilmiyordu.
///
/// Donor pattern'i adapte edildi:
///   * `DraggableScrollableSheet` (initialChildSize: 0.85) → bounded
///     height.
///   * İçeride `Scaffold` → `appBar` + `bottomNavigationBar` (composer)
///     + `body` (CommentsList). Scaffold bound layout sağlar.
///   * `bottomNavigationBar` slot keyboard inset'i otomatik yönetir
///     (Scaffold + resizeToAvoidBottomInset).
///
/// PowerSync/BLoC alınmadı — Riverpod ile elle port. Mevcut sıkı RLS
/// pattern korunur; `feed_comments` tablosu kullanılır (yeni migration
/// yok).
class SocialCommentsPage extends ConsumerWidget {
  const SocialCommentsPage({super.key, required this.postId});

  final String postId;

  /// Donor `context.showScrollableModal()` helper'ından esinli.
  /// DraggableScrollableSheet ile bottom sheet açar; içeride
  /// `SocialCommentsPage` Scaffold çalışır.
  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Material(
          color: AppColors.elevatedCard,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SocialCommentsPage(postId: postId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(socialCommentsProvider(postId));
    final user = ref.watch(currentAuthUserProvider);
    return Scaffold(
      backgroundColor: AppColors.elevatedCard,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: AppSpacing.s),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              AppStrings.feedCommentSheetTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            const Divider(height: 0, color: AppColors.borderHairline),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _CommentComposer(
          postId: postId,
          guest: user == null,
        ),
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Center(
            child: Text(
              AppStrings.feedCommentErrorGeneric,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: Text(
                  user == null
                      ? AppStrings.feedCommentEmptyGuest
                      : AppStrings.feedCommentEmpty,
                  style:
                      const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.s),
            itemBuilder: (_, i) {
              final c = items[i];
              final isOwn = user != null && c.ownerId == user.id;
              return _CommentRow(
                comment: c,
                isOwn: isOwn,
                postId: postId,
              );
            },
          );
        },
      ),
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({
    required this.comment,
    required this.isOwn,
    required this.postId,
  });

  final SocialComment comment;
  final bool isOwn;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border:
            Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isOwn
                      ? AppStrings.feedCommentOwnLabel
                      : comment.authorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwn)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => _confirmAndDelete(context, ref),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minHeight: 28,
                    minWidth: 28,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            comment.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.elevatedCard,
        content: const Text(AppStrings.feedCommentDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.feedCommentCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text(AppStrings.feedCommentDeleteCta),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(socialCommentsRepositoryProvider);
    try {
      await repo
          .deleteComment(comment.id)
          .timeout(const Duration(seconds: 15));
      // Provider tick yorum listesini yeniden çeker → silinen yorum
      // listeden düşer.
    } catch (_) {
      // Best-effort; üst sheet zaten kapalı/açık; ek hata mesajı gerekirse
      // _CommentComposer'a yansıtılabilir. V1: sessiz fallback yok ama
      // bu basit ack — provider zaten refresh ediyor.
    }
  }
}

/// Donor pattern: Scaffold.bottomNavigationBar slot'unda composer.
/// Bu sayede yumuşak klavye açıldığında composer üstte sabit; Scaffold
/// `resizeToAvoidBottomInset` davranışı otomatik.
class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({
    required this.postId,
    required this.guest,
  });

  final String postId;
  final bool guest;

  @override
  ConsumerState<_CommentComposer> createState() =>
      _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _inlineError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = AppStrings.feedCommentEmptyError);
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _sending = true;
      _inlineError = null;
    });
    final repo = ref.read(socialCommentsRepositoryProvider);
    try {
      await repo
          .addComment(postId: widget.postId, text: text)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      _ctrl.clear();
      // Provider tick listede yeni yorumu getirecek; ek snackbar yok.
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = _humanizeError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('failed host') ||
        s.contains('network') ||
        s.contains('timeout')) {
      return AppStrings.feedCommentErrorNetwork;
    }
    return AppStrings.feedCommentErrorSubmit;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guest) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.s,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: () => showAuthRequiredSheet(context, ref),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text(AppStrings.feedCommentGuestCta),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.copper,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_inlineError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 10,
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
                    _inlineError!,
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
        const Divider(height: 0, color: AppColors.borderHairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    hintText: AppStrings.feedCommentComposerHint,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.icon(
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                onPressed: _sending ? null : _onSend,
                label: const Text(AppStrings.feedCommentSendCta),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
