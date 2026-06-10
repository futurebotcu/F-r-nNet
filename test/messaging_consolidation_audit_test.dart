// FırınNet Sprint C — Messaging Consolidation Audit (contract lock).
//
// Bu testler, audit edilmiş MEVCUT mesajlaşma gerçeğini source-level
// olarak kilitler. Amaç: legacy/generic ikiliğinin durumu (özellikle C-1
// uyumsuzluğu) Sprint D'de **bilinçli** değiştirilene dek sessizce
// kaymasın. Davranış doğrulaması değil, mimari sözleşme doğrulamasıdır.
//
// Tam analiz: docs/audits/GROUPS_MESSAGING_UX_AUDIT.md → "Sprint C".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sprint C — Route haritası', () {
    late String src;
    setUpAll(() {
      src = File('lib/app/router/app_router.dart').readAsStringSync();
    });

    test('Generic: /messages/:id → ChatScreen', () {
      expect(src.contains("path: '/messages/:id'"), isTrue);
      expect(src.contains('ChatScreen('), isTrue);
    });

    test('Sprint E: legacy route + JobConversationScreen tamamen kaldırıldı',
        () {
      expect(src.contains("'/messages/legacy/:id'"), isFalse);
      expect(src.contains('JobConversationScreen'), isFalse);
    });

    test('Hiçbir lib dosyasında /messages/legacy/ kalmadı', () {
      final hits = <String>[];
      final dir = Directory('lib');
      for (final f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains('/messages/legacy/')) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty, reason: 'Legacy route izi bulundu: $hits');
    });
  });

  group('Sprint C — Generic liste (messages klasöründe ama generic okur)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messages/screens/messages_list_screen.dart')
          .readAsStringSync();
    });

    test('conversationsListProvider (generic) kullanır, job değil', () {
      expect(src.contains('conversationsListProvider'), isTrue);
      expect(src.contains('myJobConversationsProvider'), isFalse);
    });
  });

  group('Sprint D — C-1 FIXED: job sheet generic messaging kullanır', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messages/widgets/start_job_conversation_sheet.dart')
          .readAsStringSync();
    });

    test('Generic messagingRepositoryProvider kullanır (legacy job repo değil)',
        () {
      expect(src.contains('messagingRepositoryProvider'), isTrue);
      expect(
        src.contains('jobMessagingRepositoryProvider'),
        isFalse,
        reason: 'C-1 fix: artık legacy job repo kullanılmıyor',
      );
      expect(src.contains('startForJobOffer'), isFalse);
      expect(src.contains('startForJobSeek'), isFalse);
    });

    test('findOrCreateDirectConversation + job_offer/job_seek context', () {
      expect(src.contains('findOrCreateDirectConversation'), isTrue);
      expect(src.contains("'job_offer'"), isTrue);
      expect(src.contains("'job_seek'"), isTrue);
      expect(src.contains('contextId: postId'), isTrue);
    });

    test('İlk mesaj generic sendTextMessage; generic /messages/:id\'ye push',
        () {
      expect(src.contains('sendTextMessage(conversationId: convId'), isTrue);
      expect(src.contains(r"context.push('/messages/$convId')"), isTrue);
      expect(
        src.contains('/messages/legacy/'),
        isFalse,
        reason: 'Job akışı generic chat ekranına gider, legacy değil',
      );
    });
  });

  group('Sprint C — Panel Mesajlar girişi generic listeye gider', () {
    test('role_panel_cards Mesajlar kartı AppRoutes.messages kullanır', () {
      final src = File(
        'lib/features/dashboard/services/role_panel_cards.dart',
      ).readAsStringSync();
      expect(src.contains('route: AppRoutes.messages'), isTrue);
    });
  });

  group('Sprint C — Generic sistem job context\'i zaten destekler', () {
    test('ChatScreen job_offer / job_seek context label\'larını işler', () {
      final src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
      expect(src.contains("case 'job_offer':"), isTrue);
      expect(src.contains("case 'job_seek':"), isTrue);
    });
  });
}
