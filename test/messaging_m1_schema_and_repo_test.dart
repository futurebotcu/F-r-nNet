// FırınNet Messaging M1 — schema + repository invariants.
//
// 4 alan: migration source, model behavior, local repo behavior,
// supabase repo source hardening, providers/pubspec wiring.

import 'dart:io';

import 'package:firin_defter/features/messaging/models/conversation.dart';
import 'package:firin_defter/features/messaging/models/conversation_participant.dart';
import 'package:firin_defter/features/messaging/models/message.dart';
import 'package:firin_defter/features/messaging/repositories/guarded_messaging_repository.dart';
import 'package:firin_defter/features/messaging/repositories/local_messaging_repository.dart';
import 'package:firin_defter/features/messaging/repositories/messaging_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M1 — Migration dosyası', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260520160000_messaging_m1_generic.sql',
      ).readAsStringSync();
    });

    test('3 tablo create var', () {
      expect(sql.contains('create table if not exists public.conversations'),
          isTrue);
      expect(
          sql.contains(
              'create table if not exists public.conversation_participants'),
          isTrue);
      expect(sql.contains('create table if not exists public.messages'),
          isTrue);
    });

    test('Context whitelist + cross-field CHECK', () {
      expect(
          sql.contains(
              "context_type in ('market_listing','profile_direct','job_offer','job_seek')"),
          isTrue);
      expect(sql.contains('conversations_context_invariant'), isTrue);
      expect(sql.contains("context_type = 'profile_direct' and context_id is null"),
          isTrue);
    });

    test('messages V1 message_type sadece text + system + content 1-4000',
        () {
      expect(sql.contains("message_type in ('text','system')"), isTrue);
      expect(sql.contains('length(content) between 1 and 4000'), isTrue);
    });

    test('Indexler tanımlı', () {
      expect(sql.contains('messages_conv_created_idx'), isTrue);
      expect(sql.contains('conv_updated_idx'), isTrue);
      expect(sql.contains('participants_user_idx'), isTrue);
    });

    test('SECURITY DEFINER + search_path hardening', () {
      // Tüm SECURITY DEFINER fn'lerin search_path set olmalı.
      final fnRegions = sql
          .split(RegExp(r'create or replace function'))
          .where((s) => s.contains('security definer'))
          .toList();
      expect(fnRegions, isNotEmpty);
      for (final r in fnRegions) {
        expect(r.contains('set search_path = public, pg_temp'), isTrue,
            reason:
                'SECURITY DEFINER fonksiyonda search_path zorunlu (hardening Q1)');
      }
    });

    test('is_in_conversation stable + grant authenticated', () {
      expect(sql.contains('function public.is_in_conversation'), isTrue);
      // stable kelimesi fn body içinde olmalı.
      final region = sql.substring(
        sql.indexOf('function public.is_in_conversation'),
      );
      final endIdx = region.indexOf(r'$$;') + 3;
      final body = region.substring(0, endIdx);
      expect(body.contains('stable'), isTrue);
      expect(body.contains('security definer'), isTrue);
      expect(
        sql.contains(
            'grant execute on function public.is_in_conversation(uuid) to authenticated'),
        isTrue,
      );
    });

    test('find_or_create_direct_conversation hardening', () {
      expect(
        sql.contains('function public.find_or_create_direct_conversation'),
        isTrue,
      );
      expect(sql.contains('cannot direct-message self'), isTrue);
      expect(sql.contains('target profile not found'), isTrue);
      expect(sql.contains('invalid context_type'), isTrue);
      // market_listing context owner doğrulaması
      expect(sql.contains('market_listing context invalid'), isTrue);
      expect(
        sql.contains('ml.owner_id = p_other_user'),
        isTrue,
        reason: 'p_other_user market_listing owner olmalı',
      );
      // pg_advisory_xact_lock race-free dedupe
      expect(sql.contains('pg_advisory_xact_lock'), isTrue);
      expect(sql.contains('hashtextextended'), isTrue);
    });

    test('messages_insert_sender WITH CHECK sadece text', () {
      expect(
        sql.contains("message_type = 'text'"),
        isTrue,
        reason:
            'Client system message attığı için RLS sadece text WITH CHECK eder',
      );
      // Policy WITH CHECK içinde "in ('text','system')" kalıbı OLMAMALI.
      // Sadece create policy bloğunu izole et (yorumlar dışarıda kalsın):
      // `create policy messages_insert_sender` ... `with check ( ... );`
      final createIdx =
          sql.indexOf('create policy messages_insert_sender');
      expect(createIdx, greaterThanOrEqualTo(0));
      final policyBlock = sql.substring(createIdx);
      final endIdx = policyBlock.indexOf(');');
      final policy = policyBlock.substring(0, endIdx + 2);
      expect(
        policy.contains("message_type in ('text','system')"),
        isFalse,
        reason: 'Insert policy hem text hem system kabul etmemeli (V1: text)',
      );
      expect(
        policy.contains("message_type = 'text'"),
        isTrue,
        reason: 'Insert policy sadece text bekler',
      );
    });

    test('conversations UPDATE policy YOK (default deny)', () {
      // create policy ... on public.conversations for update aranır;
      // bulunmamalı.
      final updateRegex = RegExp(
        r'create\s+policy\s+\w+\s+on\s+public\.conversations\s+for\s+update',
        caseSensitive: false,
      );
      expect(updateRegex.hasMatch(sql), isFalse,
          reason: 'V1 conversations UPDATE kullanıcıya kapalı');
    });

    test('Realtime publication idempotent DO block', () {
      expect(sql.contains('pg_publication_tables'), isTrue);
      expect(
        sql.contains(
            'alter publication supabase_realtime add table public.messages'),
        isTrue,
      );
    });
  });

  group('M1 — Models', () {
    test('Conversation defaults + helpers', () {
      final c = Conversation(
        id: 'c1',
        type: 'direct',
        contextType: 'profile_direct',
        createdAt: DateTime.utc(2026, 5, 20),
        updatedAt: DateTime.utc(2026, 5, 20),
      );
      expect(c.isDirect, isTrue);
      expect(c.isProfileDirectContext, isTrue);
      expect(c.hasUnread, isFalse);
    });

    test('Conversation fromRow + sidecar', () {
      final c = Conversation.fromRow(<String, dynamic>{
        'id': 'c1',
        'type': 'direct',
        'context_type': 'market_listing',
        'context_id': 'ml-1',
        'created_at': '2026-05-20T10:00:00Z',
        'updated_at': '2026-05-20T11:00:00Z',
      }, otherUserId: 'u2', unreadCount: 3);
      expect(c.isMarketListingContext, isTrue);
      expect(c.contextId, 'ml-1');
      expect(c.otherUserId, 'u2');
      expect(c.unreadCount, 3);
      expect(c.hasUnread, isTrue);
    });

    test('Message toInsertRow message_type=text sabit', () {
      final m = Message(
        id: '_',
        conversationId: 'c1',
        senderId: 'u1',
        content: 'merhaba',
        createdAt: DateTime.utc(2026, 5, 20),
      );
      final row = m.toInsertRow(
        senderId: 'u1',
        conversationId: 'c1',
        content: 'merhaba',
      );
      expect(row['message_type'], 'text',
          reason: 'V1 client sadece text yazar');
    });

    test('Message fromRow soft-delete flag', () {
      final m = Message.fromRow(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'hi',
        'message_type': 'text',
        'created_at': '2026-05-20T10:00:00Z',
        'deleted_at': '2026-05-20T11:00:00Z',
      });
      expect(m.isDeleted, isTrue);
      expect(m.isText, isTrue);
    });

    test('ConversationParticipant fromRow', () {
      final p = ConversationParticipant.fromRow(<String, dynamic>{
        'conversation_id': 'c1',
        'user_id': 'u1',
        'role': 'owner',
        'joined_at': '2026-05-20T10:00:00Z',
      });
      expect(p.isOwner, isTrue);
      expect(p.lastReadAt, isNull);
    });
  });

  group('M1 — LocalMessagingRepository davranışı', () {
    test('findOrCreate dedupe + cannot DM self', () async {
      final repo = LocalMessagingRepository(meId: 'me');
      final id1 = await repo.findOrCreateDirectConversation(
        otherUserId: 'u2',
        contextType: 'profile_direct',
      );
      final id2 = await repo.findOrCreateDirectConversation(
        otherUserId: 'u2',
        contextType: 'profile_direct',
      );
      expect(id1, equals(id2),
          reason: 'Aynı (me, u2, profile_direct) için tek conversation');

      expect(
        () => repo.findOrCreateDirectConversation(otherUserId: 'me'),
        throwsA(isA<StateError>()),
      );
    });

    test('Market context profile_direct ile çelişirse hata', () async {
      final repo = LocalMessagingRepository(meId: 'me');
      expect(
        () => repo.findOrCreateDirectConversation(
          otherUserId: 'u2',
          contextType: 'profile_direct',
          contextId: 'ml-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.findOrCreateDirectConversation(
          otherUserId: 'u2',
          contextType: 'market_listing',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sendTextMessage + listMessages + bump updated_at', () async {
      final repo = LocalMessagingRepository(meId: 'me');
      final cid = await repo.findOrCreateDirectConversation(
        otherUserId: 'u2',
      );
      final m = await repo.sendTextMessage(
        conversationId: cid,
        content: 'merhaba',
      );
      expect(m.content, 'merhaba');
      expect(m.messageType, 'text');
      final list = await repo.listMessages(cid);
      expect(list, hasLength(1));
      expect(list.first.id, m.id);
      final conv = await repo.getConversation(cid);
      expect(conv, isNotNull);
      expect(conv!.lastMessageContent, 'merhaba');
    });

    test('unread + markAsRead semantiği', () async {
      final me = LocalMessagingRepository(meId: 'me');
      // İki repo aynı in-memory paylaşmıyor — bu testte sadece self
      // unread mantığı doğrulanır.
      final cid = await me.findOrCreateDirectConversation(otherUserId: 'them');
      await me.sendTextMessage(conversationId: cid, content: 'a');
      // Kendi mesajım unread sayılmaz
      expect(await me.unreadCount(cid), 0);
      // markAsRead idempotent
      await me.markAsRead(cid);
      expect(await me.unreadCount(cid), 0);
    });

    test('Soft delete sender-only', () async {
      final repo = LocalMessagingRepository(meId: 'me');
      final cid = await repo.findOrCreateDirectConversation(otherUserId: 'u2');
      final m = await repo.sendTextMessage(
        conversationId: cid,
        content: 'sil beni',
      );
      await repo.softDeleteMessage(m.id);
      final list = await repo.listMessages(cid);
      expect(list, isEmpty,
          reason: 'Soft-deleted mesaj listMessages\'tan filtrelenir');
    });

    test('content length 1..4000 zorlanır', () async {
      final repo = LocalMessagingRepository(meId: 'me');
      final cid = await repo.findOrCreateDirectConversation(otherUserId: 'u2');
      expect(
        () => repo.sendTextMessage(conversationId: cid, content: ''),
        throwsA(isA<ArgumentError>()),
      );
      final big = 'x' * 4001;
      expect(
        () => repo.sendTextMessage(conversationId: cid, content: big),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('M1 — Supabase repo source hardening', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/messaging/repositories/supabase_messaging_repository.dart',
      ).readAsStringSync();
    });

    test('findOrCreate RPC çağrısı + null guard', () {
      // Boşluk-toleranslı: RPC çağrısı V1.1'de try/catch ile sarıldı (çift
      // yön block map'i), girinti değişti ama sözleşme aynı.
      expect(src.contains('rpc<dynamic>('), isTrue);
      expect(
        src.contains("'find_or_create_direct_conversation'"),
        isTrue,
      );
      expect(
        src.contains('find_or_create_direct_conversation returned null'),
        isTrue,
      );
    });

    test('sendTextMessage .select + StateError on empty (silent-fail guard)',
        () {
      expect(src.contains('message insert returned no row'), isTrue);
      expect(src.contains("'message_type': 'text'"), isTrue,
          reason: 'Insert payload sadece text, defansif');
    });

    test('softDelete .select(id) + sender enforcement', () {
      expect(src.contains("eq('sender_id', meId)"), isTrue);
      expect(
        src.contains('soft delete failed: message not found or not sender'),
        isTrue,
      );
    });

    test('Realtime postgres_changes filter conversation_id eq', () {
      expect(src.contains('PostgresChangeEvent.insert'), isTrue);
      expect(src.contains("table: 'messages'"), isTrue);
      expect(src.contains('PostgresChangeFilterType.eq'), isTrue);
      expect(src.contains("column: 'conversation_id'"), isTrue);
    });

    test('listMessages deleted_at IS NULL + ascending order', () {
      expect(src.contains("isFilter('deleted_at', null)"), isTrue);
      expect(src.contains("order('created_at', ascending: true)"), isTrue);
    });
  });

  group('M1 — Guarded delegator guest guards', () {
    test('Write metodlar _requireWrite çağrısı + read direkt', () {
      final src = File(
        'lib/features/messaging/repositories/guarded_messaging_repository.dart',
      ).readAsStringSync();
      // Writes
      for (final action in const [
        'findOrCreateDirectConversation',
        'sendTextMessage',
        'markAsRead',
        'softDeleteMessage',
      ]) {
        expect(src.contains(action), isTrue);
      }
      expect('_requireWrite('.allMatches(src).length, greaterThanOrEqualTo(4));
      // Reads — guard yok
      for (final action in const [
        'listConversations',
        'getConversation',
        'listMessages',
        'unreadCount',
        'watchMessages',
        'watchConversationsTick',
      ]) {
        expect(src.contains(action), isTrue);
      }
    });
  });

  group('M1 — Providers + pubspec', () {
    test('Provider dosyası beklenen 6 provider tanımlar', () {
      final src = File(
        'lib/features/messaging/providers/messaging_providers.dart',
      ).readAsStringSync();
      for (final name in const [
        'messagingRepositoryProvider',
        'messagingChangesProvider',
        'conversationsListProvider',
        'conversationByIdProvider',
        'messagesListProvider',
        'messagesStreamProvider',
        'conversationUnreadProvider',
      ]) {
        expect(src.contains(name), isTrue, reason: 'provider $name eksik');
      }
    });

    test('pubspec flutter_chat_ui + flutter_chat_core eklenmiş', () {
      final ps = File('pubspec.yaml').readAsStringSync();
      expect(ps.contains('flutter_chat_ui:'), isTrue);
      expect(ps.contains('flutter_chat_core:'), isTrue);
    });

    test('THIRD_PARTY_NOTICES flyer.chat + insideapp-srl attribution', () {
      final t = File('THIRD_PARTY_NOTICES.md').readAsStringSync();
      expect(t.contains('flutter_chat_ui'), isTrue);
      expect(t.contains('flutter_chat_core'), isTrue);
      expect(t.contains('Apache-2.0'), isTrue);
      expect(t.contains('flutter_supabase_chat_core'), isTrue,
          reason: 'insideapp-srl pattern referansı attribution');
    });
  });

  group('M1 — Repository interface yüzeyi', () {
    test('Beklenen 9 method tanımlı', () {
      // Interface kontrolü — dummy implementer ile satır sayısı yerine
      // method varlığını teyit.
      MessagingRepository repo = LocalMessagingRepository(meId: 'me');
      // Sadece public sembolleri çağrılabilir mi diye
      expect(repo.findOrCreateDirectConversation, isNotNull);
      expect(repo.listConversations, isNotNull);
      expect(repo.getConversation, isNotNull);
      expect(repo.listMessages, isNotNull);
      expect(repo.sendTextMessage, isNotNull);
      expect(repo.markAsRead, isNotNull);
      expect(repo.unreadCount, isNotNull);
      expect(repo.softDeleteMessage, isNotNull);
      expect(repo.watchMessages, isNotNull);
      expect(repo.watchConversationsTick, isNotNull);
    });

    test('Guarded sarmalı doğru wire eder', () {
      final inner = LocalMessagingRepository(meId: 'me');
      final guarded =
          GuardedMessagingRepository(inner: inner, canWriteCheck: () => false);
      expect(
        () => guarded.findOrCreateDirectConversation(otherUserId: 'u2'),
        throwsA(isA<Exception>()),
        reason: 'canWriteCheck=false ise write reddedilmeli',
      );
    });
  });
}
