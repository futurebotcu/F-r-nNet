// V1 — Job messaging sprint testleri.
//
// Kapsam:
//   1. JobConversation / JobMessage model fromRow + toInsertRow mapping.
//   2. LocalJobMessagingRepository:
//      - startForJobOffer (yeni + dedup mevcut conversation reuse).
//      - sendMessage updates lastMessageAt.
//      - softDeleteMessage sender-only.
//      - closeConversation status='closed'.
//      - kendi ilanına başvuru reddedilir.
//   3. GuardedJobMessagingRepository:
//      - guest start/send/softDelete/close → GuestActionRequiredException.
//      - listMyConversations / listMessages pass-through.
//   4. UI source smoke:
//      - JobsScreen kaynak kodunda StartJobConversationSheet import edilmiş.
//      - JobOpportunityCard kaynak kodunda 'jobsApplyComingSoon' artık snackbar
//        fallback olarak kullanılmıyor (snackbar default davranışı kaldırıldı).
//      - role_panel_cards Mesajlar kartı route'lu (comingSoon değil).
//      - Router /messages + /messages/:id route'larına sahip.
//   5. Migration SQL string-smoke:
//      - RLS enabled.
//      - participant-only select policy.
//      - cross-owner insert policy (recipient = post.owner_id + is_active).
//      - status='open' check on message insert policy.
//      - no `with check (true)` / `using (true)`.

import 'dart:io';

