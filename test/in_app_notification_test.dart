// In-App Bildirim Merkezi — testler.
//
// Kapsam:
//  * Local repo: boş başlar, add, list (yeni→eski), unreadCount, markAsRead,
//    markAllAsRead, watch emit.
//  * Model fromRow: B2B bildirimi actor_id=null + route taşır (navigasyon
//    kontratı); sosyal bildirimi actor set; read_at → isRead.
//
// Not: Event üretimi (teklif/lead/mesaj/kabul/yorum/takip → bildirim) DB
// trigger'larıyla yapılır; canlı davranışı MCP rollback işlemiyle doğrulandı.

import 'package:firin_defter/features/notifications/models/app_notification.dart';
import 'package:firin_defter/features/notifications/notification_routing.dart';
import 'package:firin_defter/features/notifications/repositories/local_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(String id, {DateTime? readAt, DateTime? createdAt}) {
  return AppNotification(
    id: id,
    recipientId: 'me',
    type: 'b2b_quote_reply_created',
    title: 'Talebine yeni teklif geldi',
    body: 'Bir tedarikçi talebine teklif verdi.',
    route: '/pazar/tekliflerim/req-1',
    readAt: readAt,
    createdAt: createdAt ?? DateTime(2026, 6, 19, 12),
  );
}

void main() {
  group('LocalNotificationRepository', () {
    test('boş başlar (seed=false)', () async {
      final repo = LocalNotificationRepository();
      expect(await repo.list(), isEmpty);
      expect(await repo.unreadCount(), 0);
    });

    test('add → list + unreadCount', () async {
      final repo = LocalNotificationRepository();
      repo.add(_n('a'));
      repo.add(_n('b'));
      expect((await repo.list()).length, 2);
      expect(await repo.unreadCount(), 2);
    });

    test('list yeni→eski sıralı', () async {
      final repo = LocalNotificationRepository();
      repo.add(_n('eski', createdAt: DateTime(2026, 6, 1)));
      repo.add(_n('yeni', createdAt: DateTime(2026, 6, 19)));
      final list = await repo.list();
      expect(list.first.id, 'yeni');
      expect(list.last.id, 'eski');
    });

    test('markAsRead → unreadCount düşer', () async {
      final repo = LocalNotificationRepository();
      repo.add(_n('a'));
      repo.add(_n('b'));
      await repo.markAsRead('a');
      expect(await repo.unreadCount(), 1);
      final a = (await repo.list()).firstWhere((n) => n.id == 'a');
      expect(a.isRead, isTrue);
    });

    test('markAllAsRead → tümü okundu', () async {
      final repo = LocalNotificationRepository();
      repo.add(_n('a'));
      repo.add(_n('b'));
      await repo.markAllAsRead();
      expect(await repo.unreadCount(), 0);
    });

    test('watch değişimde emit eder', () async {
      final repo = LocalNotificationRepository();
      final f = repo.watch().first;
      repo.add(_n('a'));
      await f; // emit gelmezse test takılır/zaman aşımına uğrar
      expect(true, isTrue);
    });
  });

  group('Bildirim navigasyonu (push→go düzeltmesi)', () {
    test('shell/tab kökleri → go (push değil)', () {
      for (final r in const [
        '/community',
        '/pazar',
        '/ilanlar',
        '/messages', // UI-NAV-003: doğru route (eski yanlış literal /mesajlar)
        '/panel',
      ]) {
        expect(isShellTabRoot(r), isTrue, reason: '$r shell kökü olmalı');
      }
      // Eski yanlış literal artık shell kökü SAYILMAZ.
      expect(isShellTabRoot('/mesajlar'), isFalse);
    });

    test('derin route\'lar push-safe kalır (go değil)', () {
      expect(isShellTabRoot('/pazar/tekliflerim/abc'), isFalse);
      expect(isShellTabRoot('/pazar/urun/x'), isFalse);
      expect(isShellTabRoot('/groups/g1'), isFalse);
    });
  });

  group('AppNotification.fromRow', () {
    test('B2B bildirimi: actor_id null + route taşır (navigasyon)', () {
      final n = AppNotification.fromRow({
        'id': 'n1',
        'recipient_id': 'buyer',
        'actor_id': null,
        'type': 'b2b_quote_reply_created',
        'title': 'Talebine yeni teklif geldi',
        'body': 'Bir tedarikçi talebine teklif verdi.',
        'entity_type': 'quote_request',
        'entity_id': 'req-1',
        'route': '/pazar/tekliflerim/req-1',
        'metadata': <String, dynamic>{},
        'read_at': null,
        'created_at': '2026-06-19T12:00:00+00:00',
      });
      expect(n.actorId, isNull);
      expect(n.route, '/pazar/tekliflerim/req-1');
      expect(n.isUnread, isTrue);
    });

    test('sosyal bildirimi: actor set + read_at → isRead', () {
      final n = AppNotification.fromRow({
        'id': 'n2',
        'recipient_id': 'owner',
        'actor_id': 'commenter',
        'type': 'social_comment_created',
        'title': 'Paylaşımına yorum geldi',
        'body': 'Bir paylaşımına yeni yorum yapıldı.',
        'entity_type': 'feed_post',
        'entity_id': 'post-1',
        'route': '/community',
        'metadata': <String, dynamic>{},
        'read_at': '2026-06-19T13:00:00+00:00',
        'created_at': '2026-06-19T12:00:00+00:00',
      });
      expect(n.actorId, 'commenter');
      expect(n.isRead, isTrue);
    });
  });
}
