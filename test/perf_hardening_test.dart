// FırınNet Perf Hardening — signed URL cache + N+1 RPC source contracts.

import 'dart:io';

import 'package:firin_defter/features/messaging/services/chat_media_signed_url_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Perf — ChatMediaSignedUrlCache', () {
    late ChatMediaSignedUrlCache cache;
    var signCalls = 0;
    var fakeNow = 1000000;

    setUp(() {
      cache = ChatMediaSignedUrlCache.instance;
      cache.clear();
      cache.nowMs = () => fakeNow;
      signCalls = 0;
    });

    Future<String> sign(String path) async {
      signCalls++;
      return 'signed://$path/$signCalls';
    }

    test('ilk istek imzalar (miss), aynı path tekrar cache hit', () async {
      final a = await cache.resolve('p1', sign);
      final b = await cache.resolve('p1', sign);
      expect(signCalls, 1, reason: 'İkinci istek yeniden imzalamamalı');
      expect(a, b);
      expect(cache.hits, 1);
      expect(cache.misses, 1);
    });

    test('farklı path ayrı imzalanır', () async {
      await cache.resolve('p1', sign);
      await cache.resolve('p2', sign);
      expect(signCalls, 2);
    });

    test('20 medya ilk açılış 20 imza; aynı oturum tekrar açılış 0', () async {
      for (var i = 0; i < 20; i++) {
        await cache.resolve('m$i', sign);
      }
      expect(signCalls, 20, reason: 'İlk açılış: her medya bir imza');
      final firstRound = signCalls;
      // Aynı oturumda yeniden açılış — hepsi cache hit.
      for (var i = 0; i < 20; i++) {
        await cache.resolve('m$i', sign);
      }
      expect(signCalls, firstRound,
          reason: 'İkinci açılış: 0 ek imza (storm engellendi)');
      expect(cache.hits, 20);
    });

    test('TTL dolunca yeniden imzalar (expired URL servis edilmez)', () async {
      await cache.resolve('p1', sign);
      expect(signCalls, 1);
      // TTL'i aş (signExpiresSeconds - 600) * 1000 ms.
      fakeNow += (ChatMediaSignedUrlCache.signExpiresSeconds - 600) * 1000 + 1;
      await cache.resolve('p1', sign);
      expect(signCalls, 2, reason: 'Süresi geçmiş giriş yeniden imzalanmalı');
    });

    test('clear (logout) cache\'i boşaltır → yeniden imza', () async {
      await cache.resolve('p1', sign);
      cache.clear();
      expect(cache.size, 0);
      await cache.resolve('p1', sign);
      expect(signCalls, 2, reason: 'Logout sonrası bayat URL taşınmamalı');
    });

    test('TTL signed-URL ömründen kısa (erken yeniden imzalama emniyeti)', () {
      // Cache TTL < signExpires → URL gerçekten expire olmadan tazelenir.
      const ttlMs =
          (ChatMediaSignedUrlCache.signExpiresSeconds - 600) * 1000;
      expect(ttlMs, lessThan(ChatMediaSignedUrlCache.signExpiresSeconds * 1000));
    });
  });

  group('Perf — source contracts', () {
    String src(String p) => File(p).readAsStringSync();

    test('listConversations: N+1 döngüsü yerine tek RPC', () {
      final s = src(
        'lib/features/messaging/repositories/supabase_messaging_repository.dart',
      );
      expect(s.contains("rpc<dynamic>(\n      'messages_last_per_conversation'"),
          isTrue);
      // Eski per-conv döngü kalmamalı.
      expect(
        s.contains('for (final cid in myConvIds)'),
        isFalse,
        reason: 'Konuşma başına son-mesaj döngüsü kaldırılmalı (N+1)',
      );
    });

    test('migration: RPC SECURITY INVOKER + DISTINCT ON', () {
      final sql = src(
        'supabase/migrations/'
        '20260612050000_perf_messages_last_per_conversation.sql',
      );
      expect(sql.contains('security invoker'), isTrue,
          reason: 'RLS korunmalı, privilege escalation olmamalı');
      expect(sql.contains('distinct on (m.conversation_id)'), isTrue);
    });

    test('her iki repo + upload servisi cache kullanır', () {
      final m = src(
        'lib/features/messaging/repositories/supabase_messaging_repository.dart',
      );
      final g = src(
        'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
      );
      final u = src(
        'lib/features/messaging/services/chat_media_upload_service.dart',
      );
      for (final s in [m, g, u]) {
        expect(s.contains('ChatMediaSignedUrlCache.instance'), isTrue);
      }
    });

    test('logout cache temizler', () {
      final s = src('lib/features/auth/services/auth_actions.dart');
      expect(s.contains('ChatMediaSignedUrlCache.instance.clear()'), isTrue);
    });
  });
}