import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/messages/models/job_conversation.dart';
import 'package:firin_defter/features/messages/models/job_message.dart';
import 'package:firin_defter/features/messages/repositories/guarded_job_messaging_repository.dart';
import 'package:firin_defter/features/messages/repositories/local_job_messaging_repository.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobConversation model', () {
    test('fromRow mapping', () {
      final c = JobConversation.fromRow(<String, dynamic>{
        'id': 'c1',
        'related_type': 'job_offer',
        'job_offer_id': 'jo1',
        'initiator_id': 'u_b',
        'recipient_id': 'u_a',
        'status': 'open',
        'last_message_at': '2026-05-16T20:00:00Z',
        'created_at': '2026-05-16T19:55:00Z',
        'updated_at': '2026-05-16T20:00:00Z',
      });
      expect(c.id, 'c1');
      expect(c.relatedType, 'job_offer');
      expect(c.jobOfferId, 'jo1');
      expect(c.jobSeekPostId, isNull);
      expect(c.initiatorId, 'u_b');
      expect(c.recipientId, 'u_a');
      expect(c.isOpen, isTrue);
      expect(c.isClosed, isFalse);
      expect(c.otherPartyId('u_b'), 'u_a');
      expect(c.otherPartyId('u_a'), 'u_b');
      expect(c.lastMessageAt, isNotNull);
    });

    test('toInsertRow yalnız set alanları içerir', () {
      const c = JobConversation(
        relatedType: 'job_seek',
        jobSeekPostId: 'js1',
        initiatorId: 'u_a',
        recipientId: 'u_b',
      );
      final row = c.toInsertRow();
      expect(row['related_type'], 'job_seek');
      expect(row['job_seek_post_id'], 'js1');
      expect(row.containsKey('job_offer_id'), isFalse);
      expect(row['initiator_id'], 'u_a');
      expect(row['recipient_id'], 'u_b');
      expect(row['status'], 'open');
    });
  });

  group('JobMessage model', () {
    test('fromRow mapping', () {
      final m = JobMessage.fromRow(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u_b',
        'body': 'Merhaba',
        'is_deleted': false,
        'created_at': '2026-05-16T20:00:00Z',
      });
      expect(m.id, 'm1');
      expect(m.conversationId, 'c1');
      expect(m.senderId, 'u_b');
      expect(m.body, 'Merhaba');
      expect(m.displayBody, 'Merhaba');
      expect(m.isDeleted, isFalse);
    });

    test('isDeleted → displayBody placeholder', () {
      final m = JobMessage.fromRow(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u_b',
        'body': 'silinen mesaj',
        'is_deleted': true,
      });
      expect(m.isDeleted, isTrue);
      expect(m.displayBody, '[Mesaj silindi]');
    });
  });

  group('LocalJobMessagingRepository', () {
    const offer = JobOfferPost(
      id: 'jo1',
      ownerId: 'u_a',
      title: 'Taş Fırın Ustası',
      roleTitle: 'Ekmek Ustası',
    );
    const seek = JobSeekPost(
      id: 'js1',
      ownerId: 'u_a',
      title: 'İş arıyorum',
    );

    test('startForJobOffer yeni convo açar + first message ekler', () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_b');
      final c = await repo.startForJobOffer(
        offer: offer,
        firstMessage: 'Merhaba, başvurmak istiyorum.',
      );
      expect(c.id, isNotNull);
      expect(c.relatedType, 'job_offer');
      expect(c.jobOfferId, 'jo1');
      expect(c.initiatorId, 'u_b');
      expect(c.recipientId, 'u_a');
      final msgs = await repo.listMessages(c.id!);
      expect(msgs.length, 1);
      expect(msgs.first.body, 'Merhaba, başvurmak istiyorum.');
    });

    test('startForJobOffer dedup: aynı offer + aynı initiator → reuse',
        () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_b');
      final c1 = await repo.startForJobOffer(
        offer: offer,
        firstMessage: 'İlk',
      );
      final c2 = await repo.startForJobOffer(
        offer: offer,
        firstMessage: 'İkinci',
      );
      expect(c2.id, c1.id);
      final msgs = await repo.listMessages(c1.id!);
      expect(msgs.length, 2);
      expect(msgs.map((m) => m.body), ['İlk', 'İkinci']);
    });

    test('startForJobOffer kendi ilanına → throws', () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_a');
      expect(
        () => repo.startForJobOffer(offer: offer, firstMessage: 'Ben kendim'),
        throwsStateError,
      );
    });

    test('startForJobSeek aynı pattern', () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_b');
      final c = await repo.startForJobSeek(
        post: seek,
        firstMessage: 'Sana iş teklifim var',
      );
      expect(c.relatedType, 'job_seek');
      expect(c.jobSeekPostId, 'js1');
    });

    test('sendMessage updates last_message_at', () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_b');
      final c = await repo.startForJobOffer(
        offer: offer,
        firstMessage: 'İlk mesaj',
      );
      await repo.sendMessage(conversationId: c.id!, body: 'ikinci');
      final list = await repo.listMyConversations();
      expect(list.first.lastMessageAt, isNotNull);
    });

    test('softDeleteMessage sender-only', () async {
      final repoB = LocalJobMessagingRepository(selfId: 'u_b');
      final c = await repoB.startForJobOffer(
        offer: offer,
        firstMessage: 'B yazdı',
      );
      final msgs = await repoB.listMessages(c.id!);
      // B kendi mesajını siler — OK.
      await repoB.softDeleteMessage(msgs.first.id!);
      final after = await repoB.listMessages(c.id!);
      expect(after.first.isDeleted, isTrue);
    });

    test('closeConversation → status=closed → send throws', () async {
      final repo = LocalJobMessagingRepository(selfId: 'u_b');
      final c = await repo.startForJobOffer(
        offer: offer,
        firstMessage: 'mesaj',
      );
      await repo.closeConversation(c.id!);
      expect(
        () => repo.sendMessage(conversationId: c.id!, body: 'kapanan'),
        throwsStateError,
      );
    });
  });

  group('GuardedJobMessagingRepository', () {
    const offer = JobOfferPost(
      id: 'jo1',
      ownerId: 'u_a',
      title: 'Ustaaa',
      roleTitle: 'Ekmek',
    );
    const seek = JobSeekPost(id: 'js1', ownerId: 'u_a', title: 'iş arıyorum');

    test('guest → start/send/softDelete/close throws GuestActionRequiredException',
        () async {
      final inner = LocalJobMessagingRepository(selfId: 'u_b');
      final guarded = GuardedJobMessagingRepository(
        inner: inner,
        canWriteCheck: () => false, // guest
      );
      expect(
        () => guarded.startForJobOffer(offer: offer, firstMessage: 'x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.startForJobSeek(post: seek, firstMessage: 'x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.sendMessage(conversationId: 'c1', body: 'x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.softDeleteMessage('m1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.closeConversation('c1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('list/read pass-through (no auth required)', () async {
      final inner = LocalJobMessagingRepository(selfId: 'u_b');
      final guarded = GuardedJobMessagingRepository(
        inner: inner,
        canWriteCheck: () => false, // guest
      );
      // Liste/read guest için izin verilir, sadece boş döner.
      final list = await guarded.listMyConversations();
      expect(list, isEmpty);
      final msgs = await guarded.listMessages('non-existent');
      expect(msgs, isEmpty);
    });

    test('auth user → start passes through', () async {
      final inner = LocalJobMessagingRepository(selfId: 'u_b');
      final guarded = GuardedJobMessagingRepository(
        inner: inner,
        canWriteCheck: () => true,
      );
      final c = await guarded.startForJobOffer(
        offer: offer,
        firstMessage: 'merhaba',
      );
      expect(c.id, isNotNull);
    });
  });

  group('UI source smoke — job messaging wiring', () {
    test('JobsScreen imports StartJobConversationSheet + uses it', () {
      final src =
          File('lib/features/jobs/screens/jobs_screen.dart').readAsStringSync();
      expect(src.contains('start_job_conversation_sheet.dart'), isTrue,
          reason: 'JobsScreen StartJobConversationSheet import etmeli');
      expect(src.contains('StartJobConversationSheet.showForOffer'), isTrue,
          reason: 'JobsScreen offer kartı sheet açmalı');
      expect(src.contains('StartJobConversationSheet.showForSeek'), isTrue,
          reason: 'JobsScreen seek kartı sheet açmalı');
    });

    test('JobOpportunityCard artık jobsApplyComingSoon snackbar göstermiyor',
        () {
      final src =
          File('lib/core/widgets/premium/job_opportunity_card.dart')
              .readAsStringSync();
      // onApply parent'tan geçilmezse CTA hiç render edilmez; eski snackbar
      // fallback kaldırıldı.
      expect(src.contains('jobsApplyComingSoon'), isFalse,
          reason: 'Snackbar fallback kaldırılmış olmalı');
      expect(src.contains('if (onApply != null)'), isTrue,
          reason: 'onApply null ise CTA gizli');
    });

    test('role_panel_cards Mesajlar route bağlı (comingSoon değil)', () {
      final src =
          File('lib/features/dashboard/services/role_panel_cards.dart')
              .readAsStringSync();
      // cardMessages tile artık route='/messages' kullanmalı.
      expect(src.contains('route: AppRoutes.messages'), isTrue);
    });

    test('Router /messages + /messages/:id route\'larına sahip', () {
      final src =
          File('lib/app/router/app_router.dart').readAsStringSync();
      expect(src.contains("messages = '/messages'"), isTrue);
      expect(src.contains("'/messages/:id'"), isTrue);
      expect(src.contains('MessagesListScreen()'), isTrue);
      expect(src.contains('JobConversationScreen('), isTrue);
    });
  });

  group('Migration SQL — job_messaging_v1 smoke', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20260516200000_job_messaging_v1.sql')
          .readAsStringSync()
          .toLowerCase();
    });

    test('tables + RLS enabled', () {
      expect(sql.contains('create table public.job_conversations'), isTrue);
      expect(sql.contains('create table public.job_messages'), isTrue);
      expect(
          sql.contains('alter table public.job_conversations enable row level security'),
          isTrue);
      expect(
          sql.contains('alter table public.job_messages      enable row level security'),
          isTrue);
    });

    test('participant select policy + initiator insert + cross-owner check',
        () {
      // job_conversations select: participant only.
      expect(
          sql.contains('job_conversations_select_participant'), isTrue);
      // insert: initiator = auth.uid(), recipient farklı, post owner check.
      expect(sql.contains('initiator_id = auth.uid()'), isTrue);
      expect(sql.contains('recipient_id <> auth.uid()'), isTrue);
      expect(sql.contains('p.owner_id = recipient_id'), isTrue);
      // job_offer + job_seek branch'leri kontrol.
      expect(sql.contains("related_type = 'job_offer'"), isTrue);
      expect(sql.contains("related_type = 'job_seek'"), isTrue);
      // Aktiflik kontrol.
      expect(sql.contains('p.is_active = true'), isTrue);
    });

    test('message insert policy: sender + participant + status=open', () {
      expect(sql.contains('job_messages_insert_sender'), isTrue);
      expect(sql.contains('sender_id = auth.uid()'), isTrue);
      expect(sql.contains("c.status = 'open'"), isTrue);
    });

    test('message update policy sender-only', () {
      expect(sql.contains('job_messages_update_owner_softdelete'), isTrue);
    });

    test('no with check (true) / using (true)', () {
      expect(sql.contains('with check (true)'), isFalse);
      expect(sql.contains('using (true)'), isFalse);
    });

    test('trigger bumps last_message_at + grants authenticated', () {
      expect(sql.contains('bump_job_conversation_last_message'), isTrue);
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains('set search_path = public'), isTrue);
      expect(sql.contains('grant select, insert, update on public.job_conversations to authenticated'),
          isTrue);
      expect(sql.contains('grant select, insert, update on public.job_messages to authenticated'),
          isTrue);
    });

    test('unique conversation partial indexes', () {
      expect(sql.contains('uq_job_conversations_offer_initiator'), isTrue);
      expect(sql.contains('uq_job_conversations_seek_initiator'), isTrue);
    });

    test('distinct parties + target consistency constraints', () {
      expect(sql.contains('job_conversations_distinct_parties'), isTrue);
      expect(sql.contains('job_conversations_target_consistency'), isTrue);
    });
  });
}
