import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/job_conversation.dart';
import '../models/job_message.dart';
import '../providers/job_messaging_providers.dart';

/// /messages/:conversationId — sohbet ekranı.
class JobConversationScreen extends ConsumerStatefulWidget {
  const JobConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<JobConversationScreen> createState() =>
      _JobConversationScreenState();
}

class _JobConversationScreenState extends ConsumerState<JobConversationScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  JobConversation? _findConvo(List<JobConversation>? list) {
    if (list == null) return null;
    for (final c in list) {
      if (c.id == widget.conversationId) return c;
    }
    return null;
  }

  Future<void> _onSendPressed() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final repo = ref.read(jobMessagingRepositoryProvider);
    try {
      await repo.sendMessage(conversationId: widget.conversationId, body: body);
      _ctrl.clear();
      ref.invalidate(jobMessagesProvider(widget.conversationId));
      ref.invalidate(myJobConversationsProvider);
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.conversationSendError)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onCloseConversation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: const Text('Bu sohbeti kapatıyor musun? Yeni mesaj alınmaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.feedCommentCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(AppStrings.conversationCloseCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(jobMessagingRepositoryProvider);
    try {
      await repo.closeConversation(widget.conversationId);
      ref.invalidate(myJobConversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.conversationClosedSnack)),
        );
      }
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.conversationSendError)),
        );
      }
    }
  }

  Future<void> _onDeleteOwnMessage(JobMessage m) async {
    if (m.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: const Text('Bu mesajı silmek istiyor musun?'),
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
    final repo = ref.read(jobMessagingRepositoryProvider);
    try {
      await repo.softDeleteMessage(m.id!);
      ref.invalidate(jobMessagesProvider(widget.conversationId));
    } on GuestActionRequiredException {
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.conversationSendError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAuthUserProvider);
    final selfId = user?.id ?? '';
    final convoListAsync = ref.watch(myJobConversationsProvider);
    final convo = _findConvo(convoListAsync.valueOrNull);
    final messagesAsync = ref.watch(jobMessagesProvider(widget.conversationId));
    final title = convo?.relatedTitle ?? AppStrings.conversationTitleFallback;
    final isClosed = convo?.isClosed == true;

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (convo != null && !isClosed)
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: AppStrings.conversationCloseCta,
              onPressed: _onCloseConversation,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.s,
                ),
                color: AppColors.textMuted.withValues(alpha: 0.10),
                child: const Text(
                  AppStrings.conversationClosedBanner,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    AppStrings.conversationLoadError,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.l),
                        child: Text(
                          AppStrings.conversationEmptyOwn,
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s),
                    itemBuilder: (_, i) {
                      final m = items[i];
                      final isMe = m.senderId == selfId;
                      return _MessageBubble(
                        message: m,
                        isMe: isMe,
                        onDelete: (isMe && !m.isDeleted)
                            ? () => _onDeleteOwnMessage(m)
                            : null,
                      );
                    },
                  );
                },
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
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      enabled: !_sending && !isClosed,
                      decoration: InputDecoration(
                        hintText: AppStrings.conversationComposerHint,
                        isDense: true,
                        counterText: '',
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
                                AppColors.surface,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    onPressed: (_sending || isClosed) ? null : _onSendPressed,
                    label: const Text(AppStrings.conversationSendCta),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onDelete,
  });

  final JobMessage message;
  final bool isMe;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMM HH:mm', 'tr_TR');
    final bg = isMe
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.surface;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.m),
            topRight: Radius.circular(AppRadius.m),
            bottomLeft: Radius.circular(AppRadius.m),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.m),
            topRight: Radius.circular(AppRadius.m),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(AppRadius.m),
          );
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: AppShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.isDeleted
                    ? AppStrings.conversationDeletedPlaceholder
                    : message.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontStyle: message.isDeleted
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: message.isDeleted
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    message.createdAt != null
                        ? df.format(message.createdAt!)
                        : '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (onDelete != null) ...[
                    const Spacer(),
                    InkWell(
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
