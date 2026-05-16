import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/job_conversation.dart';
import '../providers/job_messaging_providers.dart';

/// /messages — kullanıcının açık olduğu tüm conversation'lar.
class MessagesListScreen extends ConsumerWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myJobConversationsProvider);
    final user = ref.watch(currentAuthUserProvider);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const FirinNetHeader(
              title: AppStrings.messagesTitle,
              subtitle: AppStrings.messagesSubtitle,
              showLogo: false,
            ),
            const SectionLabel(title: AppStrings.messagesTitle),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const _Message(
                icon: Icons.cloud_off_outlined,
                message: AppStrings.messagesErrorGeneric,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _Message(
                    icon: Icons.inbox_outlined,
                    message: user == null
                        ? AppStrings.messagesEmptyGuest
                        : AppStrings.messagesEmpty,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _ConversationCard(
                          conversation: items[i],
                          selfId: user?.id ?? '',
                        ),
                        if (i != items.length - 1)
                          const SizedBox(height: AppSpacing.s),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.selfId,
  });

  final JobConversation conversation;
  final String selfId;

  String _formatLast() {
    final t = conversation.lastMessageAt ?? conversation.createdAt;
    if (t == null) return '—';
    final df = DateFormat('d MMM HH:mm', 'tr_TR');
    return df.format(t);
  }

  String _relatedLabel() {
    return conversation.relatedType == 'job_offer'
        ? AppStrings.messagesRelatedJobOffer
        : AppStrings.messagesRelatedJobSeek;
  }

  @override
  Widget build(BuildContext context) {
    final relatedTitle = conversation.relatedTitle ?? '—';
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      onTap: () => context.push('/messages/${conversation.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  relatedTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (conversation.isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    AppStrings.messagesClosedBadge,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _relatedLabel(),
            style: const TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                _formatLast(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.borderHairline,
            width: 0.6,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.softGold, size: 20),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
