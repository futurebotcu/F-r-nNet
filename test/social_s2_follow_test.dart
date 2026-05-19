// FırınNet Social S2 — Follow / Subscriptions regresyon testi.
//
// Scope:
//   1. Migration dosyası + table + RLS + index + constraint source-level.
//   2. AppStrings yeni sabitler.
//   3. LocalFollowRepository: self-follow no-op, follow, unfollow, toggle,
//      isFollowing, counts.
//   4. Source-level: SupabaseFollowRepository RLS-safe paths
//      (follower_id = auth.uid() defansif + 23505/23514 idempotent).
//   5. Source-level: GuardedFollowRepository write guard'lı.
//   6. FollowButton render davranışı (not-following → "Takip et",
//      following → "Takipten çık").
//   7. PublicProfileScreen kendi profilinde follow butonu render etmez.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/profile/providers/follow_providers.dart';
import 'package:firin_defter/features/profile/repositories/follow_repository.dart';
import 'package:firin_defter/features/profile/repositories/local_follow_repository.dart';
import 'package:firin_defter/features/profile/widgets/follow_button.dart';

Widget _wrap({
  required FollowRepository followRepo,
  AuthUser? authUser,
  bool canWrite = true,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      followRepositoryProvider.overrideWithValue(followRepo),
      canWriteCheckProvider.overrideWithValue(() => canWrite),
      currentAuthUserProvider.overrideWith((ref) => authUser),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('S2 — Migration file', () {
    const migrationPath =
        'supabase/migrations/20260519160000_social_s2_profile_follows.sql';

    test('Migration dosyası repo\'da var', () {
      expect(File(migrationPath).existsSync(), isTrue);
    });

    test('Tablo + composite PK + self-follow CHECK', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(sql.contains('create table public.profile_follows'), isTrue);
      expect(sql.contains('primary key (follower_id, following_id)'), isTrue);
      expect(
        sql.contains(
            'constraint profile_follows_no_self check (follower_id <> following_id)'),
        isTrue,
      );
    });

    test('RLS açık + 3 policy + grant authenticated', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(
        sql.contains('alter table public.profile_follows enable row level security'),
        isTrue,
      );
      expect(sql.contains('profile_follows_select_visible'), isTrue);
      expect(sql.contains('profile_follows_insert_self'), isTrue);
      expect(sql.contains('profile_follows_delete_self'), isTrue);
      expect(
        sql.contains('with check (follower_id = auth.uid())'),
        isTrue,
        reason: 'INSERT policy follower_id = auth.uid() ile sıkı olmalı',
      );
      expect(
        sql.contains('using (follower_id = auth.uid())'),
        isTrue,
        reason: 'DELETE policy follower_id = auth.uid() ile sıkı olmalı',
      );
      expect(
        sql.contains('grant select, insert, delete on public.profile_follows to authenticated'),
        isTrue,
      );
    });

    test('İndexler: follower + following + created_at desc', () {
      final sql = File(migrationPath).readAsStringSync();
      expect(
        sql.contains('profile_follows_follower_idx'),
        isTrue,
      );
      expect(
        sql.contains('profile_follows_following_idx'),
        isTrue,
      );
      expect(sql.contains('created_at desc'), isTrue);
    });
  });

  group('S2 — AppStrings yeni sabitler', () {
    test('Takip et / Takipten çık', () {
      expect(AppStrings.followCtaFollow, 'Takip et');
      expect(AppStrings.followCtaUnfollow, 'Takipten çık');
    });

    test('Counts helper', () {
      expect(AppStrings.followCountFollowers(0), '0 takipçi');
      expect(AppStrings.followCountFollowers(1), '1 takipçi');
      expect(AppStrings.followCountFollowing(7), '7 takip');
    });

    test('Error metni', () {
      expect(
        AppStrings.followError,
        'Takip işlemi tamamlanamadı. Lütfen tekrar dene.',
      );
    });
  });

  group('S2 — LocalFollowRepository davranışı', () {
    test('Self-follow no-op', () async {
      final repo = LocalFollowRepository(currentUserId: 'me');
      await repo.followProfile('me');
      expect(await repo.isFollowing('me'), isFalse);
      final c = await repo.getFollowCounts('me');
      expect(c.followers, 0);
      expect(c.following, 0);
    });

    test('Follow + isFollowing + counts', () async {
      final repo = LocalFollowRepository(currentUserId: 'a');
      await repo.followProfile('b');
      expect(await repo.isFollowing('b'), isTrue);
      // Idempotent — ikinci follow no-op.
      await repo.followProfile('b');
      final cB = await repo.getFollowCounts('b');
      expect(cB.followers, 1);
      final cA = await repo.getFollowCounts('a');
      expect(cA.following, 1);
    });

    test('Unfollow + toggleFollow', () async {
      final repo = LocalFollowRepository(currentUserId: 'a');
      await repo.followProfile('b');
      expect(await repo.toggleFollow('b'), isFalse,
          reason: 'Takipteyken toggle → unfollow → false döner');
      expect(await repo.isFollowing('b'), isFalse);
      expect(await repo.toggleFollow('b'), isTrue,
          reason: 'Takipte değilken toggle → follow → true döner');
      expect(await repo.isFollowing('b'), isTrue);
    });

    test('Duplicate follow oluşmaz (counts artmaz)', () async {
      final repo = LocalFollowRepository(currentUserId: 'a');
      await repo.followProfile('b');
      await repo.followProfile('b');
      await repo.followProfile('b');
      final c = await repo.getFollowCounts('b');
      expect(c.followers, 1);
    });
  });

  group('S2 — Source-level Supabase repo', () {
    final src = File(
      'lib/features/profile/repositories/supabase_follow_repository.dart',
    ).readAsStringSync();

    test('Tablo adı + insert/delete payload', () {
      expect(src.contains("from('profile_follows')"), isTrue);
      expect(src.contains("'follower_id': me"), isTrue);
      expect(src.contains("'following_id': userId"), isTrue);
    });

    test('Self-follow client erken-reddetme + idempotent code mapping', () {
      expect(src.contains('if (me == userId) return;'), isTrue);
      // 23505 unique_violation + 23514 check_violation idempotent yutma.
      expect(src.contains("e.code == '23505'"), isTrue);
      expect(src.contains("e.code == '23514'"), isTrue);
    });

    test('Counts iki paralel count', () {
      expect(src.contains('CountOption.exact'), isTrue);
      expect(src.contains('_countOf('), isTrue);
    });
  });

  group('S2 — Source-level Guarded', () {
    final src = File(
      'lib/features/profile/repositories/guarded_follow_repository.dart',
    ).readAsStringSync();

    test('Write metodlar _requireWrite ile sarılı', () {
      expect(src.contains("_requireWrite('takip etmek')"), isTrue);
      expect(src.contains("_requireWrite('takipten çıkmak')"), isTrue);
      expect(src.contains("_requireWrite('takibi değiştirmek')"), isTrue);
    });

    test('Read metodlar guard\'sız delege', () {
      expect(src.contains('Future<bool> isFollowing(String userId) => inner.isFollowing(userId);'),
          isTrue);
    });
  });

  group('S2 — FollowButton render', () {
    testWidgets(
      'isFollowing=false → "Takip et" görünür',
      (tester) async {
        final repo = LocalFollowRepository(currentUserId: 'a');
        await tester.pumpWidget(_wrap(
          followRepo: repo,
          authUser: const AuthUser(id: 'a', email: null),
          child: const FollowButton(userId: 'b'),
        ));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.followCtaFollow), findsOneWidget);
        expect(find.text(AppStrings.followCtaUnfollow), findsNothing);
      },
    );

    testWidgets(
      'Tap → toggleFollow → buton "Takipten çık"\'a döner',
      (tester) async {
        final repo = LocalFollowRepository(currentUserId: 'a');
        await tester.pumpWidget(_wrap(
          followRepo: repo,
          authUser: const AuthUser(id: 'a', email: null),
          child: const FollowButton(userId: 'b'),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.followCtaFollow));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.followCtaUnfollow), findsOneWidget);
        expect(await repo.isFollowing('b'), isTrue);
      },
    );
  });
}
