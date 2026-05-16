import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/services/auth_required_guard.dart';
import '../../jobs/models/job_offer_post.dart';
import '../../worker/models/job_seek_post.dart';
import '../providers/job_messaging_providers.dart';

/// V1 — Job ilanına başvurmak / iş arayanla iletişime geçmek için
/// ilk mesajı yazdıran bottom sheet.
///
/// Akış:
/// 1. Auth yoksa AuthRequiredSheet (caller pre-check yapıyor olsa bile
///    inner repo guarded; sheet build edilirse user authenticated kabul edilir).
/// 2. Trim'li body 1..1000 karakter.
/// 3. `startForJobOffer` / `startForJobSeek` çağrılır, conversation döner.
/// 4. Conversation screen'e push edilir; başarı snackbar'ı gösterilir.
class StartJobConversationSheet extends ConsumerStatefulWidget {
  const StartJobConversationSheet._({
    this.offer,
    this.seekPost,
  }) : assert(
          (offer != null) ^ (seekPost != null),
          'Tam olarak bir hedef post verilmeli.',
        );

  final JobOfferPost? offer;
  final JobSeekPost? seekPost;

  static Future<void> showForOffer(
    BuildContext context,
    JobOfferPost offer,
  ) =>
      _open(context, StartJobConversationSheet._(offer: offer));

  static Future<void> showForSeek(
    BuildContext context,
    JobSeekPost post,
  ) =>
      _open(context, StartJobConversationSheet._(seekPost: post));

  static Future<void> _open(BuildContext context, Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedCard,
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
    setState(() => _sending = true);
    final repo = ref.read(jobMessagingRepositoryProvider);
    try {
      final convo = _isOffer
          ? await repo.startForJobOffer(
              offer: widget.offer!,
              firstMessage: body,
            )
          : await repo.startForJobSeek(
              post: widget.seekPost!,
              firstMessage: body,
            );
      ref.invalidate(myJobConversationsProvider);
      if (convo.id != null) {
        ref.invalidate(jobMessagesProvider(convo.id!));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (convo.id != null) {
        context.push('/messages/${convo.id}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.startConvoOpenedSnack)),
      );
    } on GuestActionRequiredException {
      if (mounted) {
        Navigator.of(context).pop();
        await showAuthRequiredSheet(context, ref);
      }
    } on StateError catch (e) {
      if (mounted) {
        final msg = e.message.contains('Kendi ilanına')
            ? AppStrings.startConvoOwnPostError
            : AppStrings.startConvoGenericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
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
                decoration: const InputDecoration(
                  hintText: AppStrings.conversationComposerHint,
                  isDense: true,
                  border: OutlineInputBorder(),
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
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  onPressed: _sending ? null : _onSendPressed,
                  label: const Text(AppStrings.startConvoSendCta),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
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
