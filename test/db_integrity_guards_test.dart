// PR-4 DB integrity guards — kaynak-assertion'lar.
// FN-AUDIT-011 / 019 / 016 / 009 / 012. RLS/trigger/RPC Dart'ta runtime test
// edilemez; migration + repo köprüsü statik kilitlenir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  final mig = _read(
    'supabase/migrations/20260622180000_db_integrity_guards.sql',
  );
  final ml = mig.toLowerCase();

  group('FN-AUDIT-011 — sosyal sayaç guard', () {
    test('feed_posts + feed_comments counter guard trigger', () {
      expect(ml.contains('feed_guard_server_counters'), isTrue);
      expect(ml.contains('counters are server-managed'), isTrue);
      expect(ml.contains('before update on public.feed_posts'), isTrue);
      expect(ml.contains('before update on public.feed_comments'), isTrue);
      for (final c in ['like_count', 'comment_count', 'repost_count']) {
        expect(ml.contains(c), isTrue, reason: c);
      }
    });
    test('rol-bazlı (INVOKER) kontrol: authenticated/anon bloklanır', () {
      expect(ml.contains("current_user in ('authenticated', 'anon')"), isTrue);
      // Guard fonksiyonu SECURITY DEFINER OLMAMALI (aksi halde current_user
      // hep definer olur). Guard bloğu definer içermez:
      final gStart = ml.indexOf('feed_guard_server_counters');
      final gEnd = ml.indexOf('trg_feed_posts_guard_counters');
      expect(ml.substring(gStart, gEnd).contains('security definer'), isFalse);
    });
  });

  group('FN-AUDIT-019 — job_conversations lifecycle guard', () {
    test('status + last_message_at client UPDATE bloklanır', () {
      expect(ml.contains('job_conversations_guard_lifecycle'), isTrue);
      expect(ml.contains('conversation lifecycle is server-managed'), isTrue);
      expect(ml.contains('new.status is distinct from old.status'), isTrue);
      expect(
        ml.contains('new.last_message_at is distinct from old.last_message_at'),
        isTrue,
      );
      expect(
        ml.contains('before update on public.job_conversations'),
        isTrue,
      );
    });
  });

  group('FN-AUDIT-016 — dealer_transactions amount işaret CHECK', () {
    test('payment/return negatif olamaz; adjustment imzalı', () {
      expect(ml.contains('dealer_transactions_amount_sign'), isTrue);
      expect(ml.contains("type = 'adjustment' or amount >= 0"), isTrue);
    });
  });

  group('FN-AUDIT-009 — driver_add_note owner_id=patron', () {
    test('RPC: SECURITY DEFINER + atama + owner + owner_id=v_owner', () {
      expect(ml.contains('driver_add_note'), isTrue);
      expect(ml.contains('security definer'), isTrue);
      expect(ml.contains("raise exception 'not assigned to this dealer'"),
          isTrue);
      expect(ml.contains("raise exception 'owner mismatch'"), isTrue);
      expect(
        ml.contains('insert into public.dealer_notes(owner_id, dealer_id, note)'),
        isTrue,
      );
      expect(ml.contains('values (v_owner'), isTrue);
      expect(ml.contains('from public, anon'), isTrue);
    });
  });

  group('FN-AUDIT-012 — create_driver_invite enumeration', () {
    test('generic mesaj + saatlik rate-limit', () {
      expect(ml.contains('create_driver_invite'), isTrue);
      expect(ml.contains("interval '1 hour'"), isTrue);
      expect(ml.contains("raise exception 'too many invites'"), isTrue);
      // FN-ID çözüm hataları TEK generic mesaja indirildi.
      expect(ml.contains("raise exception 'invite failed'"), isTrue);
      // Eski ayrıştırıcı (var/yok sızdıran) RAISE'ler olmamalı.
      expect(ml.contains("raise exception 'already a driver'"), isFalse);
      expect(ml.contains("raise exception 'cannot invite self'"), isFalse);
      expect(ml.contains("raise exception 'invite already pending'"), isFalse);
    });
  });

  group('Dart köprü — FN-009 + FN-012', () {
    final repo = _read(
      'lib/features/dealers/repositories/supabase_dealer_repository.dart',
    );
    test('driverAddNote driver_add_note RPC çağırır', () {
      expect(repo.contains("rpc('driver_add_note'"), isTrue);
    });
    test('createDriverInvite mesajı generic (spesifik sızdıran kaldırıldı)', () {
      expect(repo.contains('Bu kullanıcı zaten şoför.'), isFalse);
      expect(repo.contains('Kendini davet edemezsin.'), isFalse);
      expect(repo.contains('Davet oluşturulamadı.'), isTrue);
    });
    test('driver-scoped addNote → driverAddNote köprüsü', () {
      final scoped = _read(
        'lib/features/dealers/repositories/driver_scoped_dealer_repository.dart',
      );
      expect(
        scoped.contains('inner.driverAddNote(dealerId: note.dealerId'),
        isTrue,
      );
    });
  });
}
