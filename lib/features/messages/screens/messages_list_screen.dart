// FırınNet V1 Messaging M1.2 — Generic MessagesListScreen.
//
// /messages route'unda kullanıcının dahil olduğu tüm generic
// conversation'ları gösterir (market_listing / profile_direct /
// job_offer / job_seek context). Eski job_conversations modeli
// silinmedi; eski mesajlar route üzerinden (örn. job offer detail)
// erişilebilir kalır; yeni mesajlaşma akışı generic sistemden geçer.
//
// Tap → /messages/:id → ChatScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messaging/models/conversation.dart';
import '../../messaging/providers/messaging_providers.dart';

class MessagesListScreen extends ConsumerWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsListProvider);
    final user = ref.watch(currentAuthUserProvider);

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(
              child: FirinNetHeader(
                title: AppStrings.messagesTitle,
                subtitle: AppStrings.messagesSubtitle,
                showLogo: false,
              ),
            ),
            async.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: _SimpleEmpty(
                  icon: Icons.cloud_off_outlined,
                  message: AppStrings.messagesErrorGeneric,
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _SimpleEmpty(
                      icon: Icons.forum_outlined,
                      message: user == null
                          ? AppStrings.messagesEmptyGuest
                          : AppStrings.messagesEmpty,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s),
                    itemBuilder: (_, i) {
                      final c = items[i];
                      return _ConversationTile(
                        conversation: c,
                        onTap: () => context.push(
                          AppRoutes.conversation(c.id),
                        ),
                      );
                    },
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  String _contextLabel() {
    switch (conversation.contextType) {
      case 'market_listing':
        return 'Market ilanı';
      case 'job_offer':
        return 'İş ilanı';
      case 'job_seek':
        return 'İş arayan ilanı';
      case 'profile_direct':
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (conversation.otherUserName ?? '').isNotEmpty
        ? conversation.otherUserName!
        : AppStrings.messagesUnknownUser;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final last = conversation.lastMessageContent ?? '';
    final ctxLabel = _contextLabel();
    final time = conversation.lastMessageCreatedAt;
    final timeLabel = time == null ? '' : _relativeTime(time);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.borderHairline, width: 0.6),
          ),
          child: Row(
            children: [
              // Avatar (initial)
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softGold.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.softGold.withValues(alpha: 0.32),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (ctxLabel.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGold.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: AppColors.softGold
                                    .withValues(alpha: 0.32),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              ctxLabel,
                              style: const TextStyle(
                                color: AppColors.softGold,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            last.isEmpty ? '—' : last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.s),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.copper,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    conversation.unreadCount > 99
                        ? '99+'
                        : '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}d';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return DateFormat('d MMM').format(t);
  }
}

class _SimpleEmpty extends StatelessWidget {
  const _SimpleEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xxxl,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.softGold.withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, size: 32, color: AppColors.softGold),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
