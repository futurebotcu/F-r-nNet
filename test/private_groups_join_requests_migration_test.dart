// V1 P1-D — Migration dosyası source-level test.
//
// Bu test migration'ın aktif/inactive olduğunu DOĞRULAMAZ; yalnız dosyanın
// repo'da var olduğunu ve beklenen DDL tanımlarını içerdiğini doğrular.
// Canlı schema durumu Supabase MCP audit ile ayrıca kontrol edilir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 P1-D migration dosyası (source-level)', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'supabase/migrations/'
        '20260517170000_private_groups_join_requests_and_notifications.sql',
      ).readAsStringSync();
    });

    test('group_join_requests tablosunu tanımlar', () {
      expect(sql.contains('CREATE TABLE public.group_join_requests'), isTrue);
      expect(
        sql.contains(
          "CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))",
        ),
        isTrue,
      );
      expect(
        sql.contains(
          'UNIQUE INDEX group_join_requests_group_requester_unique',
        ),
        isTrue,
      );
    });

    test('notifications tablosunu tanımlar', () {
      expect(sql.contains('CREATE TABLE public.notifications'), isTrue);
      expect(
        sql.contains('CREATE INDEX notifications_unread_idx'),
        isTrue,
        reason: 'Partial index unread sayacını O(unread) yapar',
      );
    });

    test('request_group_join RPC tanımlı', () {
      expect(
        sql.contains(
          'CREATE OR REPLACE FUNCTION public.request_group_join',
        ),
        isTrue,
      );
      expect(sql.contains('SECURITY DEFINER'), isTrue);
      expect(sql.contains("'group_is_public'"), isTrue);
      expect(sql.contains("'owner_cannot_request'"), isTrue);
      expect(sql.contains("'already_member'"), isTrue);
    });

    test('decide_group_join_request RPC tanımlı', () {
      expect(
        sql.contains(
          'CREATE OR REPLACE FUNCTION public.decide_group_join_request',
        ),
        isTrue,
      );
      expect(sql.contains("'not_group_owner'"), isTrue);
      expect(sql.contains("'request_not_pending'"), isTrue);
      expect(
        sql.contains('INSERT INTO public.group_members'),
        isTrue,
        reason: 'Approve sırasında member tablosuna ekleme yapar',
      );
      expect(
        sql.contains('ON CONFLICT (group_id, owner_id) DO NOTHING'),
        isTrue,
        reason: 'Idempotent insert',
      );
    });

    test('social_groups SELECT policy discoverable yapılır', () {
      expect(
        sql.contains(
          'DROP POLICY IF EXISTS social_groups_select_visible',
        ),
        isTrue,
      );
      // Yeni policy USING (is_deleted = false) — private branch kaldırıldı.
      // private/owner/member 3'lü USING'ı içermemeli artık.
      final selectPolicyIdx = sql.indexOf(
        'CREATE POLICY social_groups_select_visible',
      );
      expect(selectPolicyIdx, greaterThan(-1));
      final body = sql.substring(
        selectPolicyIdx,
        sql.indexOf('COMMENT ON POLICY', selectPolicyIdx),
      );
      expect(body.contains('USING (is_deleted = false)'), isTrue);
      // is_private = false branch açık select için artık gerekmez.
      expect(body.contains('is_private = false'), isFalse);
    });

    test('group_messages SELECT policy DOKUNULMADI', () {
      // Migration'da group_messages tablosuna ALTER/DROP/CREATE POLICY YOK.
      expect(
        sql.contains('DROP POLICY IF EXISTS group_messages_select_visible'),
        isFalse,
        reason: 'group_messages policy drop edilmemeli',
      );
      expect(
        sql.contains('CREATE POLICY group_messages_select_visible'),
        isFalse,
        reason: 'group_messages policy yeniden oluşturulmamalı',
      );
      expect(
        sql.contains('ALTER TABLE public.group_messages'),
        isFalse,
        reason: 'group_messages tablosu değiştirilmemeli',
      );
    });

    test('RPC execute permission authenticated role\'a verilmiş', () {
      expect(
        sql.contains(
          'GRANT  EXECUTE ON FUNCTION public.request_group_join(uuid, text) TO authenticated;',
        ),
        isTrue,
      );
      expect(
        sql.contains(
          'GRANT  EXECUTE ON FUNCTION public.decide_group_join_request(uuid, boolean) TO authenticated;',
        ),
        isTrue,
      );
    });
  });
}
