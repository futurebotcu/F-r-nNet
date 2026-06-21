// FırınNet Social Core — Commit 1: Feed pagination
// (donor `posts_repository.getPage` muadili).
//
// Source-level kontratlar:
//   * FeedRepository interface'inde `listPostsPage({offset, limit, type})`.
//   * Supabase impl `.range(offset, offset+limit-1)` kullanır,
//     `is_deleted=false` filtresini korur, created_at desc.
//   * Local impl skip/take parite.
//   * Guarded delegate.
//   * Provider: feedPagedNotifierProvider AsyncNotifier; loadMore +
//     refresh + hasMore + isLoadingMore state'i.
//   * SocialFeedPage ScrollController threshold (300px) → loadMore.
//
// Repo-direct davranış:
//   * Local repo'da skip/take doğru sayfa döner.
//   * `hasMore` son sayfada false.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Social Core — listPostsPage interface + impls', () {
    test('FeedRepository interface listPostsPage imzası', () {
      final src = _strip(
        File('lib/features/feed/repositories/feed_repository.dart')
            .readAsStringSync(),
      );
      expect(src.contains('Future<List<FeedPost>> listPostsPage'), isTrue);
      expect(src.contains('int offset = 0'), isTrue);
      expect(src.contains('int limit = 20'), isTrue);
      expect(src.contains('PostType? type'), isTrue);
    });

    test('Supabase impl .range(offset, offset+limit-1) + is_deleted filtresi',
        () {
      final raw = File(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ).readAsStringSync();
      final src = _strip(raw);
      // listPostsPage bloğunu izole et
      final start = src.indexOf('Future<List<FeedPost>> listPostsPage');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      // Repost surfacing sonrası: merge için en üst (offset+limit), aksi
      // halde sayfa dilimi. Aralık is_deleted=false + created_at desc korunur.
      expect(body.contains('.range(merging ? 0 : offset, end - 1)'), isTrue);
      expect(body.contains(".eq('is_deleted', false)"), isTrue);
      expect(
        body.contains(".order('created_at', ascending: false)"),
        isTrue,
      );
    });

    test('Guarded delegate listPostsPage', () {
      final src = _strip(
        File('lib/features/feed/repositories/guarded_feed_repository.dart')
            .readAsStringSync(),
      );
      expect(src.contains('inner.listPostsPage('), isTrue);
    });
  });

  group('V2 Social Core — Local skip/take davranışı', () {
    test('Local repo offset/limit doğru sayfa döner', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      // 5 post ekle
      for (var i = 0; i < 5; i++) {
        await repo.addPost(
          type: PostType.production,
          author: 'Me',
          role: 'Usta',
          text: 'post $i',
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final page1 = await repo.listPostsPage(offset: 0, limit: 2);
      final page2 = await repo.listPostsPage(offset: 2, limit: 2);
      final page3 = await repo.listPostsPage(offset: 4, limit: 2);
      final outOfRange = await repo.listPostsPage(offset: 10, limit: 2);
      expect(page1, hasLength(2));
      expect(page2, hasLength(2));
      expect(page3, hasLength(1)); // son sayfa kısmi
      expect(outOfRange, isEmpty);
      // Newest first → page1.first = "post 4"
      expect(page1.first.text, 'post 4');
      expect(page2.first.text, 'post 2');
    });

    test('Type filtresi listPostsPage içinde uygulanır', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      await repo.addPost(
        type: PostType.question,
        author: 'Me',
        role: 'Usta',
        text: 'q1',
      );
      await repo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'p1',
      );
      final qs =
          await repo.listPostsPage(limit: 10, type: PostType.question);
      expect(qs, hasLength(1));
      expect(qs.first.text, 'q1');
    });
  });

  group('V2 Social Core — Provider akışı', () {
    final src = _strip(
      File('lib/features/feed/providers/feed_providers.dart')
          .readAsStringSync(),
    );

    test('feedPagedNotifierProvider AsyncNotifier + state', () {
      expect(src.contains('feedPagedNotifierProvider'), isTrue);
      expect(src.contains('AsyncNotifierProvider<FeedPagedNotifier'), isTrue);
      expect(src.contains('class FeedPagedState'), isTrue);
      expect(src.contains('class FeedPagedNotifier'), isTrue);
    });

    test('Notifier yöntemleri: loadMore / refresh + state.hasMore', () {
      expect(src.contains('Future<void> loadMore()'), isTrue);
      expect(src.contains('Future<void> refresh()'), isTrue);
      expect(src.contains('hasMore'), isTrue);
      expect(src.contains('isLoadingMore'), isTrue);
    });
  });

  group('V2 Social Core — SocialFeedPage scroll loadMore wiring', () {
    final src = _strip(
      File('lib/features/social/feed/social_feed_page.dart')
          .readAsStringSync(),
    );

    test('ScrollController listener + bottom threshold', () {
      expect(src.contains('_scrollController.addListener'), isTrue);
      expect(src.contains('_onScroll'), isTrue);
      expect(src.contains('maxScrollExtent - 300'), isTrue);
      expect(
        src.contains('feedPagedNotifierProvider.notifier'),
        isTrue,
      );
      expect(src.contains('.loadMore()'), isTrue);
    });

    test('Pull-to-refresh → notifier.refresh()', () {
      expect(src.contains('.refresh()'), isTrue);
      expect(src.contains('RefreshIndicator.adaptive'), isTrue);
    });
  });
}
