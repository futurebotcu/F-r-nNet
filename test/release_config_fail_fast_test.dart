// Final audit P0-1 — release build production config'siz SESSİZCE mock/local
// moda düşmemeli.

import 'dart:io';

import 'package:firin_defter/core/config/app_config.dart';
import 'package:firin_defter/core/config/config_error_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.releaseConfigError', () {
    test('debug: config yoksa hata yok (dev fallback korunur)', () {
      expect(
        AppConfig.releaseConfigError(isRelease: false, url: '', anonKey: ''),
        isNull,
      );
    });

    test('release: SUPABASE_URL eksik → fail', () {
      expect(
        AppConfig.releaseConfigError(isRelease: true, url: '', anonKey: 'k'),
        contains('SUPABASE_URL'),
      );
    });

    test('release: SUPABASE_ANON_KEY eksik → fail', () {
      expect(
        AppConfig.releaseConfigError(
          isRelease: true,
          url: 'https://x.supabase.co',
          anonKey: '  ',
        ),
        contains('SUPABASE_ANON_KEY'),
      );
    });

    test('release: http/bozuk URL → fail', () {
      expect(
        AppConfig.releaseConfigError(
          isRelease: true,
          url: 'http://x.supabase.co',
          anonKey: 'k',
        ),
        isNotNull,
      );
    });

    test('release: tam config → ok; hata mesajı değeri içermez', () {
      expect(
        AppConfig.releaseConfigError(
          isRelease: true,
          url: 'https://x.supabase.co',
          anonKey: 'secret-ish',
        ),
        isNull,
      );
      final err = AppConfig.releaseConfigError(
        isRelease: true,
        url: '',
        anonKey: 'secret-ish',
      );
      expect(err, isNot(contains('secret-ish')));
    });
  });

  testWidgets('ConfigErrorApp engelleyici ekran gösterir', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(reason: 'SUPABASE_URL eksik'));
    expect(find.byKey(const ValueKey('config_error_title')), findsOneWidget);
  });

  test(
    'main.dart release config kontrolünü Supabase init/runApp öncesi yapar',
    () {
      final src = File('lib/main.dart').readAsStringSync();
      final check = src.indexOf(
        'AppConfig.releaseConfigError(isRelease: kReleaseMode)',
      );
      expect(check, greaterThan(0));
      expect(check, lessThan(src.indexOf('Supabase.initialize')));
      expect(check, lessThan(src.indexOf('runApp(const ProviderScope')));
    },
  );

  test('Gradle release task dart-define eksikse fail eder', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('"dart-defines"'));
    expect(gradle, contains('listOf("SUPABASE_URL", "SUPABASE_ANON_KEY")'));
  });
}
