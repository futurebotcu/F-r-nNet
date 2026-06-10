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

    test('Legacy: /messages/legacy/:id → JobConversationScreen (korunur)', () {
      expect(src.contains("'/messages/legacy/:id'"), isTrue);
      expect(src.contains('JobConversationScreen('), isTrue);
    });

    test('Legacy route in-app push YOK (ölü route)', () {
      // Router tanımı dışında hiçbir lib dosyası /messages/legacy/ push etmemeli.
      final hits = <String>[];
      final dir = Directory('lib');
      for (final f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.replaceAll('\\', '/').endsWith('app/router/app_router.dart')) {
          continue;
        }
        if (f.readAsStringSync().contains('/messages/legacy/')) {
          hits.add(f.path);
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'Legacy route yalnız router tanımında olmalı; '
            'navigasyon kaynağı bulundu: $hits',
      );
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

  group('Sprint C — C-1 uyumsuzluğu (job sheet → generic route)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messages/widgets/start_job_conversation_sheet.dart')
          .readAsStringSync();
    });

    test('Job repo ile job_conversation yaratır', () {
      expect(src.contains('jobMessagingRepositoryProvider'), isTrue);
      expect(
        src.contains('startForJobOffer') || src.contains('startForJobSeek'),
        isTrue,
      );
    });

    test(
      'C-1: şu an GENERIC /messages/:id\'ye push ediyor (Sprint D düzeltir)',
      () {
        // Bu, bilinen P0 uyumsuzluğun mevcut sözleşmesidir. Sprint D job
        // akışını generic findOrCreate\'e taşıyınca bu beklenti bilinçli
        // güncellenecek (örn. generic conversation id ile).
        expect(
          src.contains(r"context.push('/messages/${convo.id}')"),
          isTrue,
          reason: 'C-1 audit kaydı: job sheet generic route kullanıyor',
        );
        expect(
          src.contains('/messages/legacy/'),
          isFalse,
          reason: 'Job sheet legacy route\'a gitmiyor (C-1 uyumsuzluğun özü)',
        );
      },
    );
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
