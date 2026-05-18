// Build Config Hardening — Supabase-disabled APK üretme riskini bitiren
// scriptlerin var olup doğru pattern'i izlediğini source-level garantiler.
//
// Kök neden: `String.fromEnvironment(...)` compile-time çalışır; `.env.local`
// otomatik okunmaz. Plain `flutter build apk --debug` → APK içinde Supabase
// devre dışı → "Canlı giriş kapalı" mesajı. Scriptler bu hatayı engeller.
//
// Bu testler kod değil **script + docs** garantileridir:
//  - scripts/build_debug_supabase_apk.ps1 var
//  - SUPABASE_URL / SUPABASE_ANON_KEY presence check yapıyor
//  - --dart-define ile geçiyor
//  - Anahtarları echo etmiyor (secret-safety)
//  - docs/BUILD_RUNBOOK.md var ve plain komutları açıkça yasaklıyor
//  - .gitignore .env.* dosyalarını koruyor

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) =>
    File(relativePath).readAsStringSync();

void main() {
  group('Build config hardening — scripts/build_debug_supabase_apk.ps1', () {
    const path = 'scripts/build_debug_supabase_apk.ps1';

    test('Dosya mevcut', () {
      expect(File(path).existsSync(), isTrue,
          reason: 'Debug APK için Supabase-aware script eklenmiş olmalı '
              '(plain `flutter build apk --debug` kullanımını engeller).');
    });

    test('SUPABASE_URL ve SUPABASE_ANON_KEY presence check yapıyor', () {
      final src = _read(path);
      expect(src.contains(r"$config['SUPABASE_URL']"), isTrue);
      expect(src.contains(r"$config['SUPABASE_ANON_KEY']"), isTrue);
      // Eksikse fail-fast (exit 1):
      expect(src.contains('IsNullOrWhiteSpace'), isTrue);
      expect(src.contains('exit 1'), isTrue);
    });

    test('--dart-define ile geçiyor', () {
      final src = _read(path);
      expect(src.contains('--dart-define=SUPABASE_URL='), isTrue);
      expect(src.contains('--dart-define=SUPABASE_ANON_KEY='), isTrue);
      expect(src.contains('flutter build apk --debug'), isTrue);
    });

    test('Anahtar değerlerini echo etmiyor (secret-safety)', () {
      final src = _read(path);
      // Yalnız "present: yes" / "no" mesajı atılır; ham $url/$key echo
      // edilmez. Asagidaki regex potansiyel sizinti pattern'lerini yakalar:
      //   Write-Host $url
      //   Write-Host "URL is: $url"
      final urlEcho = RegExp(
        r'Write-(Host|Output)\s+.*\$url\b',
        caseSensitive: false,
      );
      final keyEcho = RegExp(
        r'Write-(Host|Output)\s+.*\$key\b',
        caseSensitive: false,
      );
      expect(urlEcho.hasMatch(src), isFalse,
          reason: 'Script SUPABASE_URL değerini Write-Host/Output ile basmamalı');
      expect(keyEcho.hasMatch(src), isFalse,
          reason: 'Script SUPABASE_ANON_KEY değerini Write-Host/Output ile basmamalı');
      // Aksine "present: yes" pattern'i bekleniyor:
      expect(src.contains('SUPABASE_URL present:'), isTrue);
      expect(src.contains('SUPABASE_ANON_KEY present:'), isTrue);
    });

    test('Flutter exit code\'unu koruyor', () {
      final src = _read(path);
      expect(src.contains(r'$LASTEXITCODE'), isTrue,
          reason: 'Flutter build fail ederse script de fail etmeli');
    });
  });

  group('Build config hardening — mevcut scriptler aynı pattern\'de', () {
    test('scripts/run_supabase_android.ps1 fail-fast + dart-define', () {
      final src = _read('scripts/run_supabase_android.ps1');
      expect(src.contains('--dart-define=SUPABASE_URL='), isTrue);
      expect(src.contains('--dart-define=SUPABASE_ANON_KEY='), isTrue);
      expect(src.contains('IsNullOrWhiteSpace'), isTrue);
      expect(src.contains('exit 1'), isTrue);
      // Secret echo yok:
      expect(
        RegExp(r'Write-(Host|Output)\s+.*\$url\b', caseSensitive: false)
            .hasMatch(src),
        isFalse,
      );
      expect(
        RegExp(r'Write-(Host|Output)\s+.*\$key\b', caseSensitive: false)
            .hasMatch(src),
        isFalse,
      );
    });

    test('scripts/build_release_supabase_aab.ps1 fail-fast + dart-define', () {
      final src = _read('scripts/build_release_supabase_aab.ps1');
      expect(src.contains('--dart-define=SUPABASE_URL='), isTrue);
      expect(src.contains('--dart-define=SUPABASE_ANON_KEY='), isTrue);
      expect(src.contains('IsNullOrWhiteSpace'), isTrue);
      expect(src.contains('exit 1'), isTrue);
      expect(
        RegExp(r'Write-(Host|Output)\s+.*\$url\b', caseSensitive: false)
            .hasMatch(src),
        isFalse,
      );
      expect(
        RegExp(r'Write-(Host|Output)\s+.*\$key\b', caseSensitive: false)
            .hasMatch(src),
        isFalse,
      );
    });
  });

  group('Build config hardening — docs/BUILD_RUNBOOK.md', () {
    const path = 'docs/BUILD_RUNBOOK.md';

    test('Dosya mevcut', () {
      expect(File(path).existsSync(), isTrue);
    });

    test('Plain build komutlarını yasaklıyor', () {
      final src = _read(path);
      // Hem doğru hem yanlış komutları açıkça gösteriyor olmalı:
      expect(src.contains('Yanlış'), isTrue);
      expect(src.contains('Doğru'), isTrue);
      expect(src.contains('flutter build apk'), isTrue);
      // Üç doğru script'i de listelemeli:
      expect(src.contains('build_debug_supabase_apk.ps1'), isTrue);
      expect(src.contains('run_supabase_android.ps1'), isTrue);
      expect(src.contains('build_release_supabase_aab.ps1'), isTrue);
    });

    test('Sağlık kontrolü — "Canlı giriş kapalı" tanısı içeriyor', () {
      final src = _read(path);
      // Kullanıcı bu mesajı görürse direkt runbook'a bakıp tanı koyabilmeli:
      expect(src.contains('Canlı giriş kapalı'), isTrue);
      expect(src.contains('dart-define'), isTrue);
    });
  });

  group('Build config hardening — .gitignore koruması', () {
    test('.env.local repo dışı', () {
      final src = _read('.gitignore');
      // .env / .env.* pattern'i — .env.local'i de kapsar.
      expect(
        src.contains(RegExp(r'^\.env(\.\*)?\s*$', multiLine: true)) ||
            src.contains('.env.local'),
        isTrue,
        reason: '.env.local commit edilmemeli (anahtar sızıntısı riski)',
      );
    });
  });
}
