// FN-AUDIT-003 / 014 / 015 — B2B reply hardening migration kaynak-assertion'ı.
//
// RLS/trigger/RPC Dart'ta runtime test edilemez; migration dosyasını statik
// okuyup kritik güvenlik/lifecycle invariant'larını kilitler. Gerçek DB'ye
// bağlanmaz.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'supabase/migrations/20260622160000_b2b_reply_hardening.sql',
  ).readAsStringSync();
  final lower = src.toLowerCase();

  group('FN-AUDIT-015 — mükerrer teklif engeli', () {
    test('unique(quote_request_id, supplier_shop_id)', () {
      expect(
        lower.contains('unique (quote_request_id, supplier_shop_id)'),
        isTrue,
      );
    });
  });

  group('FN-AUDIT-003 — status/accepted buyer-only (guard trigger)', () {
    test('guard fonksiyonu + flag kontrolü', () {
      expect(lower.contains('b2b_replies_guard_status'), isTrue);
      expect(lower.contains("current_setting('b2b.reply_write'"), isTrue);
      expect(
        lower.contains('new.status is distinct from old.status'),
        isTrue,
      );
      expect(
        lower.contains('new.accepted is distinct from old.accepted'),
        isTrue,
      );
      expect(
        lower.contains("raise exception 'reply status/accepted is buyer-controlled'"),
        isTrue,
      );
    });

    test('BEFORE UPDATE trigger + güvenli definer', () {
      expect(
        lower.contains('before update on public.b2b_quote_replies'),
        isTrue,
      );
      expect(lower.contains('security definer'), isTrue);
      expect(lower.contains("set search_path = ''"), isTrue);
    });

    test('accept RPC tek meşru yazar: flag + status/accepted + buyer guard', () {
      expect(lower.contains('b2b_accept_quote_reply'), isTrue);
      expect(lower.contains("set_config('b2b.reply_write', 'on', true)"), isTrue);
      expect(lower.contains('if v_buyer <> v_uid then'), isTrue);
      expect(
        lower.contains("when id = p_reply_id then 'accepted' else 'declined'"),
        isTrue,
      );
      expect(lower.contains("raise exception 'already decided'"), isTrue);
    });
  });

  group('FN-AUDIT-014 — kabul sonrası talep ağdan çıkar', () {
    test('accept = accepted_reply_id ile karara bağlanır', () {
      expect(lower.contains('accepted_reply_id = p_reply_id'), isTrue);
    });

    test('b2b_request_accepts_reply accepted_reply_id null şartı', () {
      expect(lower.contains('b2b_request_accepts_reply'), isTrue);
      // karara bağlanmış (accepted_reply_id dolu) talep yeni teklif kabul etmez.
      expect(lower.contains('accepted_reply_id is null'), isTrue);
    });

    test('teklif ağı (function + view) karara bağlanmışı gizler', () {
      expect(lower.contains('b2b_open_quote_requests'), isTrue);
      // hem function hem view aynı filtreyi taşır (en az 2 kez "accepted_reply_id is null").
      final count = 'accepted_reply_id is null'.allMatches(lower).length;
      expect(count >= 3, isTrue,
          reason: 'accepts_reply + function + view = en az 3 kez');
    });

    test('status korunur (kabul-sonrası lead/iletişim bozulmaz)', () {
      // status=closed YAPMAZ; create_b2b_quote_lead open/answered şartı sürer.
      expect(lower.contains("status = 'closed'"), isFalse);
    });
  });
}
