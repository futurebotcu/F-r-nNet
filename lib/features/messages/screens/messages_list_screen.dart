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

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messaging/models/conversation.dart';
import '../../messaging/providers/messaging_providers.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/firinnet_avatar.dart';
import '../../social/widgets/social_skeletons.dart';

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
              // Perf (jank): yeni mesaj/okundu tick'i conversationsListProvider'ı
              // recompute ediyordu → liste spinner'a flash atıyordu.
              skipLoadingOnReload: true,
              // İlk yükleme: tek başına dev spinner yerine statik satır
              // iskeleti (sohbet kartlarının yerleşimi).
              loading: () => const SliverToBoxAdapter(
                child: SocialListSkeleton(
                  key: ValueKey('messages_skeleton'),
                  avatarSize: FirinNetAvatarSize.m,
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: ErrorRetryState(
                  title: AppStrings.messagesErrorGeneric,
                  onRetry: () => ref.invalidate(conversationsListProvider),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.forum_rounded,
                      title: user == null
                          ? AppStrings.messagesEmptyGuestTitle
                          : AppStrings.messagesEmptyTitle,
                      subtitle: user == null
                          ? AppStrings.messagesEmptyGuest
                          : AppStrings.messagesEmptySubtitle,
                      // Misafir: "giriş yap" deyip butonsuz bırakma.
                      actionLabel: user == null
                          ? AppStrings.authRequiredSignIn
                          : null,
                      onAction: user == null
                          ? () => context.push(AppRoutes.authEntry)
                          : null,
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
                      return ConversationTile(
                        conversation: c,
                        onTap: () => context.push(AppRoutes.conversation(c.id)),
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

@visibleForTesting
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  String _contextLabel() {
    switch (conversation.contextType) {
      case 'market_listing':
        return AppStrings.messagingContextMarket;
      case 'job_offer':
        return AppStrings.messagingContextJobOffer;
      case 'job_seek':
        return AppStrings.messagingContextJobSeek;
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
    final last = conversation.lastMessageContent ?? '';
    final ctxLabel = _contextLabel();
    final time = conversation.lastMessageCreatedAt;
    // "5 dk" / "3 sa" / "dün" — eski "5d" dakikayı gün gibi okutuyordu.
    final timeLabel = time == null ? '' : relativeTimeShortTr(time);
    // Kalın isim/önizleme yalnız okunmamış sohbette (tarama kolaylığı).
    final unread = conversation.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.m,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.l),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              FirinNetAvatar(name: name, size: FirinNetAvatarSize.m),
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
                            style: AppTypography.authorName.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            timeLabel,
                            key: const ValueKey('conversation_tile_time'),
                            style: AppTypography.caption.copyWith(
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (ctxLabel.isNotEmpty) ...[
                          // Bağlam etiketi dar ekran/büyük yazıda kısalır;
                          // önizleme metnine yer bırakır (taşma yok).
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLine,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: AppColors.borderHairline,
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                ctxLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.badge.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0,
                                ),
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
                            style: AppTypography.body.copyWith(
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.s),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandLemon,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.brandLemonPressed.withValues(
                        alpha: 0.45,
                      ),
                      width: 0.6,
                    ),
                  ),
                  // Faz 2 P2 — beyaz-on-lemon (düşük kontrast) yerine ink-on-lemon
                  // (panel rozetiyle tutarlı, okunur).
                  child: Text(
                    conversation.unreadCount > 99
                        ? '99+'
                        : '${conversation.unreadCount}',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.brandInk,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
