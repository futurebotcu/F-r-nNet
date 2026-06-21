// Feed sprint — repost toggle + recipe/announcement post tipleri.
//
// LocalFeedRepository, Supabase + migration paritesini modeller:
//   * toggleRepost → isReposted/repostCount (toggle: ikinci tap geri alır)
//   * PostType.recipe/announcement label + persistKey (Tarif/Duyuru)

import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repost toggle', () {
    test('repost → isReposted=true, repostCount+1; tekrar → false, -1',
        () async {
      final repo = LocalFeedRepository(seed: true);
      final posts = await repo.listPosts();
      final id = posts.first.id;
      final before = posts.first.repostCount;

      final r1 = await repo.toggleRepost(id);
      expect(r1.isReposted, isTrue);
      expect(r1.repostCount, before + 1);

      final r2 = await repo.toggleRepost(id);
      expect(r2.isReposted, isFalse);
      expect(r2.repostCount, before);
    });

    test('addPost sonrası repostCount 0, isReposted false', () async {
      final repo = LocalFeedRepository(seed: false);
      final p = await repo.addPost(
        type: PostType.production,
        author: 'Ben',
        role: 'Usta',
        text: 'merhaba',
      );
      expect(p.repostCount, 0);
      expect(p.isReposted, isFalse);
    });
  });

  group('PostType recipe/announcement', () {
    test('label: Tarif / Duyuru', () {
      expect(PostType.recipe.label, 'Tarif');
      expect(PostType.announcement.label, 'Duyuru');
    });

    test('persistKey: recipe / announcement', () {
      expect(PostType.recipe.persistKey, 'recipe');
      expect(PostType.announcement.persistKey, 'announcement');
    });

    test('fromPersistKey round-trip', () {
      expect(PostTypeMeta.fromPersistKey('recipe'), PostType.recipe);
      expect(PostTypeMeta.fromPersistKey('announcement'),
          PostType.announcement);
    });

    test('addPost recipe/announcement tipini korur', () async {
      final repo = LocalFeedRepository(seed: false);
      final r = await repo.addPost(
        type: PostType.recipe,
        author: 'Ben',
        role: 'Usta',
        text: 'tarif',
      );
      expect(r.type, PostType.recipe);
      final a = await repo.addPost(
        type: PostType.announcement,
        author: 'Ben',
        role: 'Usta',
        text: 'duyuru',
      );
      expect(a.type, PostType.announcement);
    });
  });
}
