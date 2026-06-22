// Push notifications PR-2 — FCM dispatch wiring kontratı (kaynak-assertion).
//
// Edge function (Deno) + dispatch trigger + tap handling birim test edilemez
// (platform/runtime); kontrat kaynak seviyesinde garanti edilir. Gerçek push
// = secret + cihaz smoke.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Migration — notification_push_dispatch', () {
    final src = _read(
      'supabase/migrations/20260622090000_notification_push_dispatch.sql',
    );
    test('pg_net + delivery table + dedup + RLS', () {
      expect(src.contains('create extension if not exists pg_net'), isTrue);
      expect(
        src.contains('create table if not exists public.notification_push_deliveries'),
        isTrue,
      );
      // Duplicate guard.
      expect(src.contains('unique (notification_id, token_id)'), isTrue);
      expect(src.contains('enable row level security'), isTrue);
      expect(src.contains('npd_select_own'), isTrue);
      for (final c in ['notification_id', 'user_id', 'token_id', 'status', 'error', 'sent_at']) {
        expect(src.contains(c), isTrue, reason: '$c eksik');
      }
    });

    test('dispatch trigger — exception-guard (in-app bozulmaz)', () {
      expect(src.contains('dispatch_notification_push'), isTrue);
      expect(src.contains('after insert on public.notifications'), isTrue);
      expect(src.contains('net.http_post'), isTrue);
      // Vault'tan url/key + tam exception guard.
      expect(src.contains('vault.decrypted_secrets'), isTrue);
      expect(src.contains('exception when others then'), isTrue);
      expect(src.contains('security definer'), isTrue);
    });
  });

  group('Edge function — push-dispatch', () {
    final src = _read('supabase/functions/push-dispatch/index.ts');
    test('FCM HTTP v1 + service account OAuth', () {
      expect(src.contains('fcm.googleapis.com/v1/projects/'), isTrue);
      expect(src.contains('firebase.messaging'), isTrue);
      expect(src.contains('FIREBASE_SERVICE_ACCOUNT_JSON'), isTrue);
    });
    test('secret yoksa graceful no-op', () {
      expect(src.contains('no_credential'), isTrue);
      expect(src.contains('if (!saRaw)'), isTrue);
    });
    test('duplicate guard + invalid token deactivation + minimal payload', () {
      expect(src.contains('notification_push_deliveries'), isTrue);
      expect(src.contains('UNREGISTERED'), isTrue);
      expect(src.contains('is_active'), isTrue);
      // Minimal payload alanları.
      expect(src.contains('route'), isTrue);
      expect(src.contains('notification_id'), isTrue);
    });
  });

  group('Flutter — tap handling', () {
    test('push servisi terminated + background tap → route', () {
      final s = _read(
        'lib/features/notifications/push/push_notification_service.dart',
      );
      expect(s.contains('getInitialMessage'), isTrue);
      expect(s.contains('onMessageOpenedApp'), isTrue);
      expect(s.contains("message.data['route']"), isTrue);
      // UI-NAV-002: koşulsuz go yerine shell-kök/derin ayrımı yapan helper.
      expect(s.contains('navigateToNotificationRoute(router, route)'), isTrue);
    });

    test('app_router global appRouter referansı', () {
      final r = _read('lib/app/router/app_router.dart');
      expect(r.contains('GoRouter? appRouter;'), isTrue);
      expect(r.contains('appRouter = router;'), isTrue);
    });
  });
}
