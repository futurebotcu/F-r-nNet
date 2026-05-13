import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalFeedRepository', () {
    test('seed default 7 post barındırır (6 normal + 1 group highlight)',
        () async {
      final repo = LocalFeedRepository(seed: true);
      final posts = await repo.listPosts();
      expect(posts.length, 7);
      expect(posts.any((p) => p.type == PostType.groupHighlight), isTrue);
    });

    test('addPost — yeni post listenin en üstüne eklenir', () async {
      final repo = LocalFeedRepository(seed: true);
      final before = await repo.listPosts();
      final beforeFirst = before.first.id;

      final newPost = await repo.addPost(
        type: PostType.question,
        author: 'Sen',
        role: 'Misafir · FırınNet',
        text: 'Yaz mayası ne kadar düşürülmeli?',
        tags: const ['maya', 'yazreçetesi'],
      );

      final after = await repo.listPosts();
      expect(after.length, before.length + 1);
      expect(after.first.id, newPost.id);
      expect(after.first.text.startsWith('Yaz mayası'), isTrue);
      expect(after.first.id, isNot(beforeFirst));
    });

    test('addPost — text trim edilir, tags korunur', () async {
      final repo = LocalFeedRepository(seed: false);
      final p = await repo.addPost(
        type: PostType.production,
        author: 'A',
        role: 'B',
        text: '   Düz metin   \n',
        tags: const ['test', 'ekşimaya'],
      );
      expect(p.text, 'Düz metin');
      expect(p.tags, ['test', 'ekşimaya']);
      expect(p.likeCount, 0);
      expect(p.commentCount, 0);
      expect(p.isLiked, isFalse);
      expect(p.isSaved, isFalse);
    });

    test('toggleLike — false→true count artırır, geri alınca azaltır',
        () async {
      final repo = LocalFeedRepository(seed: true);
      final posts = await repo.listPosts();
      final p = posts.firstWhere((x) => x.id == 'fp_seed_1');
      expect(p.isLiked, isFalse);
      expect(p.likeCount, 142);

      final liked = await repo.toggleLike('fp_seed_1');
      expect(liked.isLiked, isTrue);
      expect(liked.likeCount, 143);

      final unliked = await repo.toggleLike('fp_seed_1');
      expect(unliked.isLiked, isFalse);
      expect(unliked.likeCount, 142);
    });

    test('toggleSave — sadece flag değişir, count değişmez', () async {
      final repo = LocalFeedRepository(seed: true);
      final posts = await repo.listPosts();
      final p = posts.firstWhere((x) => x.id == 'fp_seed_1');
      expect(p.isSaved, isFalse);

      final saved = await repo.toggleSave('fp_seed_1');
      expect(saved.isSaved, isTrue);
      expect(saved.likeCount, p.likeCount);

      final unsaved = await repo.toggleSave('fp_seed_1');
      expect(unsaved.isSaved, isFalse);
    });

    test('toggleLike olmayan post id\'sine fırlatır', () async {
      final repo = LocalFeedRepository(seed: false);
      expect(
        () => repo.toggleLike('yok'),
        throwsA(isA<StateError>()),
      );
    });

    test('listPosts type filter doğru süzer', () async {
      final repo = LocalFeedRepository(seed: true);
      final supplyOnly = await repo.listPosts(type: PostType.supply);
      expect(supplyOnly, isNotEmpty);
      expect(supplyOnly.every((p) => p.type == PostType.supply), isTrue);

      final highlights =
          await repo.listPosts(type: PostType.groupHighlight);
      expect(highlights.length, 1);
      expect(highlights.first.groupId, 'g_un_tip550');
      expect(highlights.first.groupName, 'Un & Hammadde Pazarı');
    });

    test('group highlight postlarda groupId/groupName dolu', () async {
      final repo = LocalFeedRepository(seed: true);
      final all = await repo.listPosts();
      final highlights =
          all.where((p) => p.type == PostType.groupHighlight).toList();
      expect(highlights, isNotEmpty);
      for (final h in highlights) {
        expect(h.groupId, isNotNull);
        expect(h.groupName, isNotNull);
        expect(h.isGroupHighlight, isTrue);
      }
    });

    test('listInsights 3 sosyal büyüme rozet kartı döner', () async {
      final repo = LocalFeedRepository(seed: true);
      final insights = await repo.listInsights();
      expect(insights.length, 3);
      // Her kart tipinin tek bir kartı olmalı.
      final kinds = insights.map((i) => i.kind).toSet();
      expect(kinds.length, 3);
    });
  });

  group('PostType meta', () {
    test('persistKey round-trip', () {
      for (final t in PostType.values) {
        expect(PostTypeMeta.fromPersistKey(t.persistKey), t);
      }
    });

    test('label / icon / accent her tip için doludur', () {
      for (final t in PostType.values) {
        expect(t.label, isNotEmpty);
        expect(t.icon, isNotNull);
        expect(t.accent, isNotNull);
      }
    });
  });
}
