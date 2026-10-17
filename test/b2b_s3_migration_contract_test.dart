// S3 — B2B talep/guard/sayfalama/bildirim migration'ı kaynak-sözleşmesi.
//
// Davranış kanıtı: supabase/tests/b2b_requests_s3/run_tests.ps1 (izole
// PostgreSQL üzerinde gerçek migration zinciri + RLS/eşzamanlılık). Bu dosya
// yalnız kritik güvenlik invariant'larını metin düzeyinde kilitler; DB'ye
// bağlanmaz. Migration PRODUCTION'A UYGULANMADI (onay bekliyor).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'supabase/migrations/20261017120000_b2b_s3_requests_v1.sql',
  ).readAsStringSync();
  final lower = src.toLowerCase();
  // Yorum satırları (başlık + ROLLBACK referansı) güvenlik kontrolünden hariç.
  final code = lower
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n');

  group('Additif / güvenli', () {
    test('drop table / delete from / truncate yok', () {
      expect(code.contains('drop table'), isFalse);
      expect(
        RegExp(r'^\s*delete from', multiLine: true).hasMatch(code),
        isFalse,
      );
      expect(code.contains('truncate'), isFalse);
    });
    test('yeni kolonlar nullable + if not exists; rollback bloğu var', () {
      expect(lower.contains('add column if not exists phone text'), isTrue);
      expect(lower.contains('add column if not exists whatsapp text'), isTrue);
      expect(lower.contains('add column if not exists website text'), isTrue);
      expect(lower.contains('add column if not exists address text'), isTrue);
      expect(lower.contains('b2b_shops_contact_len'), isTrue);
      expect(lower.contains('rollback'), isTrue);
    });
    test('tüm yeni fonksiyonlar search_path sabitli ve SECURITY DEFINER', () {
      final fnCount = RegExp(
        r'create or replace function public\.',
      ).allMatches(lower).length;
      final spCount = RegExp(r"set search_path = ''").allMatches(lower).length;
      expect(fnCount, greaterThanOrEqualTo(8));
      expect(spCount, fnCount);
    });
  });

  group('Kolon guard\'ları', () {
    test('is_verified / owner_id yalnız service_role', () {
      expect(lower.contains('b2b_shops_guard_columns'), isTrue);
      expect(
        lower.contains('new.is_verified is distinct from old.is_verified'),
        isTrue,
      );
      expect(
        lower.contains('new.owner_id is distinct from old.owner_id'),
        isTrue,
      );
      expect(
        lower.contains('before update on public.b2b_supplier_shops'),
        isTrue,
      );
    });
    test('reply INSERT guard: status sent, accepted false', () {
      expect(lower.contains('b2b_replies_guard_insert'), isTrue);
      expect(lower.contains("new.status := 'sent'"), isTrue);
      expect(lower.contains('new.accepted := false'), isTrue);
      expect(
        lower.contains('before insert on public.b2b_quote_replies'),
        isTrue,
      );
    });
    test(
      'talep guard: accepted_reply_id yalnız RPC, buyer_id sabit, geçiş matrisi',
      () {
        expect(lower.contains('b2b_qr_guard_columns'), isTrue);
        expect(
          lower.contains(
            'new.accepted_reply_id is distinct from old.accepted_reply_id',
          ),
          isTrue,
        );
        expect(
          lower.contains('new.buyer_id is distinct from old.buyer_id'),
          isTrue,
        );
        expect(lower.contains("old.status in ('open', 'answered')"), isTrue);
        expect(lower.contains("new.status in ('closed', 'cancelled')"), isTrue);
        expect(
          lower.contains('before update on public.b2b_quote_requests'),
          isTrue,
        );
      },
    );
    test(
      'open→answered meşru yazıcı GUC ile işaretli (S2 kontrolündeki kırılma kapandı)',
      () {
        final i = lower.indexOf('function public.b2b_mark_request_answered');
        expect(i, greaterThan(0));
        final body = lower.substring(i, i + 600);
        expect(
          body.contains("set_config('b2b.reply_write', 'on', true)"),
          isTrue,
        );
        expect(body.contains("set status = 'answered'"), isTrue);
      },
    );
    test('guard trigger fonksiyonları client rollerinden revoke', () {
      for (final fn in [
        'b2b_shops_guard_columns()',
        'b2b_replies_guard_insert()',
        'b2b_qr_guard_columns()',
        'b2b_mark_request_answered()',
        'notify_b2b_quote_request_created()',
      ]) {
        // Satır sonu CRLF/LF ve girinti farklarına dayanıklı.
        final normalized = lower.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          normalized.contains(
            'revoke execute on function public.$fn from public, anon, authenticated',
          ),
          isTrue,
          reason: fn,
        );
      }
    });
  });

  group('Yarış koşulu düzeltmesi (kabul)', () {
    test('talep satırı FOR UPDATE ile kilitlenir ve şartlı güncellenir', () {
      final i = lower.indexOf('function public.b2b_accept_quote_reply');
      expect(i, greaterThan(0));
      final body = lower.substring(i, i + 1600);
      expect(body.contains('for update of qr'), isTrue);
      expect(
        body.contains('where id = v_req and accepted_reply_id is null'),
        isTrue,
      );
      expect(
        body.contains("if not found then raise exception 'already decided'"),
        isTrue,
      );
      expect(
        body.contains("set_config('b2b.reply_write', 'on', true)"),
        isTrue,
      );
    });
  });

  group('RPC — minimum yetki / anonimlik', () {
    test(
      'b2b_my_replied_requests: yalnız kendi mağazası; buyer_id ve accepted_reply_id dönmez',
      () {
        final i = lower.indexOf('function public.b2b_my_replied_requests');
        final body = lower.substring(
          i,
          lower.indexOf(
            'grant execute on function public.b2b_my_replied_requests',
          ),
        );
        final returns = body.substring(
          body.indexOf('returns table'),
          body.indexOf('language sql'),
        );
        expect(returns.contains('buyer_id'), isFalse);
        expect(returns.contains('accepted_reply_id'), isFalse);
        expect(returns.contains('phone'), isFalse);
        expect(body.contains('where s.owner_id = auth.uid()'), isTrue);
        expect(body.contains('auth.uid() is not null'), isTrue);
        expect(
          lower.contains(
            'revoke execute on function public.b2b_my_replied_requests() from public, anon',
          ),
          isTrue,
        );
      },
    );
    test(
      'sayfalama RPC: limit üst sınırı, offset normalizasyonu, exclude_replied',
      () {
        final i = lower.indexOf('function public.b2b_open_quote_requests_page');
        final body = lower.substring(i, i + 2600);
        expect(
          body.contains('limit least(greatest(coalesce(p_limit, 20), 1), 100)'),
          isTrue,
        );
        expect(
          body.contains('offset greatest(coalesce(p_offset, 0), 0)'),
          isTrue,
        );
        expect(body.contains('count(*) over () as total_count'), isTrue);
        expect(body.contains('p_exclude_replied'), isTrue);
        expect(body.contains('qr.accepted_reply_id is null'), isTrue);
        final returns = body.substring(
          body.indexOf('returns table'),
          body.indexOf('language sql'),
        );
        expect(returns.contains('buyer_id'), isFalse);
      },
    );
    test('sayaç RPC + index\'ler', () {
      expect(
        lower.contains('function public.b2b_supplier_request_counts'),
        isTrue,
      );
      expect(lower.contains('idx_b2b_qr_open_cat_city'), isTrue);
      expect(lower.contains('idx_b2b_replies_shop_created'), isTrue);
    });
  });

  group('Yeni talep bildirimi', () {
    test(
      'mevcut notifications tablosu; dedupe index; yoğunluk kapağı; alıcı hariç; generic metin',
      () {
        expect(lower.contains('notifications_b2b_qr_dedupe_idx'), isTrue);
        expect(
          lower.contains("where type = 'b2b_quote_request_created'"),
          isTrue,
        );
        expect(lower.contains('on conflict do nothing'), isTrue);
        expect(lower.contains('if v_recent >= 10'), isTrue);
        expect(
          lower.contains('s.owner_id is distinct from new.buyer_id'),
          isTrue,
        );
        expect(lower.contains("'/pazar?tab=talepler'"), isTrue);
        // Hedefleme: shop/product/campaign → yalnız hedef mağaza.
        expect(
          lower.contains("new.target_type = 'shop' and s.id = new.target_id"),
          isTrue,
        );
        expect(
          lower.contains('after insert on public.b2b_quote_requests'),
          isTrue,
        );
        // actor_id null (anonimlik), not/telefon yok.
        final i = lower.indexOf(
          'function public.notify_b2b_quote_request_created',
        );
        final body = lower.substring(i, i + 2600);
        expect(body.contains('(v_owner, null,'), isTrue);
        expect(body.contains('new.note'), isFalse);
      },
    );
  });
}
