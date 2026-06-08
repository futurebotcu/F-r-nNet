import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/app_notification.dart';
import '../providers/notification_providers.dart';

/// V1 P1-D — Uygulama içi bildirim merkezi.
///
/// Akış:
/// - Liste: `notificationsProvider` (created_at desc)
/// - Tap: markAsRead + (varsa) entity route
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
              await repo.markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Center(
              child: Text(
                AppStrings.notificationsErrorGeneric,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _NotificationsEmpty();
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.s,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) => NotificationRow(item: items[i]),
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
          context.push(route);
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
                color: isUnread ? AppColors.copper : Colors.transparent,
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
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
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

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.softGold,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.notificationsEmptyTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.notificationsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
