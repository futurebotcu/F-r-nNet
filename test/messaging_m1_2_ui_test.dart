// FırınNet Messaging M1.2 — UI wiring source-level invariants.
//
// Kapsam: router /messages/:id ChatScreen + legacy split, MessagesListScreen
// generic conversationsListProvider, ChatScreen flutter_chat_ui + realtime
// + markAsRead, market detail _onInAppMessage findOrCreate + push, profile
// non-self "Mesaj" CTA, AppStrings.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M1.2 — Router /messages/:id ChatScreen + legacy split', () {
    late String src;
    setUpAll(() {
      src = File('lib/app/router/app_router.dart').readAsStringSync();
    });

    test('ChatScreen import edilmiş', () {
      expect(
        src.contains(
            "import '../../features/messaging/screens/chat_screen.dart'"),
        isTrue,
      );
    });

    test('/messages/:id → ChatScreen (generic)', () {
      expect(src.contains("path: '/messages/:id'"), isTrue);
      expect(src.contains('ChatScreen('), isTrue);
    });

    test('Legacy /messages/legacy/:id ve JobConversationScreen kaldırıldı '
        '(Sprint E)', () {
      expect(src.contains("'/messages/legacy/:id'"), isFalse);
      expect(src.contains('JobConversationScreen'), isFalse);
    });
  });

  group('M1.2 — MessagesListScreen generic', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messages/screens/messages_list_screen.dart')
          .readAsStringSync();
    });

    test('conversationsListProvider kullanır (job provider değil)', () {
      expect(src.contains('conversationsListProvider'), isTrue);
      expect(
        src.contains('myJobConversationsProvider'),
        isFalse,
        reason:
            'Generic listeye geçildi — job provider artık burada referans değil',
      );
    });

    test('Tap → AppRoutes.conversation(id) push', () {
      expect(src.contains('AppRoutes.conversation(c.id)'), isTrue);
    });

    test('Context badge label markete/job ayrımı', () {
      expect(src.contains("case 'market_listing':"), isTrue);
      expect(src.contains("case 'job_offer':"), isTrue);
      expect(src.contains("case 'job_seek':"), isTrue);
    });

    test('Unread badge görüntülenir', () {
      expect(src.contains('unreadCount'), isTrue);
      expect(src.contains("'99+'"), isTrue,
          reason: 'Unread badge 99+ overflow handling');
    });
  });

  group('M1.2 — ChatScreen flutter_chat_ui + realtime + markAsRead', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
    });

    test('flutter_chat_ui + flutter_chat_core import', () {
      expect(
        src.contains(
            "import 'package:flutter_chat_core/flutter_chat_core.dart'"),
        isTrue,
      );
      expect(
        src.contains("import 'package:flutter_chat_ui/flutter_chat_ui.dart'"),
        isTrue,
      );
    });

    test('InMemoryChatController + Chat widget', () {
      expect(src.contains('InMemoryChatController'), isTrue);
      expect(src.contains('fcu.Chat('), isTrue);
      expect(src.contains('chatController: _chatController'), isTrue);
      expect(src.contains('onMessageSend: _onSend'), isTrue);
    });

    test('TextMessage map (our.Message → fcc.TextMessage)', () {
      expect(src.contains('fcc.TextMessage('), isTrue);
      expect(src.contains('authorId: m.senderId'), isTrue);
      expect(src.contains('text: m.content'), isTrue);
    });

    test('Realtime messagesStreamProvider listen + dedupe', () {
      expect(src.contains('messagesStreamProvider'), isTrue);
      expect(src.contains('_seenMessageIds'), isTrue);
    });

    test('open\'da markAsRead + invalidate', () {
      expect(src.contains('markAsRead(widget.conversationId)'), isTrue);
      expect(
        src.contains('ref.invalidate(conversationsListProvider)'),
        isTrue,
      );
    });

    test('AppBar otherUserName + context badge subtitle', () {
      expect(src.contains('otherUserName'), isTrue);
      expect(src.contains('messagingContextMarket'), isTrue);
      expect(src.contains('messagingContextJobOffer'), isTrue);
    });
  });

  group('M1.2 — Market detail mesaj başlatma', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/marketplace/screens/marketplace_detail_screen.dart',
      ).readAsStringSync();
    });

    test('Snackbar "yakında" mesajı kaldırıldı', () {
      expect(
        src.contains('İlan içi mesajlaşma yakında'),
        isFalse,
        reason: 'M1.2 ile gerçek mesajlaşma akışı bağlandı',
      );
    });

    test('findOrCreateDirectConversation market_listing context', () {
      expect(src.contains('findOrCreateDirectConversation'), isTrue);
      expect(src.contains("contextType: 'market_listing'"), isTrue);
      expect(src.contains('contextId: l.id'), isTrue);
      expect(src.contains('otherUserId: l.ownerId!'), isTrue);
    });

    test('Push /messages/\$convId + auth guard exception handling', () {
      expect(src.contains(r"context.push('/messages/$convId')"), isTrue);
      expect(src.contains('GuestActionRequiredException'), isTrue);
    });

    test('Self-DM pre-check (kendi ilanına mesaj engeli)', () {
      expect(src.contains('me.id == l.ownerId'), isTrue);
    });
  });

  group('M1.2 — Profile non-self "Mesaj" CTA', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('Non-self profilde Mesaj outlined button render eder', () {
      expect(src.contains('messagingMessageCtaProfile'), isTrue);
      expect(src.contains('Icons.chat_bubble_outline_rounded'), isTrue);
      expect(src.contains('_openProfileChat'), isTrue);
    });

    test('findOrCreate profile_direct context (contextId null)', () {
      expect(src.contains("contextType: 'profile_direct'"), isTrue);
      expect(
        src.contains('contextId:'),
        isFalse,
        reason:
            'profile_direct için contextId null (RPC validate eder); açıkça yazma',
      );
    });

    test('Auth guard + push /messages/\$convId', () {
      expect(src.contains('AuthRequiredGuard.canWriteWithRef(ref)'), isTrue);
      expect(src.contains(r"context.push('/messages/$convId')"), isTrue);
    });
  });

  group('M1.2 — AppStrings yeni messaging sabitleri', () {
    test('Beklenen mesajlaşma sabitleri tanımlı', () {
      expect(AppStrings.messagingDefaultTitle, isNotEmpty);
      expect(AppStrings.messagesUnknownUser, isNotEmpty);
      expect(AppStrings.messagingContextMarket, isNotEmpty);
      expect(AppStrings.messagingContextJobOffer, isNotEmpty);
      expect(AppStrings.messagingContextJobSeek, isNotEmpty);
      expect(AppStrings.messagingSendError, isNotEmpty);
      expect(AppStrings.messagingStartError, isNotEmpty);
      expect(AppStrings.messagingMessageCtaProfile, isNotEmpty);
      expect(AppStrings.messagingMessageCtaMarket, isNotEmpty);
    });
  });
}
