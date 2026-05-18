import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../providers/notification_providers.dart';

/// V1 P1-D — Header sağ üstte bell + unread badge.
///
/// Profile, Feed ve Gruplar header'larında paylaşılır. Tap → `/notifications`.
/// Badge `unreadNotificationsCountProvider`'ı izler; 99+ üstü kırpılır.
class NotificationsHeaderAction extends ConsumerWidget {
  const NotificationsHeaderAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).maybeWhen(
          data: (n) => n,
          orElse: () => 0,
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        HeaderActionButton(
          icon: Icons.notifications_none_rounded,
          tooltip: AppStrings.notificationsTitle,
          onTap: () => context.push(AppRoutes.notifications),
        ),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.copper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
