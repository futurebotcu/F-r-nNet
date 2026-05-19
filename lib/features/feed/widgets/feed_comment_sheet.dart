import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/feed_comment.dart';
import '../providers/feed_providers.dart';

/// V1 P1-B — Feed yorum bottom sheet'i.
///
/// Akış:
/// - List: `feedCommentsProvider(postId)` — Loading / Error / Empty / Data
/// - Composer (auth): doğrudan `repo.addComment` → provider invalidate
/// - Composer (guest): AuthRequiredSheet
/// - Owner yorum: kart üzerinde "Sil" sheet aksiyonu (soft delete)
class FeedCommentSheet extends ConsumerStatefulWidget {
  const FeedCommentSheet({super.key, required this.postId});

  final String postId;

  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => FeedCommentSheet(postId: postId),
    );
  }

  @override
  ConsumerState<FeedCommentSheet> createState() => _FeedCommentSheetState();
}

class _FeedCommentSheetState extends ConsumerState<FeedCommentSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  /// V1 — Yorum sheet UX hardening: snackbar bottom sheet'in altında kaldığı
  /// için kullanıcıya görünmüyordu; hata ve doğrulama mesajlarını sheet
  /// içinde inline gösteririz. Başarı için snackbar yerine input clear +
  /// listede beliren yeni yorum yeterli görsel geri bildirim.
  String? _inlineError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSendPressed() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = AppStrings.feedCommentEmptyError);
      return;
    }
    final canWrite = AuthRequiredGuard.canWriteWithRef(ref);
    if (!canWrite) {
      await showAuthRequiredSheet(context, ref);
      return;
    }
    setState(() {
      _sending = true;
      _inlineError = null;
    });
    final repo = ref.read(feedRepositoryProvider);
    final profile = ref.read(profileControllerProvider);
    try {
      // V1 P0 — `_sending=true` stuck kalmasın diye timeout. Network hang
      // veya yavaş cevap durumunda 30s sonra TimeoutException atar; catch
      // yakalar; finally _sending=false yapar.
      await repo
          .addComment(
            postId: widget.postId,
            text: text,
            currentAuthorName: profile?.displayName,
            currentAuthorRole: profile?.roleBadge,
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      _ctrl.clear();
      ref.invalidate(feedCommentsProvider(widget.postId));
      // Başarı için snackbar AÇILMAZ — sheet üstünden görünmeyecek. Yeni
      // yorum listede ascending sort ile dipte beliriyor; bu yeterli
      // görsel geri bildirim.
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

  /// Ham exception'ı kullanıcıya anlamlı Türkçe mesaja çevirir. Network
  /// kategorisi ayrı tutulur; geri kalanı generic submit hatası.
  String _humanizeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('timeoutexception') ||
        s.contains('clientexception')) {
      return AppStrings.feedCommentErrorNetwork;
    }
    return AppStrings.feedCommentErrorSubmit;
  }

  Future<void> _onDeletePressed(FeedComment c) async {
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(AppStrings.feedCommentDeleteCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(feedRepositoryProvider);
    try {
      await repo.deleteComment(c.id);
      if (!mounted) return;
      ref.invalidate(feedCommentsProvider(widget.postId));
      // Başarı snackbar'ı sheet altında görünmez — silinen yorum listeden
      // kaybolur, bu yeterli görsel geri bildirim.
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = _humanizeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedCommentsProvider(widget.postId));
    final user = ref.watch(currentAuthUserProvider);
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    // V1 Comment Reality Fix — Donor pattern (instagram clone) sheet'i
    // full Scaffold + DraggableScrollableSheet ile kuruyor. Bizim sheet
    // `Column(mainAxisSize: min) + Flexible(...)` deseni
    // `isScrollControlled: true` modunda **unbounded height** alıyor ve
    // `RenderFlex children have non-zero flex but incoming height
    // constraints are unbounded` assertion'ı ile sheet'i hiç çizmiyordu —
    // emülatörde yorum butonuna tıklayınca yalnız dim arka plan kalıyor,
    // sheet açılmıyordu.
    //
    // Minimum fix: dış sarmayı ekranın %85'ine sabitle. İçerideki
    // `Flexible(child: list)` artık bounded → ListView/loading/empty
    // düzgün çiziliyor. Donor'un DraggableScrollableSheet'i daha esnek
    // (drag-to-resize) ama V1 için fixed-height yeterli.
    final sheetHeight = (mq.size.height - mq.padding.top) * 0.85;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
            // Sheet handle + başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.m,
                AppSpacing.l,
                0,
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.s),
                      decoration: BoxDecoration(
                        color: AppColors.borderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    AppStrings.feedCommentSheetTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            const Divider(height: 0, color: AppColors.borderHairline),
            // Liste
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    AppStrings.feedCommentErrorGeneric,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        user == null
                            ? AppStrings.feedCommentEmptyGuest
                            : AppStrings.feedCommentEmpty,
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
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
                        onDelete: isOwn ? () => _onDeletePressed(c) : null,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 0, color: AppColors.borderHairline),
            // V1 — Inline error banner: snackbar bottom sheet'in altında
            // görünmediği için, validation/submit/network hataları burada
            // görünür kalır.
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
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Composer — auth user için TextField + send; guest için CTA.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: user == null
                  ? _GuestComposerCta(
                      onLogin: () => showAuthRequiredSheet(context, ref),
                    )
                  : Row(
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
                            onSubmitted: (_) => _onSendPressed(),
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
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white)),
                                )
                              : const Icon(Icons.send_rounded, size: 16),
                          onPressed: _sending ? null : _onSendPressed,
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
          ),
        ),
      ),
    );
  }
}

/// V1 — Guest kullanıcı için composer alanı: TextField yerine "Giriş yap"
/// CTA. Sheet okuma için açık kalır (mevcut yorumları görür), ama yazma
/// girişimi auth bottom sheet'e yönlendirilir.
class _GuestComposerCta extends StatelessWidget {
  const _GuestComposerCta({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login_rounded, size: 16),
        label: const Text(AppStrings.feedCommentGuestCta),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.copper,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.isOwn,
    required this.onDelete,
  });

  final FeedComment comment;
  final bool isOwn;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
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
                  isOwn ? AppStrings.feedCommentOwnLabel : comment.authorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onDelete,
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
}
