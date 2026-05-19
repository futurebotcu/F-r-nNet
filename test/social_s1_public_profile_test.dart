// FırınNet Social S1 — Public Profile regresyon testi.
//
// Scope:
//   1. AppStrings yeni sabitler.
//   2. PublicProfile model davranışı (displayNameOrFallback).
//   3. LocalFeedRepository.listPostsByOwner: owner filtreli liste, newest first.
//   4. SupabaseFeedRepository.listPostsByOwner source-level: is_deleted=false
//      + owner_id eq + order created_at desc.
//   5. GuardedFeedRepository.listPostsByOwner read-only delegate.
//   6. AppRouter `userPublicProfile` constant + route registered.
//   7. FeedPostCard `onAuthorTap` callback davranışı.
//   8. Source-level: feed_screen.dart PostCardWired onAuthorTap'i
//      AppRoutes.userPublicProfile altına push ediyor.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/feed_post_card.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';

void main() {
  group('S1 — AppStrings yeni sabitler', () {
    test('publicProfileTitle / fallback', () {
      expect(AppStrings.publicProfileTitle, 'Profil');
      expect(AppStrings.publicProfileFallbackTitle, 'FırınNet Kullanıcısı');
    });

    test('publicProfilePostsHeading tekil/çoğul aynı string yapısı', () {
      expect(AppStrings.publicProfilePostsHeading(1), '1 gönderi');
      expect(AppStrings.publicProfilePostsHeading(5), '5 gönderi');
    });

    test('publicProfileSelfHint + empty + loadError', () {
      expect(AppStrings.publicProfileSelfHint, 'Bu senin profilin');
      expect(
        AppStrings.publicProfilePostsEmpty,
        'Bu kullanıcı henüz gönderi paylaşmadı.',
      );
      expect(
        AppStrings.publicProfileLoadError,
        'Profil yüklenemedi. Yeniden dener misin?',
      );
    });
  });

  group('S1 — PublicProfile model', () {
    test('displayNameOrFallback boş/null değerleri yakalar', () {
      const a = PublicProfile(id: 'u1', displayName: 'Hasan Usta');
      expect(a.displayNameOrFallback, 'Hasan Usta');
      const b = PublicProfile(id: 'u2', displayName: null);
      expect(b.displayNameOrFallback, PublicProfile.fallbackName);
      const c = PublicProfile(id: 'u3', displayName: '   ');
      expect(c.displayNameOrFallback, PublicProfile.fallbackName);
    });

    test('fallbackName sabiti', () {
      expect(PublicProfile.fallbackName, 'FırınNet Kullanıcısı');
    });
  });

  group('S1 — LocalFeedRepository.listPostsByOwner', () {
    test('Owner filtreli + newest first', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      await repo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'eski post',
      );
      // Küçük gecikme — saniye precision yetmezse aynı timestamp olabilir;
      // _meId aynı kalır → ikisi de aynı owner.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.addPost(
        type: PostType.question,
        author: 'Me',
        role: 'Usta',
        text: 'yeni post',
      );
      final mine = await repo.listPostsByOwner('me');
      expect(mine, hasLength(2));
      // Newest first → ilk eleman 'yeni post' olmalı.
      expect(mine.first.text, 'yeni post');
      // Başka user için boş.
      final other = await repo.listPostsByOwner('someone_else');
      expect(other, isEmpty);
    });
  });

  group('S1 — Source-level guards', () {
    test('FeedRepository interface listPostsByOwner imzası', () {
      final src = File(
        'lib/features/feed/repositories/feed_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('Future<List<FeedPost>> listPostsByOwner(String ownerId);'),
        isTrue,
      );
    });

    test('Supabase impl is_deleted+owner_id+order doğru', () {
      final src = File(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains(
            'Future<List<FeedPost>> listPostsByOwner(String ownerId)'),
        isTrue,
      );
      // Source bloğunu izole et — listPostsByOwner'dan addPost'a kadar.
      final start = src.indexOf('listPostsByOwner(String ownerId)');
      final endMarker = src.indexOf('Future<FeedPost> addPost', start);
      expect(endMarker, greaterThan(start));
      final body = src.substring(start, endMarker);
      expect(body.contains(".eq('is_deleted', false)"), isTrue);
      expect(body.contains(".eq('owner_id', ownerId)"), isTrue);
      expect(body.contains(".order('created_at', ascending: false)"), isTrue);
    });

    test('GuardedFeedRepository listPostsByOwner read-only delegate', () {
      final src = File(
        'lib/features/feed/repositories/guarded_feed_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('inner.listPostsByOwner(ownerId)'),
        isTrue,
      );
    });

    test('app_router userPublicProfile constant + route registered', () {
      final src = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(
        src.contains(
            "static const String userPublicProfile = '/u';"),
        isTrue,
      );
      expect(
        src.contains("'\${AppRoutes.userPublicProfile}/:userId'"),
        isTrue,
        reason: 'GoRoute path PublicProfileScreen ile bağlanmalı',
      );
      expect(src.contains('PublicProfileScreen('), isTrue);
    });

    test('PostCardWired onAuthorTap public profile route\'a push eder', () {
      final src = File(
        'lib/features/feed/screens/feed_screen.dart',
      ).readAsStringSync();
      // Yorum strip'i; kod içinde push'a bak.
      final stripped = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(stripped.contains('AppRoutes.userPublicProfile'), isTrue);
      expect(stripped.contains('onAuthorTap:'), isTrue);
    });

    test('publicProfileProvider RPC adı + parametre adı doğru', () {
      final src = File(
        'lib/features/profile/providers/profile_provider.dart',
      ).readAsStringSync();
      expect(src.contains("'public_profile_snapshot'"), isTrue);
      expect(src.contains("'p_user_ids'"), isTrue);
      expect(src.contains('class PublicProfile'), isTrue);
      expect(src.contains('publicProfileProvider'), isTrue);
    });
  });

  group('S1 — FeedPostCard onAuthorTap davranışı', () {
    testWidgets('onAuthorTap verilirse avatar tap tetiklenir',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPostCard(
              author: 'Hasan',
              role: 'Usta',
              timeAgo: 'şimdi',
              content: 'içerik',
              likeCount: 0,
              commentCount: 0,
              onAuthorTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Avatar metni "H" → ona tıkla; GestureDetector tetiklenir.
      await tester.tap(find.text('H'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('onAuthorTap=null verilirse tap inert', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPostCard(
              author: 'Hasan',
              role: 'Usta',
              timeAgo: 'şimdi',
              content: 'içerik',
              likeCount: 0,
              commentCount: 0,
              // onAuthorTap null
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap atmaya çalış — exception olmamalı, kayıt yok.
      await tester.tap(find.text('H'));
      await tester.pumpAndSettle();
      // Bir şey patlamadıysa testin başarısı yeterli.
    });
  });
}
