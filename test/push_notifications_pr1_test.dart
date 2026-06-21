// Push notifications PR-1 — token kaydı wiring kontratı (kaynak-assertion).
//
// Firebase/FCM platform-channel olduğu için unit test edilemez; bu test
// migration + servis + wiring'in yerinde olduğunu kaynak seviyesinde garanti
// eder. Gerçek token-kaydı cihaz smoke ile doğrulanır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Migration — user_push_tokens', () {
    final src = _read(
      'supabase/migrations/20260621170000_user_push_tokens.sql',
    );
    test('tablo + kolonlar', () {
      expect(src.contains('create table if not exists public.user_push_tokens'),
          isTrue);
      for (final col in [
        'user_id',
        'token',
        'platform',
        'device_id',
        'is_active',
        'created_at',
        'updated_at',
        'last_seen_at',
      ]) {
        expect(src.contains(col), isTrue, reason: '$col eksik');
      }
      expect(src.contains('unique (token)'), isTrue);
    });

    test('RLS owner-only (4 policy)', () {
      expect(src.contains('enable row level security'), isTrue);
      for (final p in [
        'user_push_tokens_select_own',
        'user_push_tokens_insert_own',
        'user_push_tokens_update_own',
        'user_push_tokens_delete_own',
      ]) {
        expect(src.contains(p), isTrue, reason: '$p eksik');
      }
      expect(src.contains('using (user_id = auth.uid())'), isTrue);
    });

    test('RPC register/deactivate — SECURITY DEFINER + anon revoke', () {
      expect(src.contains('function public.register_push_token'), isTrue);
      expect(src.contains('function public.deactivate_push_token'), isTrue);
      expect(src.contains('security definer'), isTrue);
      expect(src.contains('set search_path = public'), isTrue);
      // Token devri (cihaz paylaşımı): başka kullanıcıdan al.
      expect(src.contains('user_id <> auth.uid()'), isTrue);
      expect(
        src.contains('revoke execute on function public.register_push_token'),
        isTrue,
      );
    });
  });

  group('Flutter — push servisi + wiring', () {
    test('PushNotificationService register/deactivate RPC çağırır', () {
      final s = _read(
        'lib/features/notifications/push/push_notification_service.dart',
      );
      expect(s.contains("rpc(\n        'register_push_token'") ||
          s.contains("'register_push_token'"), isTrue);
      expect(s.contains("'deactivate_push_token'"), isTrue);
      expect(s.contains('onTokenRefresh'), isTrue);
      expect(s.contains('requestPermission'), isTrue);
      expect(s.contains('getToken'), isTrue);
      // Background handler (FCM zorunlu).
      expect(s.contains("@pragma('vm:entry-point')"), isTrue);
    });

    test('main.dart Firebase init eder', () {
      final m = _read('lib/main.dart');
      expect(m.contains('PushNotificationService.initFirebase()'), isTrue);
    });

    test('app.dart login\'de registerForUser çağırır', () {
      final a = _read('lib/app/app.dart');
      expect(a.contains('PushNotificationService.registerForUser()'), isTrue);
      expect(a.contains('currentAuthUserProvider'), isTrue);
    });

    test('performSignOut çıkıştan ÖNCE unregister eder', () {
      final a = _read('lib/features/auth/services/auth_actions.dart');
      final idxUnreg = a.indexOf('PushNotificationService.unregister()');
      final idxSignOut = a.indexOf('auth.signOut()');
      expect(idxUnreg, greaterThan(0));
      expect(idxSignOut, greaterThan(0));
      expect(idxUnreg, lessThan(idxSignOut),
          reason: 'unregister, signOut\'tan ÖNCE olmalı (auth.uid() geçerli)');
    });
  });

  group('Android — FCM config', () {
    test('settings.gradle.kts google-services plugin', () {
      final s = _read('android/settings.gradle.kts');
      expect(s.contains('com.google.gms.google-services'), isTrue);
    });

    test('app/build.gradle.kts google-services apply', () {
      final s = _read('android/app/build.gradle.kts');
      expect(s.contains('com.google.gms.google-services'), isTrue);
    });

    test('AndroidManifest POST_NOTIFICATIONS izni', () {
      final s = _read('android/app/src/main/AndroidManifest.xml');
      expect(s.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
    });
  });
}
