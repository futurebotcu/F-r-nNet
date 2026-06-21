// Feed PR #2 — Yoruma beğeni + tek-seviye cevap (repo davranış testleri).
//
// LocalSocialCommentsRepository, Supabase + migration paritesini modeller:
//   * toggleCommentLike → isLiked/likeCount
//   * addComment(parentCommentId) → tek-seviye cevap
//   * tek-seviye guard: cevaba cevap reddedilir
//   * cascade: üst yorum silinince cevapları da gizlenir

import 'package:firin_defter/features/social/repositories/local_social_comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Yoruma beğeni', () {
    test('toggle: beğen → isLiked=true, likeCount=1; tekrar → false, 0',
        () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      final c = await repo.addComment(postId: 'p1', text: 'merhaba');

      final liked = await repo.toggleCommentLike(c.id);
      expect(liked, isTrue);
      var list = await repo.listComments('p1');
      expect(list.single.isLiked, isTrue);
      expect(list.single.likeCount, 1);

      final unliked = await repo.toggleCommentLike(c.id);
      expect(unliked, isFalse);
      list = await repo.listComments('p1');
      expect(list.single.isLiked, isFalse);
      expect(list.single.likeCount, 0);
    });
  });

  group('Tek-seviye cevap', () {
    test('üst yoruma cevap → parentCommentId dolu, listede görünür', () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      final top = await repo.addComment(postId: 'p1', text: 'üst yorum');
      final reply = await repo.addComment(
        postId: 'p1',
        text: 'cevap',
        parentCommentId: top.id,
      );
      expect(reply.parentCommentId, top.id);
      expect(reply.isReply, isTrue);

      final list = await repo.listComments('p1');
      expect(list.length, 2);
      expect(list.where((c) => c.parentCommentId == top.id).length, 1);
    });

    test('cevaba cevap reddedilir (tek seviye guard)', () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      final top = await repo.addComment(postId: 'p1', text: 'üst');
      final reply =
          await repo.addComment(postId: 'p1', text: 'cevap', parentCommentId: top.id);

      expect(
        () => repo.addComment(
          postId: 'p1',
          text: 'cevaba cevap',
          parentCommentId: reply.id,
        ),
        throwsStateError,
      );
    });

    test('olmayan parent reddedilir', () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      expect(
        () => repo.addComment(
          postId: 'p1',
          text: 'cevap',
          parentCommentId: 'yok',
        ),
        throwsStateError,
      );
    });
  });

  group('Cascade soft-delete', () {
    test('üst yorum silinince cevapları da gizlenir', () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      final top = await repo.addComment(postId: 'p1', text: 'üst');
      await repo.addComment(postId: 'p1', text: 'cevap1', parentCommentId: top.id);
      await repo.addComment(postId: 'p1', text: 'cevap2', parentCommentId: top.id);
      expect((await repo.listComments('p1')).length, 3);

      await repo.deleteComment(top.id);

      // Üst yorum + iki cevap görünmez.
      expect((await repo.listComments('p1')), isEmpty);
    });

    test('cevap silinince üst yorum etkilenmez', () async {
      final repo = LocalSocialCommentsRepository(currentUserId: 'me');
      final top = await repo.addComment(postId: 'p1', text: 'üst');
      final reply =
          await repo.addComment(postId: 'p1', text: 'cevap', parentCommentId: top.id);

      await repo.deleteComment(reply.id);

      final list = await repo.listComments('p1');
      expect(list.single.id, top.id);
    });
  });
}
