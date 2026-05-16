// Sosyal Omurga V1 — Provider selection + Guarded wrapper davranışı +
// SQL migration smoke testleri.
//
// Bu test dosyası gerçek bir Supabase client'ı çağırmaz; sadece:
//   1. AppConfig.supabaseEnabled false iken provider'ların LocalRepository
//      döndürdüğünü ve GuardedRepository ile sarıldığını doğrular.
//   2. GuardedFeedRepository ve GuardedSocialGroupRepository'nin guest
//      kullanıcının yazma metodlarına GuestActionRequiredException
//      attığını doğrular (canWriteCheck = () => false ile).
//   3. supabase/migrations/20260516041148_social_spine_v1.sql dosyasının
//      RLS açtığını, anon write yetkisi vermediğini, USING (true) ile
//      mass-public yazma policy'si içermediğini smoke test eder.

import 'dart:io';

import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/guarded_feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/guarded_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/social_group_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sosyal Omurga — Provider selection (Supabase off)', () {
    test('feedRepositoryProvider Guarded wrapper döner, inner Local', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(feedRepositoryProvider);
      expect(repo, isA<FeedRepository>());
      expect(repo, isA<GuardedFeedRepository>());
      // Wrapper inner okumaya delege; demo seed listesi okunmalı.
      // (Burada Future await edemeyiz çünkü test sync ama bunu ayrı testte.)
    });

    test('feedRepositoryProvider Local seed list okunur', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(feedRepositoryProvider);
      final posts = await repo.listPosts();
      // LocalFeedRepository(seed: true) 7 demo gönderi ile gelir
      // (6 user post + 1 group highlight).
      expect(posts.length, greaterThanOrEqualTo(6));
    });

    test('socialGroupRepositoryProvider Guarded wrapper döner', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(socialGroupRepositoryProvider);
      expect(repo, isA<SocialGroupRepository>());
      expect(repo, isA<GuardedSocialGroupRepository>());
    });

    test('socialGroupRepositoryProvider seed grupları okunur', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(socialGroupRepositoryProvider);
      final groups = await repo.listGroups();
      // LocalSocialGroupRepository seed 9 grup ile gelir.
      expect(groups.length, greaterThanOrEqualTo(8));
    });
  });

  group('GuardedFeedRepository — guest write block', () {
    late LocalFeedRepository inner;
    late GuardedFeedRepository guarded;

    setUp(() {
      inner = LocalFeedRepository(seed: false);
      guarded = GuardedFeedRepository(
        inner: inner,
        canWriteCheck: () => false, // simulated guest
      );
    });

    test('guest addPost → GuestActionRequiredException', () {
      expect(
        () => guarded.addPost(
          type: PostType.production,
          author: 'Sen',
          role: 'Misafir',
          text: 'Test',
        ),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest toggleLike → GuestActionRequiredException', () {
      expect(
        () => guarded.toggleLike('any-id'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest toggleSave → GuestActionRequiredException', () {
      expect(
        () => guarded.toggleSave('any-id'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest listPosts (read) bloklanmaz', () async {
      // Read serbest — guest demo seed gezebilir.
      final list = await guarded.listPosts();
      expect(list, isEmpty); // seed: false
    });
  });

  group('GuardedSocialGroupRepository — guest write block', () {
    late LocalSocialGroupRepository inner;
    late GuardedSocialGroupRepository guarded;

    setUp(() {
      inner = LocalSocialGroupRepository(seed: false);
      guarded = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: () => false,
      );
    });

    test('guest createGroup → GuestActionRequiredException', () {
      expect(
        () => guarded.createGroup(
          name: 'Test',
          description: 'd',
          category: GroupCategory.bakers,
        ),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest joinGroup → GuestActionRequiredException', () {
      expect(
        () => guarded.joinGroup('any-id'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest leaveGroup → GuestActionRequiredException', () {
      expect(
        () => guarded.leaveGroup('any-id'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest postMessage → GuestActionRequiredException', () {
      final msg = GroupMessage(
        id: 'm_test',
        groupId: 'g_test',
        authorName: 'Sen',
        authorRole: 'Misafir',
        text: 'hi',
        createdAt: DateTime.now(),
      );
      expect(
        () => guarded.postMessage(msg),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest listGroups (read) bloklanmaz', () async {
      final list = await guarded.listGroups();
      expect(list, isEmpty); // seed: false
    });
  });

  group('GuardedFeedRepository — auth\'lu kullanıcı write geçer', () {
    test('canWrite=true ise addPost inner\'a delege olur', () async {
      final inner = LocalFeedRepository(seed: false);
      final guarded = GuardedFeedRepository(
        inner: inner,
        canWriteCheck: () => true,
      );
      final p = await guarded.addPost(
        type: PostType.question,
        author: 'Sen',
        role: 'Üye',
        text: 'Maya hangi sıcaklıkta beslenmeli?',
      );
      expect(p.text, contains('Maya'));
      final list = await guarded.listPosts();
      expect(list.length, 1);
    });
  });

  // ────────────────────────────────────────────────────────────
  // Migration smoke testleri (SQL string analizi).
  // Canlı DB doğrulaması yapılmaz; dosyanın temel güvenlik kurallarını
  // bozmadığını doğrular.
  // ────────────────────────────────────────────────────────────
  group('Migration SQL — social_spine_v1 smoke', () {
    late String sql;

    setUpAll(() {
      final file = File(
        'supabase/migrations/20260516041148_social_spine_v1.sql',
      );
      expect(file.existsSync(), isTrue,
          reason: 'Migration dosyası bulunamadı');
      sql = file.readAsStringSync().toLowerCase();
    });

    test('tüm yeni tablolarda RLS açık', () {
      for (final t in const <String>[
        'feed_posts',
        'feed_likes',
        'feed_saves',
        'feed_comments',
        'social_groups',
        'group_members',
        'group_messages',
      ]) {
        final pattern = RegExp(
          r'alter\s+table\s+public\.' +
              RegExp.escape(t) +
              r'\s+enable\s+row\s+level\s+security',
          caseSensitive: false,
        );
        expect(
          pattern.hasMatch(sql),
          isTrue,
          reason: '$t tablosunda RLS enable satırı yok',
        );
      }
    });

    test('anon role\'üne hiç DML grant yok', () {
      // 'grant ... to anon' tehlikeli; bu dosyada olmamalı.
      // anon yalnız 'usage on schema public' düzeyinde olabilir (mevcut V1
      // grant migration'ından gelen miras), bu dosyada anon DML olmamalı.
      final lines = sql.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.contains('grant') &&
            l.contains('to anon') &&
            (l.contains('insert') ||
                l.contains('update') ||
                l.contains('delete') ||
                l.contains('select'))) {
          fail('anon\'a DML grant verilmiş satır: $l');
        }
      }
    });

    test('SECURITY DEFINER fonksiyonlar revoke ile korunuyor', () {
      // snapshot_feed_post_author, snapshot_feed_comment_author,
      // snapshot_group_message_author, snapshot_social_group_owner,
      // bump_feed_post_like_count, bump_feed_post_comment_count,
      // bump_social_group_member_count, enforce_group_max_members
      const funcs = <String>[
        'snapshot_feed_post_author',
        'snapshot_feed_comment_author',
        'snapshot_group_message_author',
        'snapshot_social_group_owner',
        'bump_feed_post_like_count',
        'bump_feed_post_comment_count',
        'bump_social_group_member_count',
        'enforce_group_max_members',
      ];
      for (final f in funcs) {
        expect(
          sql.contains('revoke execute on function public.$f()'),
          isTrue,
          reason: '$f için revoke execute yok',
        );
      }
    });

    test('SECURITY DEFINER fonksiyonlar search_path set ediyor', () {
      // Her security definer fonksiyon search_path ayarlamalı.
      expect(
        sql.contains('set search_path = public'),
        isTrue,
        reason: 'search_path set satırı yok',
      );
    });

    test('write policy\'lerinde WITH CHECK (true) yok', () {
      // RLS bypass anti-pattern; izin verilmemeli.
      expect(
        sql.contains('with check (true)'),
        isFalse,
        reason: 'with check (true) ile mass-public yazma policy\'si var',
      );
    });

    test('write policy\'leri owner_id = auth.uid() kontrolü içeriyor', () {
      // En az feed_posts insert policy bunu içermeli.
      expect(
        sql.contains('owner_id = auth.uid()'),
        isTrue,
        reason: 'owner_id = auth.uid() referansı bulunamadı',
      );
    });

    test('group_messages insert policy member kontrolü içeriyor', () {
      // group_messages_insert_member policy member exists check kullanmalı.
      final idx = sql.indexOf('group_messages_insert_member');
      expect(idx, greaterThan(-1));
      // Aynı policy gövdesinde group_members exists check'i olmalı.
      final policyBody = sql.substring(idx, idx + 400);
      expect(policyBody, contains('group_members'));
    });

    test('group_members trigger max_members aşımını kontrol ediyor', () {
      expect(sql.contains('enforce_group_max_members'), isTrue);
      expect(sql.contains('group_full'), isTrue,
          reason: 'group_full exception mesajı eksik');
    });

    test('feed_posts.like_count + comment_count + member_count sayaçları '
        'denormalize ve trigger ile bakım ediliyor', () {
      expect(sql.contains('like_count integer not null default 0'), isTrue);
      expect(sql.contains('comment_count integer not null default 0'),
          isTrue);
      expect(sql.contains('member_count integer not null default 0'),
          isTrue);
      expect(sql.contains('bump_feed_post_like_count'), isTrue);
      expect(sql.contains('bump_feed_post_comment_count'), isTrue);
      expect(sql.contains('bump_social_group_member_count'), isTrue);
    });

    test('author/owner snapshot triggerları INSERT için tanımlı', () {
      expect(sql.contains('trg_feed_posts_snapshot_author'), isTrue);
      expect(sql.contains('trg_feed_comments_snapshot_author'), isTrue);
      expect(sql.contains('trg_group_messages_snapshot_author'), isTrue);
      expect(sql.contains('trg_social_groups_snapshot_owner'), isTrue);
    });

    test('debugPrint veya print( kullanılmıyor (Dart kod sızıntısı yok)', () {
      // Migration SQL içinde Dart `print(` veya `debugPrint` olmamalı.
      // Trivial sanity check.
      expect(sql.contains('debugprint'), isFalse);
      // 'print(' SQL içinde geçmemeli (PG'de print fonksiyonu yok zaten).
      expect(sql.contains('print('), isFalse);
    });
  });
}
