import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../jobs/models/job_offer_post.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../messaging/repositories/messaging_repository.dart';
import '../../worker/models/job_seek_post.dart';

/// V1 — Job ilanına başvurmak / iş arayanla iletişime geçmek için
/// ilk mesajı yazdıran bottom sheet.
///
/// Sprint D (C-1) — Artık LEGACY job_conversations değil, GENERIC messaging
/// sistemi kullanılır. Akış:
/// 1. Auth yoksa AuthRequiredSheet (inner repo guarded;
///    GuestActionRequiredException yakalanır).
/// 2. Trim'li body 1..1000 karakter.
/// 3. Generic `findOrCreateDirectConversation` (contextType job_offer/job_seek,
///    contextId = ilan id) ile conversation açılır/yeniden bulunur.
/// 4. İlk mesaj generic `sendTextMessage` ile yazılır.
/// 5. /messages/:id (generic ChatScreen) ekranına push + başarı snackbar'ı.
class StartJobConversationSheet extends ConsumerStatefulWidget {
  const StartJobConversationSheet._({this.offer, this.seekPost})
    : assert(
        (offer != null) ^ (seekPost != null),
        'Tam olarak bir hedef post verilmeli.',
      );

  final JobOfferPost? offer;
  final JobSeekPost? seekPost;

  static Future<void> showForOffer(BuildContext context, JobOfferPost offer) =>
      _open(context, StartJobConversationSheet._(offer: offer));

  static Future<void> showForSeek(BuildContext context, JobSeekPost post) =>
      _open(context, StartJobConversationSheet._(seekPost: post));

  static Future<void> _open(BuildContext context, Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => child,
    );
  }

  @override
  ConsumerState<StartJobConversationSheet> createState() =>
      _StartJobConversationSheetState();
}

class _StartJobConversationSheetState
    extends ConsumerState<StartJobConversationSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  bool get _isOffer => widget.offer != null;
  String get _title => _isOffer
      ? AppStrings.startConvoSheetTitleOffer
      : AppStrings.startConvoSheetTitleSeek;
  String get _subtitle => _isOffer
      ? AppStrings.startConvoSheetSubtitleOffer
      : AppStrings.startConvoSheetSubtitleSeek;
  String get _relatedTitle =>
      _isOffer ? widget.offer!.title : widget.seekPost!.title;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSendPressed() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startConvoEmptyError)),
      );
      return;
    }

    // C-1 (Sprint D) — Job mesajlaşması artık LEGACY job_conversations değil,
    // GENERIC conversations/messages sistemine bağlı. İlgili ilan id'si
    // contextId, tip job_offer/job_seek olarak generic RPC'ye gider; ilk
    // mesaj generic sendTextMessage ile yazılır ve kullanıcı /messages/:id
    // (generic ChatScreen) ekranına gider — boş/yanlış sohbete düşmez.
    final ownerId = _isOffer ? widget.offer!.ownerId : widget.seekPost!.ownerId;
    final postId = _isOffer ? widget.offer!.id : widget.seekPost!.id;
    final contextType = _isOffer ? 'job_offer' : 'job_seek';
    final me = ref.read(currentAuthUserProvider)?.id;

    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startConvoGenericError)),
      );
      return;
    }
    // Kendi ilanı / eksik sahip → mesaj başlatma (generic RPC de reddeder;
    // burada erken ve net feedback ver).
    if (ownerId == null || ownerId == me) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startConvoOwnPostError)),
      );
      return;
    }

    setState(() => _sending = true);
    final repo = ref.read(messagingRepositoryProvider);
    try {
      final convId = await repo.findOrCreateDirectConversation(
        otherUserId: ownerId,
        contextType: contextType,
        contextId: postId,
      );
      // İlk mesaj generic messages akışına yazılır (kaybolmaz).
      await repo.sendTextMessage(conversationId: convId, content: body);
      ref.invalidate(conversationsListProvider);
      ref.invalidate(messagesListProvider(convId));
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/messages/$convId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startConvoOpenedSnack)),
      );
    } on GuestActionRequiredException {
      if (mounted) {
        Navigator.of(context).pop();
        await showAuthRequiredSheet(context, ref);
      }
    } on BlockedConversationException {
      // UGC Safety V1.1 — çift yön engel: engellenenle DM açılamaz.
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(AppStrings.blockedMessageStartBanner)),
        );
      }
    } catch (_) {
      // Hata → sheet açık kalır, metin korunur, kullanıcı tekrar deneyebilir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.startConvoGenericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
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
              Text(
                _title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _relatedTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: AppStrings.conversationComposerHint,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.surface,
                            ),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  onPressed: _sending ? null : _onSendPressed,
                  label: const Text(AppStrings.startConvoSendCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
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
