// PR-7 — medya upload boyut limiti (MediaLimits) + UAT doc.
// MediaLimits saf-Dart davranış; upload guard'ları + doküman source-assert.

import 'dart:io';

import 'package:firin_defter/core/services/media_limits.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('MediaLimits — davranış', () {
    test('sınır içi byte geçer', () {
      expect(
        () => MediaLimits.ensureImageUnderLimit(MediaLimits.maxImageBytes),
        returnsNormally,
      );
      expect(() => MediaLimits.ensureImageUnderLimit(0), returnsNormally);
    });

    test('sınır üstü byte → MediaTooLargeException', () {
      expect(
        () => MediaLimits.ensureImageUnderLimit(MediaLimits.maxImageBytes + 1),
        throwsA(isA<MediaTooLargeException>()),
      );
    });

    test('sabitler makul', () {
      expect(MediaLimits.maxImageBytes, 5 * 1024 * 1024);
      expect(MediaLimits.maxVideoBytes, 25 * 1024 * 1024);
    });
  });

  group('Upload servisleri boyut guard çağırıyor', () {
    test('avatar / feed / story / market → ensureImageUnderLimit', () {
      final files = {
        'avatar': 'lib/features/profile/services/avatar_upload_service.dart',
        'feed': 'lib/features/feed/repositories/supabase_feed_repository.dart',
        'story':
            'lib/features/social/stories/repositories/supabase_social_stories_repository.dart',
        'market':
            'lib/features/marketplace/repositories/supabase_market_listing_repository.dart',
      };
      files.forEach((name, path) {
        final src = _read(path);
        expect(
          src.contains('MediaLimits.ensureImageUnderLimit'),
          isTrue,
          reason: '$name upload guard eksik',
        );
      });
    });

    test('b2b + chat zaten kendi byte-limitini uyguluyor (regresyon)', () {
      expect(
        _read('lib/features/b2b_market/services/b2b_media_upload_service.dart')
            .contains('maxBytes'),
        isTrue,
      );
      expect(
        _read('lib/features/messaging/services/chat_media_upload_service.dart')
            .contains('maxVideoBytes'),
        isTrue,
      );
    });
  });

  group('UAT checklist dokümanı', () {
    final doc = _read('docs/UAT_CHECKLIST.md');
    test('tüm roller + kritik akışlar var', () {
      for (final s in [
        'Guest',
        'Bireysel',
        'Ticari / Fırıncı',
        'Tedarikçi',
        'Şoför (half / full)',
        'Push (FCM)',
        'Bayi Defteri',
        'Hesap silme',
        'Crashlytics smoke',
        'Quota',
      ]) {
        expect(doc.contains(s), isTrue, reason: '$s bölümü eksik');
      }
    });
  });
}
