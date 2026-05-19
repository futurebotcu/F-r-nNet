// Groups V1 Final Closure — Public profile snapshot RPC wiring.
//
// Kapsam:
//   1. Migration dosyası repo'da mevcut + güvenli kolonlar yalnız 3 alan.
//   2. SupabaseSocialGroupRepository listMembers + listPendingJoinRequests
//      artık doğrudan profiles SELECT yerine `public_profile_snapshot` RPC'sini
//      kullanıyor (source-level guard).
//   3. _fetchPublicProfileSnapshots helper mevcut.
//   4. RPC adı + parametre adı doğru (`p_user_ids`).
//   5. Hassas kolonlar (email, account_type, avatar_url) RPC'den ASLA dönmez —
//      migration SQL bunu garanti eder; source-level grep ile doğrulanır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1 Closure — Migration file', () {
    const migrationPath =
        'supabase/migrations/20260519130000_groups_v1_public_profile_snapshot_rpc.sql';

    test('Migration dosyası repo\'da var', () {
      expect(File(migrationPath).existsSync(), isTrue);
    });

    test('Fonksiyon adı + imzası doğru', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(
        sql.contains('create or replace function public.public_profile_snapshot('),
        isTrue,
      );
      expect(sql.contains('p_user_ids uuid[]'), isTrue);
    });

    test('SECURITY DEFINER + set search_path = public', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains('set search_path = public'), isTrue);
      expect(sql.contains('stable'), isTrue);
    });

    test('Yalnız üç güvenli kolon döner: display_name, profession_badge, city',
        () {
      final sql = File(migrationPath).readAsStringSync();
      // returns table imzası
      expect(sql.contains('display_name      text'), isTrue);
      expect(sql.contains('profession_badge  text'), isTrue);
      expect(sql.contains('city              text'), isTrue);
      // Fonksiyon gövdesini izole et (as $$ ... $$ arası). Sızıntı kontrolü
      // burada — yorum satırlarındaki kelimeler false-pozitif tetiklemesin.
      final bodyMatch =
          RegExp(r'as\s+\$\$([\s\S]*?)\$\$', multiLine: true).firstMatch(sql);
      expect(bodyMatch, isNotNull, reason: 'RPC body bulunamadı');
      final body = bodyMatch!.group(1)!;
      expect(body.contains('email'), isFalse,
          reason: 'RPC body\'sinde email seçilmemeli');
      expect(body.contains('account_type'), isFalse,
          reason: 'RPC body\'sinde account_type seçilmemeli');
      expect(body.contains('avatar_url'), isFalse,
          reason: 'RPC body\'sinde avatar_url seçilmemeli');
    });

    test('Grant authenticated; revoke public/anon', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(
        sql.contains(
          'revoke execute on function public.public_profile_snapshot(uuid[]) from public',
        ),
        isTrue,
      );
      expect(
        sql.contains(
          'revoke execute on function public.public_profile_snapshot(uuid[]) from anon',
        ),
        isTrue,
      );
      expect(
        sql.contains(
          'grant  execute on function public.public_profile_snapshot(uuid[]) to authenticated',
        ),
        isTrue,
      );
    });
  });

  group('V1 Closure — Client wiring (source-level)', () {
    final src = File(
      'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
    ).readAsStringSync();

    test('_fetchPublicProfileSnapshots helper mevcut', () {
      expect(
        src.contains('_fetchPublicProfileSnapshots('),
        isTrue,
        reason: 'Profil RPC fetch helper\'ı eksik',
      );
    });

    test('Helper RPC adı + parametre adı doğru', () {
      expect(src.contains("'public_profile_snapshot'"), isTrue);
      expect(src.contains("'p_user_ids'"), isTrue);
    });

    test('listMembers artık profiles SELECT kod yolu kullanmaz', () {
      // Kod yorumlarında `from('profiles')` mention edilebilir (neden RPC'ye
      // çevrildiğini açıklayan satırlar). Yorumları strip et.
      // Not: listJoined hâlâ `social_groups.inFilter('id', ...)` kullanır —
      // bu doğru ve değişmez; `from('profiles')` özelinde kontrol ederiz.
      final stripped = src
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        stripped.contains("from('profiles')"),
        isFalse,
        reason: 'profiles SELECT kod yolundan kaldırılmalı (RPC kullanılır)',
      );
    });

    test('listMembers + listPendingJoinRequests helper\'a delege ediyor', () {
      // Kaynakta iki ayrı çağrı bekleniyor.
      final matches =
          '_fetchPublicProfileSnapshots('.allMatches(src).length;
      expect(matches, greaterThanOrEqualTo(2),
          reason: 'listMembers + listPendingJoinRequests her ikisi de '
              'helper\'ı çağırmalı');
    });
  });
}
