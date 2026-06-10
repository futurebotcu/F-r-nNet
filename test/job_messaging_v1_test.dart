// Job messaging — Sprint E sonrası.
//
// Legacy job_messaging Dart katmanı (JobConversation/JobMessage modelleri,
// Local/Guarded/Supabase JobMessagingRepository, JobConversationScreen,
// /messages/legacy/:id route) Sprint E'de emekliye ayrıldı. Job/İlan
// mesajlaşması Sprint D'den beri GENERIC messaging sisteminden geçer.
//
// Bu dosya artık:
//   1. UI wiring smoke — JobsScreen sheet'i kullanır, generic route, panel.
//   2. Migration SQL smoke — `job_messaging_v1` migration dosyası KORUNUR
//      (DB tabloları drop edilmedi); historical migration sözleşmesi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI source smoke — job messaging wiring (generic)', () {
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

    test('StartJobConversationSheet generic messaging kullanır', () {
      final src = File(
        'lib/features/messages/widgets/start_job_conversation_sheet.dart',
      ).readAsStringSync();
      expect(src.contains('messagingRepositoryProvider'), isTrue);
      expect(src.contains('findOrCreateDirectConversation'), isTrue);
      expect(src.contains('jobMessagingRepositoryProvider'), isFalse,
          reason: 'Sprint D/E: legacy job repo artık kullanılmıyor');
    });

    test('JobOpportunityCard artık jobsApplyComingSoon snackbar göstermiyor',
        () {
      final src = File('lib/core/widgets/premium/job_opportunity_card.dart')
          .readAsStringSync();
      expect(src.contains('jobsApplyComingSoon'), isFalse,
          reason: 'Snackbar fallback kaldırılmış olmalı');
      expect(src.contains('if (onApply != null)'), isTrue,
          reason: 'onApply null ise CTA gizli');
    });

    test('role_panel_cards Mesajlar route bağlı (comingSoon değil)', () {
      final src = File(
        'lib/features/dashboard/services/role_panel_cards.dart',
      ).readAsStringSync();
      expect(src.contains('route: AppRoutes.messages'), isTrue);
    });

    test('Router: generic /messages route\'ları var; legacy kaldırıldı', () {
      final src = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(src.contains("messages = '/messages'"), isTrue);
      expect(src.contains("'/messages/:id'"), isTrue);
      expect(src.contains('MessagesListScreen()'), isTrue);
      // Sprint E — legacy ekran/route kaldırıldı.
      expect(src.contains('JobConversationScreen'), isFalse,
          reason: 'Legacy ekran route\'tan kaldırıldı');
      expect(src.contains('/messages/legacy/'), isFalse,
          reason: 'Legacy route kaldırıldı');
    });
  });

  group('Migration SQL — job_messaging_v1 smoke (DB tabloları korunur)', () {
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
      expect(sql.contains('job_conversations_select_participant'), isTrue);
      expect(sql.contains('initiator_id = auth.uid()'), isTrue);
      expect(sql.contains('recipient_id <> auth.uid()'), isTrue);
      expect(sql.contains('p.owner_id = recipient_id'), isTrue);
      expect(sql.contains("related_type = 'job_offer'"), isTrue);
      expect(sql.contains("related_type = 'job_seek'"), isTrue);
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
