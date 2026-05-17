// V1 P1-D — Private grup katılım isteği + bildirim akışı için widget/source testler.
//
// Kapsam:
//  1. Private group card "Katılım onaylı" badge gösterir.
//  2. Non-member private group detail mesajları göstermez (source assertion).
//  3. Non-member private group "Katılma isteği gönder" butonu gösterir.
//  4. Request send success → repo pending request tutar.
//  5+6. Owner pending requests UI görünür + approve repo'yu çağırır.
//  7. NotificationsScreen empty state.
//  8. NotificationsScreen unread item gösterir.
//  9. Tap notification markAsRead çağırır.
// 10. Public group join eski davranışı bozulmamış.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:firin_defter/features/notifications/providers/notification_providers.dart';
import 'package:firin_defter/features/notifications/repositories/local_notification_repository.dart';
import 'package:firin_defter/features/notifications/repositories/notification_repository.dart';
import 'package:firin_defter/features/notifications/screens/notifications_screen.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_join_request.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/social_group_repository.dart';
import 'package:firin_defter/features/social_groups/screens/group_detail_screen.dart';
import 'package:firin_defter/features/social_groups/widgets/group_card.dart';

SocialGroup _mkGroup({
  required String id,
  required bool isPrivate,
  String ownerId = 'me_misafir',
}) {
  return SocialGroup(
    id: id,
    name: 'Test Grup',
    description: 'desc',
    category: GroupCategory.bakers,
    ownerName: 'Owner',
    ownerId: ownerId,
    city: '',
    isPrivate: isPrivate,
    maxMembers: 100,
    currentMemberCount: 5,
    createdAt: DateTime(2026, 5, 17),
    tags: const [],
    visualSeed: 0,
  );
}

Widget _wrap({
  required SocialGroupRepository groupRepo,
  NotificationRepository? notifRepo,
  AuthUser? authUser,
  bool canWrite = true,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      socialGroupRepositoryProvider.overrideWithValue(groupRepo),
      if (notifRepo != null)
        notificationRepositoryProvider.overrideWithValue(notifRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('V1 P1-D — Private group join + notifications', () {
    testWidgets(
      '1. Private group card "Katılım onaylı" badge gösterir',
      (tester) async {
        final group = _mkGroup(id: 'g1', isPrivate: true);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: group,
              isJoined: false,
              onPrimary: () {},
            ),
          ),
        ));
        expect(
          find.text(AppStrings.groupApprovalRequiredBadge.toUpperCase()),
          findsOneWidget,
        );
      },
    );

    test(
      '2. Non-member private group_detail_screen mesaj yerine '
      'GroupPrivateInfo gating gösterir (source-level)',
      () {
        final src = File(
          'lib/features/social_groups/screens/group_detail_screen.dart',
        ).readAsStringSync();
        expect(
          src.contains(
            'final contentVisible = !g.isPrivate || joined || isOwner;',
          ),
          isTrue,
        );
        expect(src.contains('_PrivateGatedInfo()'), isTrue);
        expect(src.contains('AppStrings.groupPrivateInfo'), isTrue);
      },
    );

    testWidgets(
      '3. Non-member private group: "Katılma isteği gönder" button',
      (tester) async {
        final repo = LocalSocialGroupRepository(seed: false);
        final group = _mkGroup(id: 'g3', isPrivate: true, ownerId: 'owner_x');
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          child: Scaffold(
            body: PrimaryActionButton(group: group, isJoined: false),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupJoinRequestSend), findsOneWidget);
      },
    );

    testWidgets(
      '4. Request send → repo pending request tutar',
      (tester) async {
        final repo = LocalSocialGroupRepository(
          seed: false,
          currentUserId: 'me_test',
        );
        final group = _mkGroup(id: 'g4', isPrivate: true, ownerId: 'owner_x');
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          child: Scaffold(
            body: PrimaryActionButton(group: group, isJoined: false),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.groupJoinRequestSend));
        await tester.pumpAndSettle();

        final mine = await repo.getMyJoinRequest('g4');
        expect(mine, isNotNull);
        expect(mine!.status, GroupJoinRequestStatus.pending);
      },
    );

    testWidgets(
      '5+6. Owner pending requests UI + approve repo\'yu çağırır',
      (tester) async {
        final repo = LocalSocialGroupRepository(
          seed: false,
          currentUserId: 'requester_z',
        );
        await repo.requestJoinGroup('g5');
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          authUser: const AuthUser(id: 'owner_y', email: null),
          child: const Scaffold(
            body: PendingRequestsSection(groupId: 'g5'),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupJoinRequestApproveCta), findsWidgets);
        expect(find.text(AppStrings.groupJoinRequestRejectCta), findsWidgets);

        await tester.tap(
          find.text(AppStrings.groupJoinRequestApproveCta).first,
        );
        await tester.pumpAndSettle();
        final pending = await repo.listPendingJoinRequests('g5');
        expect(
          pending.isEmpty,
          isTrue,
          reason: 'Approve sonrası pending listesinden düşmeli',
        );
      },
    );

    testWidgets(
      '7. NotificationsScreen empty state',
      (tester) async {
        final notif = LocalNotificationRepository(seed: false);
        final groupRepo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: groupRepo,
          notifRepo: notif,
          child: const NotificationsScreen(),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
        expect(find.text(AppStrings.notificationsEmptyBody), findsOneWidget);
      },
    );

    testWidgets(
      '8. NotificationsScreen unread item gösterir',
      (tester) async {
        final notif = LocalNotificationRepository(seed: false);
        notif.add(AppNotification(
          id: 'n1',
          recipientId: 'me',
          type: 'group_join_request',
          title: 'Test başlık',
          body: 'Test gövde',
          createdAt: DateTime(2026, 5, 17),
        ));
        final groupRepo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: groupRepo,
          notifRepo: notif,
          child: const NotificationsScreen(),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Test başlık'), findsOneWidget);
        expect(find.text('Test gövde'), findsOneWidget);
      },
    );

    testWidgets(
      '9. Tap notification markAsRead çağırır (unread→read)',
      (tester) async {
        final notif = LocalNotificationRepository(seed: false);
        notif.add(AppNotification(
          id: 'n2',
          recipientId: 'me',
          type: 'group_join_request',
          title: 'Tap test',
          body: 'tap',
          createdAt: DateTime(2026, 5, 17),
          // route YOK → tap yalnız markAsRead çağırır, navigate etmez.
        ));
        final groupRepo = LocalSocialGroupRepository(seed: false);
        await tester.pumpWidget(_wrap(
          groupRepo: groupRepo,
          notifRepo: notif,
          child: const NotificationsScreen(),
        ));
        await tester.pumpAndSettle();
        expect(await notif.unreadCount(), 1);
        await tester.tap(find.text('Tap test'));
        await tester.pumpAndSettle();
        expect(
          await notif.unreadCount(),
          0,
          reason: 'Tap sonrası markAsRead çağrılır',
        );
      },
    );

    testWidgets(
      '10. Public group join akışı (joinGroup) bozulmamış',
      (tester) async {
        final repo = LocalSocialGroupRepository(
          seed: false,
          currentUserId: 'pub_user',
        );
        final group = _mkGroup(id: 'gpub', isPrivate: false);
        await tester.pumpWidget(_wrap(
          groupRepo: repo,
          child: Scaffold(
            body: PrimaryActionButton(group: group, isJoined: false),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.groupActionJoin), findsOneWidget);
        expect(find.text(AppStrings.groupJoinRequestSend), findsNothing);
      },
    );
  });
}
