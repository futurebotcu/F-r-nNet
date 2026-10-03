import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../app/theme/app_typography.dart';
import '../../social/widgets/social_skeletons.dart';
import '../models/app_notification.dart';
import '../notification_routing.dart';
import '../providers/notification_providers.dart';

/// V1 P1-D — Uygulama içi bildirim merkezi.
///
/// Akış:
/// - Liste: `notificationsProvider` (created_at desc)
/// - Tap: markAsRead + (varsa) entity route — shell kökü `go`, derin route `push`
/// - "Tümünü okundu işaretle" CTA app bar action
/// - Boş state: nazik açıklama
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final repo = ref.read(notificationRepositoryProvider);
    return PremiumScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notificationsTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.notificationsMarkAllRead,
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () async {
              try {
                await repo.markAllAsRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationsCountProvider);
                if (context.mounted) {
                  AppFeedback.success(
                    context,
                    AppStrings.notificationsMarkAllReadDone,
                  );
                }
              } catch (e) {
                debugPrint('[FirinNet][Notifications] markAll error: $e');
                if (context.mounted) {
                  AppFeedback.error(
                    context,
                    AppStrings.notificationsMarkAllReadFailed,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          // İlk yükleme: ortada dev spinner yerine statik satır iskeleti.
          loading: () => const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: SocialListSkeleton(
              key: ValueKey('notifications_skeleton'),
              count: 6,
              avatarSize: 10,
            ),
          ),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: ErrorRetryState(
                title: AppStrings.notificationsErrorTitle,
                subtitle: AppStrings.notificationsErrorGeneric,
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ),
          ),
          data: (items) {
            Future<void> refresh() async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
              try {
                await ref.read(notificationsProvider.future);
              } catch (_) {
                // Hata durumu ekranın error dalında gösterilir.
              }
            }

            if (items.isEmpty) {
              return RefreshIndicator(
                onRefresh: refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: const Center(child: _NotificationsEmpty()),
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.s,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.s),
                itemBuilder: (_, i) => NotificationRow(item: items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// V1 P1-D — Tek bildirim satırı. Library-public (test edilebilirlik).
class NotificationRow extends ConsumerWidget {
  const NotificationRow({super.key, required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = item.isUnread;
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () async {
        final repo = ref.read(notificationRepositoryProvider);
        if (isUnread) {
          await repo.markAsRead(item.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationsCountProvider);
        }
        if (!context.mounted) return;
        final route = item.route;
        if (route != null && route.isNotEmpty) {
          navigateToNotificationRoute(GoRouter.of(context), route);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol dot: unread indikatörü.
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: AppSpacing.s),
              decoration: BoxDecoration(
                color: isUnread ? AppColors.brandInk : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.authorName.copyWith(
                      fontSize: 14.5,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTypography.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTimeTr(item.createdAt),
                    key: const ValueKey('notification_row_time'),
                    style: AppTypography.caption,
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

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.notifications_none_rounded,
      title: AppStrings.notificationsEmptyTitle,
      subtitle: AppStrings.notificationsEmptyBody,
    );
  }
}
