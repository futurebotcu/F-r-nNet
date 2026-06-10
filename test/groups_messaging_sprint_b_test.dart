// FırınNet Groups & Messaging Sprint B — Liveness, Unread Badges,
// Group Community Feel.
//
// Kapsam:
//   * M-10 — Panel "Mesajlar" kartı okunmamış badge (gerçek veri).
//   * G-6/G-7 — Grup detayı topluluk header (açıklama + üye preview).
//   * G-8 — Grup composer gönderim feedback (sending + error banner + retry).
//   * M-5 deepening — Chat error bubble'da görünür "Tekrar dene".

import 'dart:io';

import 'package:firin_defter/core/widgets/premium/quick_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M-10 — QuickActionTile unread badge (widget)', () {
    Widget host(int badgeCount) => MaterialApp(
          home: Scaffold(
            body: QuickActionTile(
              label: 'Mesajlar',
              subtitle: 'Sohbetler',
              icon: Icons.chat_bubble_outline_rounded,
              badgeCount: badgeCount,
              onTap: () {},
            ),
          ),
        );

    testWidgets('badgeCount > 0 → sayı görünür', (tester) async {
      await tester.pumpWidget(host(3));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('badgeCount == 0 → badge yok', (tester) async {
      await tester.pumpWidget(host(0));
      // 0 veya başka rakam render edilmemeli (yalnız label/subtitle metni var).
      expect(find.text('0'), findsNothing);
    });

    testWidgets('badgeCount > 9 → "9+" cap', (tester) async {
      await tester.pumpWidget(host(12));
      expect(find.text('9+'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });
  });

  group('M-10 — totalUnreadMessagesProvider kaynak sözleşmesi', () {
    test('conversationsListProvider unreadCount toplamından türetilir', () {
      final src = File(
        'lib/features/messaging/providers/messaging_providers.dart',
      ).readAsStringSync();
      expect(src.contains('totalUnreadMessagesProvider'), isTrue);
      expect(src.contains('conversationsListProvider'), isTrue);
      expect(src.contains('c.unreadCount'), isTrue);
    });

    test('Panel kartı (role_dashboard) messages route\'una badge bağlar', () {
      final src = File(
        'lib/features/dashboard/screens/role_dashboard_screen.dart',
      ).readAsStringSync();
      expect(src.contains('totalUnreadMessagesProvider'), isTrue);
      expect(
        src.contains('cards[i].route == AppRoutes.messages ? unread : 0'),
        isTrue,
      );
    });
  });

  group('G-6/G-7 — Grup topluluk header (kaynak)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social_groups/screens/group_detail_screen.dart')
          .readAsStringSync();
    });

    test('_GroupCommunityHeader chat body\'ye eklendi', () {
      expect(src.contains('class _GroupCommunityHeader'), isTrue);
      expect(src.contains('_GroupCommunityHeader(group: group)'), isTrue);
    });

    test('Üye avatar preview gerçek üye verisinden (groupMembersProvider)', () {
      expect(src.contains('groupMembersProvider(group.id)'), isTrue);
      expect(src.contains('class _GroupAvatarStack'), isTrue);
    });

    test('UX Reset sözleşmesi korunur (hero/members entry yok)', () {
      expect(src.contains('class _GroupHero'), isFalse);
      expect(src.contains('class _MembersEntryRow'), isFalse);
    });
  });

  group('G-8 — Grup composer gönderim feedback (kaynak)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social_groups/screens/group_detail_screen.dart')
          .readAsStringSync();
    });

    test('Sending state + duplicate guard', () {
      expect(src.contains('bool _sending = false'), isTrue);
      expect(src.contains('|| _sending) return'), isTrue);
      expect(src.contains('onPressed: _sending ? null : _send'), isTrue);
    });

    test('Hata → top banner retry, snackbar değil', () {
      expect(src.contains('PremiumTopBannerController.show'), isTrue);
      expect(src.contains('PremiumTopBannerTone.danger'), isTrue);
      expect(src.contains('onAction: _send'), isTrue);
      // Eski hata snackbar\'ı kaldırıldı.
      expect(
        src.contains('SnackBar(content: Text(AppStrings.groupMessageSendError))'),
        isFalse,
      );
    });
  });

  group('M-5 deepening — Chat error bubble görünür retry (kaynak)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
    });

    test('textMessageBuilder default SimpleTextMessage\'ı korur', () {
      expect(src.contains('textMessageBuilder: _buildTextMessage'), isTrue);
      expect(src.contains('fcu.SimpleTextMessage(message: message'), isTrue);
    });

    test('Error bubble inline "Tekrar dene" + resend', () {
      expect(src.contains('fcc.MessageStatus.error'), isTrue);
      expect(src.contains('AppStrings.messagingRetryCta'), isTrue);
      expect(src.contains('_trySend(t, tempId: message.id)'), isTrue);
    });

    test('chatMessageBuilder override EDİLMEDİ (layout güvenliği)', () {
      expect(
        src.contains('chatMessageBuilder:'),
        isFalse,
        reason: 'Hizalama/animasyon paket varsayılanından gelmeli; '
            'chatMessageBuilder atanmamalı',
      );
    });
  });
}
