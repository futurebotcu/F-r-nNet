// PR-PERM-1 — Android bildirim + kamera izinleri (source/manifest kontratı).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('AndroidManifest izinleri', () {
    final mf = _read('android/app/src/main/AndroidManifest.xml');
    test('POST_NOTIFICATIONS korunur', () {
      expect(mf.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
    });
    test('CAMERA eklendi', () {
      expect(mf.contains('android.permission.CAMERA'), isTrue);
    });
    test('INTERNET korunur', () {
      expect(mf.contains('android.permission.INTERNET'), isTrue);
    });
  });

  group('pubspec', () {
    test('permission_handler bağımlılığı var', () {
      expect(_read('pubspec.yaml').contains('permission_handler:'), isTrue);
    });
  });

  group('AppPermissionService', () {
    final src = _read('lib/core/permissions/app_permission_service.dart');
    test('requestCameraForCapture + red açıklaması', () {
      expect(src.contains('requestCameraForCapture'), isTrue);
      expect(src.contains('Permission.camera.request()'), isTrue);
      expect(src.contains('Kamera izni verilmedi'), isTrue);
      expect(src.contains('openAppSettings'), isTrue);
    });
    test('bildirim wrapper var (push akışını bozmaz)', () {
      expect(src.contains('requestNotificationsIfNeeded'), isTrue);
      expect(src.contains('Permission.notification'), isTrue);
    });
  });

  group('Kamera çekim akışları izin helper çağırır', () {
    final cameraFlows = <String, String>{
      'composer': 'lib/features/social/composer/social_composer_page.dart',
      'story': 'lib/features/social/stories/story_create_page.dart',
      'market': 'lib/features/marketplace/screens/market_listing_form_screen.dart',
      'chat': 'lib/features/messaging/screens/chat_screen.dart',
      'group': 'lib/features/social_groups/screens/group_detail_screen.dart',
    };
    cameraFlows.forEach((name, path) {
      test('$name → requestCameraForCapture', () {
        expect(_read(path).contains('requestCameraForCapture'), isTrue,
            reason: '$name kamera akışında izin helper eksik');
      });
    });

    test('composer: capture (kamera) gate var, capture metodları async', () {
      final s =
          _read('lib/features/social/composer/social_composer_page.dart');
      expect(s.contains('Future<void> _capturePhoto() async'), isTrue);
      expect(s.contains('Future<void> _captureVideo() async'), isTrue);
    });

    test('market/chat/group: gate yalnız ImageSource.camera dalında', () {
      for (final p in const [
        'lib/features/marketplace/screens/market_listing_form_screen.dart',
        'lib/features/messaging/screens/chat_screen.dart',
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ]) {
        final s = _read(p);
        expect(s.contains('ImageSource.camera') && s.contains('requestCameraForCapture'),
            isTrue);
      }
    });
  });

  group('Galeri akışları kamera izni İSTEMEZ', () {
    test('composer galeri pick metodları doğrudan (gate yok)', () {
      final s =
          _read('lib/features/social/composer/social_composer_page.dart');
      // Galeri pick'leri expression-body, izin gate'i yok.
      expect(
        s.contains('_pickImage() => _captureOrPickImage(ImageSource.gallery)'),
        isTrue,
      );
      expect(
        s.contains('_pickVideo() => _captureOrPickVideo(ImageSource.gallery)'),
        isTrue,
      );
    });
    test('avatar (galeri-only) kamera helper kullanmaz', () {
      expect(
        _read('lib/features/profile/services/avatar_upload_service.dart')
            .contains('requestCameraForCapture'),
        isFalse,
      );
    });
    test('b2b media (galeri-only) kamera helper kullanmaz', () {
      expect(
        _read('lib/features/b2b_market/services/b2b_media_upload_service.dart')
            .contains('requestCameraForCapture'),
        isFalse,
      );
    });
  });

  group('Bildirim izni akışı (mevcut push) bozulmadı', () {
    final src = _read(
      'lib/features/notifications/push/push_notification_service.dart',
    );
    test('FirebaseMessaging.requestPermission korunur (Android 13+)', () {
      expect(src.contains('requestPermission()'), isTrue);
    });
    test('token log yalnız uzunluk (değer YOK)', () {
      expect(src.contains('len=\${token.length}'), isTrue);
    });
    test('register guard\'lı (red/hata crash etmez)', () {
      expect(src.contains('catch (e)'), isTrue);
      expect(src.contains('if (!_firebaseReady) return'), isTrue);
    });
  });
}
