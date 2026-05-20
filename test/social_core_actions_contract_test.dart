// FırınNet Social Core — Commit 1: Action contract hardening kanıtı.
//
// Donor `posts_repository` ve `database_client` write işlemleri sonrası
// dönen satırı kontrol eder; biz de tüm Supabase impl'lerinde 0-row
// silent-success durumunu kapatıyoruz:
//   * addPost: `.select(_postColumns).single()` (mevcut).
//   * deletePost: `.select('id')` + empty → StateError (P0).
//   * updatePost: `.select(_postColumns)` + empty → StateError (V2).
//   * toggleLike/toggleSave: SELECT → INSERT/DELETE atomic, 23505
//     yutması idempotent (mevcut).
//   * deleteComment: `.select('id')` + empty → StateError (P0).
//   * addComment: `.select(_columns).single()` (mevcut).
//
// Bu test source-level olarak her kontratın yerinde durduğunu doğrular.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('Post action contract — supabase_feed_repository', () {
    final src = _strip(
      File('lib/features/feed/repositories/supabase_feed_repository.dart')
          .readAsStringSync(),
    );

    test('addPost RETURNING single()', () {
      // addPost insert + select + single — silent success engellendi.
      expect(src.contains('Future<FeedPost> addPost('), isTrue);
      expect(src.contains('.select(_postColumns)'), isTrue);
      expect(src.contains('.single();'), isTrue);
    });

    test('deletePost .select(id) + StateError on empty', () {
      final start = src.indexOf('Future<void> deletePost(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".select('id')"), isTrue);
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(body.contains('StateError'), isTrue);
    });

    test('updatePost .select + StateError on empty', () {
      final start = src.indexOf('Future<FeedPost> updatePost(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains('.select(_postColumns)'), isTrue);
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(body.contains('StateError'), isTrue);
      // Owner guard: .eq('owner_id', userId)
      expect(body.contains(".eq('owner_id', userId)"), isTrue);
    });

    test('toggleLike SELECT→INSERT/DELETE atomic + 23505 idempotent', () {
      final start = src.indexOf('Future<FeedPost> toggleLike(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".from('feed_likes')"), isTrue);
      expect(body.contains('.maybeSingle()'), isTrue);
      expect(body.contains('23505'), isTrue,
          reason: 'unique_violation race idempotent yutulur');
    });

    test('toggleSave SELECT→INSERT/DELETE atomic', () {
      final start = src.indexOf('Future<FeedPost> toggleSave(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".from('feed_saves')"), isTrue);
      expect(body.contains('.maybeSingle()'), isTrue);
    });
  });

  group('Comment action contract — supabase_social_comments_repository', () {
    final src = _strip(
      File('lib/features/social/repositories/'
              'supabase_social_comments_repository.dart')
          .readAsStringSync(),
    );

    test('addComment RETURNING single()', () {
      expect(src.contains('Future<SocialComment> addComment('), isTrue);
      expect(src.contains('.select(_columns)'), isTrue);
      expect(src.contains('.single();'), isTrue);
    });

    test('deleteComment .select(id) + StateError on empty', () {
      final start = src.indexOf('Future<void> deleteComment(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Stream<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".select('id')"), isTrue);
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(body.contains('StateError'), isTrue);
    });
  });

  group('Guarded delegators — guest exception path', () {
    final src = _strip(
      File('lib/features/feed/repositories/guarded_feed_repository.dart')
          .readAsStringSync(),
    );

    test('updatePost guarded ve delegate', () {
      expect(src.contains('Future<FeedPost> updatePost('), isTrue);
      expect(src.contains("_requireWrite('gönderiyi düzenlemek')"), isTrue);
      expect(src.contains('inner.updatePost('), isTrue);
    });

    test('listPostsPage delegate (read, write guard yok)', () {
      expect(src.contains('inner.listPostsPage('), isTrue);
    });
  });
}
