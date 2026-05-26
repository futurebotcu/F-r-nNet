// G.N1 + G.N5 — Bildirim bell görünürlüğü + "Katılım onaylı" terminolojisi.
//
// Kapsam:
//   1. NotificationsHeaderAction tooltip + badge davranışı (widget).
//   2. Feed / Gruplar / Profile header'ları ortak widget'ı kullanıyor
//      (source-level guard — copy/paste reintro engellemek için).
//   3. "Özel" badge/strings kaldırıldı; tek terim "Katılım onaylı".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:firin_defter/features/notifications/providers/notification_providers.dart';
import 'package:firin_defter/features/notifications/repositories/local_notification_repository.dart';
import 'package:firin_defter/features/notifications/widgets/notifications_header_action.dart';

Widget _wrap({
  required LocalNotificationRepository repo,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('G.N1 — NotificationsHeaderAction widget', () {
    testWidgets(
      'Bell tooltip "Bildirimler"; unread=0 iken badge yok',
      (tester) async {
        final repo = LocalNotificationRepository(seed: false);
        await tester.pumpWidget(_wrap(
          repo: repo,
          child: const NotificationsHeaderAction(),
        ));
        await tester.pumpAndSettle();

        expect(find.byTooltip(AppStrings.notificationsTitle), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
        // Hiç bildirim yok → sayı widget'ı yok.
        expect(find.text('1'), findsNothing);
      },
    );

    testWidgets(
      'Unread > 0 → badge unread sayısını gösterir',
      (tester) async {
        final repo = LocalNotificationRepository(seed: false);
        repo.add(AppNotification(
          id: 'gn1_a',
          recipientId: 'me',
          type: 'group_join_request',
          title: 't',
          body: 'b',
          createdAt: DateTime(2026, 5, 17),
        ));
        await tester.pumpWidget(_wrap(
          repo: repo,
          child: const NotificationsHeaderAction(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'Unread > 99 → badge "99+" gösterir',
      (tester) async {
        final repo = LocalNotificationRepository(seed: false);
        for (var i = 0; i < 120; i++) {
          repo.add(AppNotification(
            id: 'gn1_$i',
            recipientId: 'me',
            type: 'group_join_request',
            title: 't',
            body: 'b',
            createdAt: DateTime(2026, 5, 17).add(Duration(minutes: i)),
          ));
        }
        await tester.pumpWidget(_wrap(
          repo: repo,
          child: const NotificationsHeaderAction(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('99+'), findsOneWidget);
      },
    );
  });

  group('G.N1 — Bell surface kablolaması (source-level)', () {
    test('Feed header NotificationsHeaderAction kullanıyor', () {
      // V2 Commit 4 cleanup: eski feed_screen.dart silindi. Header
      // SocialFeedPage'a taşındı (_SocialFeedHeader).
      final src = File(
        'lib/features/social/feed/social_feed_page.dart',
      ).readAsStringSync();
      expect(src.contains('NotificationsHeaderAction'), isTrue,
          reason: 'Feed header bell entry point içermeli');
      expect(
        src.contains(
            "import '../../notifications/widgets/notifications_header_action.dart';"),
        isTrue,
      );
    });

    test('Gruplar list header NotificationsHeaderAction kullanıyor', () {
      final src = File(
        'lib/features/social_groups/screens/groups_list_screen.dart',
      ).readAsStringSync();
      expect(src.contains('NotificationsHeaderAction'), isTrue,
          reason: 'Gruplar header bell entry point içermeli');
      expect(
        src.contains(
            "import '../../notifications/widgets/notifications_header_action.dart';"),
        isTrue,
      );
    });

    test(
      'Profile header eski private _NotificationsHeaderAction kaldırıldı, '
      'shared widget kullanılıyor',
      () {
        // Unified Profile M2: ProfileScreen redirector'a dönüştü; public
        // görünüm SocialProfilePage'e taşındı. Bildirim entry point feed
        // header'da NotificationsHeaderAction olarak yaşar.
        final feedSrc = File(
          'lib/features/social/feed/social_feed_page.dart',
        ).readAsStringSync();
        expect(feedSrc.contains('NotificationsHeaderAction'), isTrue,
            reason: 'Feed header bildirim shared widget içermeli');
        // ProfileScreen redirector — eski private widget reintro
        // engelleme invariant'ı korunur.
        final profileSrc = File(
          'lib/features/profile/screens/profile_screen.dart',
        ).readAsStringSync();
        expect(profileSrc.contains('_NotificationsHeaderAction'), isFalse,
            reason: 'Private kopya reintro edilmemiş olmalı');
      },
    );
  });

  group('G.N5 — "Katılım onaylı" terminolojisi', () {
    test('groupApprovalRequiredBadge tek terim olarak korunuyor', () {
      expect(AppStrings.groupApprovalRequiredBadge, 'Katılım onaylı');
    });

    test('groupCreatePrivacyPrivate yeni metin', () {
      expect(AppStrings.groupCreatePrivacyPrivate,
          'Katılım onaylı — istek ile katılım');
      expect(AppStrings.groupCreatePrivacyPrivate.contains('Özel'), isFalse);
    });

    test('Private gruplar için detail badge "Katılım onaylı" kullanır', () {
      final src = File(
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      expect(src.contains('AppStrings.groupApprovalRequiredBadge'), isTrue);
      // Eski "Özel" badge string'ine atıf kalmamalı.
      expect(src.contains('AppStrings.groupBadgePrivate'), isFalse);
    });

    test('Group card private badge "Katılım onaylı" kullanır', () {
      final src = File(
        'lib/features/social_groups/widgets/group_card.dart',
      ).readAsStringSync();
      expect(src.contains('AppStrings.groupApprovalRequiredBadge'), isTrue);
      expect(src.contains('AppStrings.groupBadgePrivate'), isFalse);
    });

    test('AppStrings içinde "Özel" badge constant kaldırıldı', () {
      final src = File('lib/core/constants/app_strings.dart').readAsStringSync();
      // groupBadgePrivate sabiti artık kaynakta tanımlı olmamalı.
      expect(
        RegExp(r'\bgroupBadgePrivate\b\s*=').hasMatch(src),
        isFalse,
        reason: 'groupBadgePrivate kaldırılmalı (G.N5 tek terim)',
      );
    });
  });
}
