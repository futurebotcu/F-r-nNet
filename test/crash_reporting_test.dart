// PR-7B — Crashlytics entegrasyon kontratı (kaynak-assertion).
// Gerçek Crashlytics init Firebase gerektirir (CI'da yok) → wiring + güvenlik
// + gradle conditional + privacy label statik kilitlenir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('pubspec + gradle', () {
    test('firebase_crashlytics bağımlılığı eklendi', () {
      expect(
        _read('pubspec.yaml').contains('firebase_crashlytics:'),
        isTrue,
      );
    });

    test('crashlytics gradle plugin declare + conditional apply', () {
      final settings = _read('android/settings.gradle.kts');
      expect(
        settings.contains('com.google.firebase.crashlytics') &&
            settings.contains('apply false'),
        isTrue,
      );
      final appGradle = _read('android/app/build.gradle.kts');
      // google-services.json varsa (CI'da yok) → conditional apply.
      expect(
        appGradle.contains('apply(plugin = "com.google.firebase.crashlytics")'),
        isTrue,
      );
      expect(appGradle.contains('if (file("google-services.json").exists())'),
          isTrue);
    });
  });

  group('CrashReportingService — wiring + güvenlik', () {
    final src = _read('lib/core/services/crash_reporting_service.dart');

    test('Firebase-ready guard (Firebase yoksa no-op)', () {
      expect(src.contains('Firebase.apps.isEmpty'), isTrue);
    });

    test('debug kapalı / release açık collection', () {
      expect(src.contains('setCrashlyticsCollectionEnabled'), isTrue);
      expect(src.contains('!kDebugMode'), isTrue);
    });

    test('framework + platform uncaught error yakalanır', () {
      expect(src.contains('FlutterError.onError'), isTrue);
      expect(src.contains('recordFlutterFatalError'), isTrue);
      expect(src.contains('PlatformDispatcher.instance.onError'), isTrue);
      expect(src.contains('recordError('), isTrue);
    });

    test('GİZLİLİK: PII/userIdentifier set EDİLMEZ (gerçek çağrı yok)', () {
      // Yorumda geçebilir; ASIL kontrol: çağrı (`.setUserIdentifier(`) yok.
      expect(src.contains('.setUserIdentifier('), isFalse);
      expect(src.contains('.setCustomKey('), isFalse);
    });
  });

  group('main bootstrap', () {
    final main = _read('lib/main.dart');
    test('Firebase init SONRASI CrashReportingService.init()', () {
      expect(main.contains('CrashReportingService.init()'), isTrue);
      // Sıra: initFirebase() önce, crash init sonra.
      expect(
        main.indexOf('PushNotificationService.initFirebase()') <
            main.indexOf('CrashReportingService.init()'),
        isTrue,
      );
    });
  });

  group('privacy label', () {
    test('Crash Data güncellendi (kullanıcıya bağlanmaz)', () {
      final doc = _read('docs/store/PRIVACY_LABEL_DRAFT.md');
      expect(doc.contains('Crash Data'), isTrue);
      expect(doc.contains('Crashlytics'), isTrue);
    });
  });
}
