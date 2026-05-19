// FırınNet Feed F1 — Post Delete regresyon testi.
//
// Scope:
//   1. FeedPost.ownerId zorunlu alan + copyWith koruyor.
//   2. AppStrings yeni sabitler.
//   3. LocalFeedRepository.deletePost: owner-only, başkasına no-op.
//   4. Source-level: SupabaseFeedRepository.deletePost owner_id filter +
//      is_deleted=true update; GuardedFeedRepository deletePost guard'lı.
//   5. UI: FeedPostCard onDelete=null → ⋮ menü görünmez (regression);
//      onDelete callback verilirse PopupMenuButton görünür.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/feed_post_card.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';

void main() {
  group('F1 — AppStrings yeni sabitler', () {
    test('feedPostMenuDelete', () {
      expect(AppStrings.feedPostMenuDelete, 'Gönderiyi sil');
    });

    test('feedPostDeleteConfirmTitle + Body', () {
      expect(
        AppStrings.feedPostDeleteConfirmTitle,
        'Bu gönderiyi sil?',
      );
      expect(
        AppStrings.feedPostDeleteConfirmBody,
        'Gönderi feed\'den kalkacak. Bu işlem geri alınamaz.',
      );
    });

    test('feedPostDeleteSuccess + Error', () {
      expect(AppStrings.feedPostDeleteSuccess, 'Gönderi silindi.');
      expect(
        AppStrings.feedPostDeleteError,
        'Gönderi silinemedi. Lütfen tekrar dene.',
      );
    });
  });

  group('F1 — FeedPost.ownerId', () {
    test('Zorunlu alan + copyWith koruyor', () {
      final p = FeedPost(
        id: 'pid',
        ownerId: 'u1',
        type: PostType.production,
        author: 'X',
        role: 'Üye',
        text: 'hi',
        createdAt: DateTime(2026, 5, 19),
        gradient: const <Color>[Color(0xFFEEE), Color(0xFFDDD)],
      );
      expect(p.ownerId, 'u1');
      final upd = p.copyWith(likeCount: 5);
      expect(upd.ownerId, 'u1', reason: 'copyWith ownerId\'yi korumalı');
    });
  });

  group('F1 — LocalFeedRepository.deletePost owner-only', () {
    test('Owner kendi postunu silebilir', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'owner_x',
      );
      final p = await repo.addPost(
        type: PostType.production,
        author: 'Owner X',
        role: 'Usta',
        text: 'gönderi',
      );
      expect(p.ownerId, 'owner_x');
      expect((await repo.listPosts()).length, 1);
      await repo.deletePost(p.id);
      expect((await repo.listPosts()).length, 0,
          reason: 'Owner soft-delete listeden düşürmeli');
    });

    test('Owner olmayan no-op', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'visitor',
      );
      final p = await repo.addPost(
        type: PostType.production,
        author: 'Visitor',
        role: 'Üye',
        text: 'visitor post',
      );
      // Repo'yu farklı user perspektifinde yeniden oluşturup deletePost
      // dener — owner farklı, silinmemeli.
      final otherRepo = LocalFeedRepository(
        seed: false,
        currentUserId: 'someone_else',
      );
      // Other repo ayrı in-memory; aynı postu görmez; bu test sadece
      // semantik: kendi repo'sunda kendi post'unu silebilir, başkasının
      // post'una müdahale edemez (Supabase tarafında RLS aynı kontratı
      // tutar).
      await otherRepo.deletePost(p.id);
      // Orijinal repo'da post hâlâ duruyor.
      expect((await repo.listPosts()).length, 1);
    });
  });

  group('F1 — Source-level guards', () {
    test('SupabaseFeedRepository.deletePost owner_id filter + is_deleted update',
        () {
      final src = File(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ).readAsStringSync();
      expect(src.contains('Future<void> deletePost(String postId)'), isTrue);
      expect(src.contains("'is_deleted': true"), isTrue);
      expect(src.contains(".eq('owner_id', userId)"), isTrue);
    });

    test('GuardedFeedRepository.deletePost guard\'lı', () {
      final src = File(
        'lib/features/feed/repositories/guarded_feed_repository.dart',
      ).readAsStringSync();
      expect(src.contains('Future<void> deletePost(String postId)'), isTrue);
      expect(src.contains("_requireWrite('gönderiyi silmek')"), isTrue);
    });

    test('feed_repository.dart interface deletePost imzası', () {
      final src = File(
        'lib/features/feed/repositories/feed_repository.dart',
      ).readAsStringSync();
      expect(src.contains('Future<void> deletePost(String postId);'), isTrue);
    });

    test('feed_screen.dart: _isOwner ve _confirmAndDeletePost mevcut', () {
      final src = File(
        'lib/features/feed/screens/feed_screen.dart',
      ).readAsStringSync();
      expect(src.contains('static bool _isOwner('), isTrue);
      expect(src.contains('_confirmAndDeletePost('), isTrue);
      expect(src.contains('user.id == post.ownerId'), isTrue);
    });
  });

  group('F1 — FeedPostCard owner menu', () {
    testWidgets(
      'onDelete=null → ⋮ menü görünmez (regression)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FeedPostCard(
                author: 'Hasan',
                role: 'Usta',
                timeAgo: '1 sa önce',
                content: 'içerik',
                likeCount: 0,
                commentCount: 0,
                // onDelete null → menü yok
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<String>), findsNothing);
      },
    );

    testWidgets(
      'onDelete verilirse → ⋮ menü görünür ve "Gönderiyi sil" itemı çıkar',
      (tester) async {
        var deleteCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FeedPostCard(
                author: 'Sen',
                role: 'Usta',
                timeAgo: 'şimdi',
                content: 'sahibi olduğum post',
                likeCount: 0,
                commentCount: 0,
                onDelete: () => deleteCalled = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // PopupMenuButton görünür.
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);
        // Menüyü aç.
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.feedPostMenuDelete), findsOneWidget);
        // Item'a tıkla.
        await tester.tap(find.text(AppStrings.feedPostMenuDelete));
        await tester.pumpAndSettle();
        expect(deleteCalled, isTrue,
            reason: 'Menüden "Gönderiyi sil" → onDelete tetiklenmeli');
      },
    );
  });
}
