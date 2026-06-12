// FırınNet UGC Safety V1.1 — engelleme tamamlama (DM + bildirim + çift yön).
//
// V1 block görsel+tek yönlüydü (feed/yorum/grup). V1.1 boşlukları kapatır:
//   - DM konuşma listesi: engellenenle thread gizlenir.
//   - DM mesajları: engellenen göndericinin mesajı gizlenir.
//   - Bildirimler: engellenen actor'lı bildirim gizlenir.
//   - Çift yön: find_or_create RPC block'ta BlockedConversationException
//     (migration + client map; source-contract).

import 'dart:io';

import 'package:firin_defter/features/messaging/models/conversation.dart';
import 'package:firin_defter/features/messaging/models/message.dart';
import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Provider filtreleri saf liste işlemleridir; mantığı birebir aynası ile
  // doğrula (provider Riverpod harness'i yerine domain davranışı).
  group('V1.1 — DM konuşma listesi blocked filtresi', () {
    Conversation conv(String id, String? other) => Conversation(
          id: id,
          type: 'direct',
          contextType: 'profile_direct',
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          otherUserId: other,
        );

    List<Conversation> filter(List<Conversation> list, Set<String> blocked) =>
        blocked.isEmpty
            ? list
            : list
                .where((c) =>
                    c.otherUserId == null || !blocked.contains(c.otherUserId))
                .toList();

    test('engellenenle thread gizlenir, diğerleri kalır', () {
      final list = [conv('c1', 'u_block'), conv('c2', 'u_ok'), conv('c3', null)];
      final out = filter(list, {'u_block'});
      expect(out.map((c) => c.id), ['c2', 'c3']);
    });

    test('blocked boşsa liste değişmez', () {
      final list = [conv('c1', 'u1')];
      expect(filter(list, {}).length, 1);
    });
  });

  group('V1.1 — DM mesaj listesi blocked filtresi', () {
    Message msg(String id, String sender) => Message(
          id: id,
          conversationId: 'c1',
          senderId: sender,
          content: 'x',
          messageType: 'text',
          createdAt: DateTime(2026, 6, 12),
        );

    List<Message> filter(List<Message> list, Set<String> blocked) =>
        blocked.isEmpty
            ? list
            : list.where((m) => !blocked.contains(m.senderId)).toList();

    test('engellenen göndericinin mesajı düşer', () {
      final list = [msg('m1', 'me'), msg('m2', 'u_block'), msg('m3', 'me')];
      expect(filter(list, {'u_block'}).map((m) => m.id), ['m1', 'm3']);
    });
  });

  group('V1.1 — bildirim blocked filtresi', () {
    AppNotification notif(String id, String? actor, {bool read = false}) =>
        AppNotification(
          id: id,
          recipientId: 'me',
          actorId: actor,
          type: 'like',
          title: 't',
          body: 'b',
          createdAt: DateTime(2026, 6, 12),
          readAt: read ? DateTime(2026, 6, 12) : null,
        );

    List<AppNotification> filter(
            List<AppNotification> list, Set<String> blocked) =>
        blocked.isEmpty
            ? list
            : list
                .where((n) =>
                    n.actorId == null || !blocked.contains(n.actorId))
                .toList();

    test('engellenen actor bildirimi gizlenir; sistem bildirimi (actor null) kalır',
        () {
      final list = [
        notif('n1', 'u_block'),
        notif('n2', 'u_ok'),
        notif('n3', null),
      ];
      expect(filter(list, {'u_block'}).map((n) => n.id), ['n2', 'n3']);
    });

    test('okunmamış sayısı blocked hariç hesaplanır', () {
      final list = [
        notif('n1', 'u_block', read: false),
        notif('n2', 'u_ok', read: false),
        notif('n3', 'u_ok', read: true),
      ];
      final visible = filter(list, {'u_block'});
      expect(visible.where((n) => !n.isRead).length, 1);
    });
  });

  group('V1.1 — source contracts (çift yön + UI map)', () {
    String src(String p) => File(p).readAsStringSync();

    test('migration: RPC çift yön block kontrolü içerir', () {
      final sql = src(
        'supabase/migrations/'
        '20260612040000_ugc_safety_v1_1_block_direct_conversation.sql',
      );
      expect(sql.contains('blocked between users'), isTrue);
      expect(
        sql.contains('blocker_id = p_other_user and blocked_user_id = v_me'),
        isTrue,
        reason: 'Engellenen kullanıcı engelleyene mesaj başlatamamalı (incoming)',
      );
      expect(
        sql.contains('blocker_id = v_me and blocked_user_id = p_other_user'),
        isTrue,
        reason: 'Çift yön: blocker da defense-in-depth',
      );
    });

    test('repo: RPC hatasını BlockedConversationException\'a map eder', () {
      final repo = src(
        'lib/features/messaging/repositories/supabase_messaging_repository.dart',
      );
      expect(repo.contains("contains('blocked between users')"), isTrue);
      expect(repo.contains('BlockedConversationException'), isTrue);
    });

    test('UI: 3 başlatma yolu BlockedConversationException yakalar', () {
      for (final f in [
        'lib/features/social/profile/profile_page.dart',
        'lib/features/marketplace/screens/marketplace_detail_screen.dart',
        'lib/features/messages/widgets/start_job_conversation_sheet.dart',
      ]) {
        expect(src(f).contains('BlockedConversationException'), isTrue,
            reason: '$f blocked durumunu dostça göstermeli');
      }
    });

    test('providerlar blocked filtresi uygular', () {
      final m = src('lib/features/messaging/providers/messaging_providers.dart');
      expect(m.contains('blockedUserIdsProvider'), isTrue);
      expect(m.contains('!blocked.contains(c.otherUserId)'), isTrue);
      expect(m.contains('!blocked.contains(m.senderId)'), isTrue);
      final n =
          src('lib/features/notifications/providers/notification_providers.dart');
      expect(n.contains('!blocked.contains(n.actorId)'), isTrue);
      final chat = src('lib/features/messaging/screens/chat_screen.dart');
      expect(chat.contains('blockedUserIdsSyncProvider'), isTrue,
          reason: 'Realtime engellenen göndericiyi eklememelı');
    });
  });
}
