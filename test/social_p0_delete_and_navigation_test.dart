// FirinNet - P0 wiring fix: comment delete + post delete + navigation proof test.
//
// This suite keeps the current social flow contracts stable.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('P0 - Comment delete wiring', () {
    final raw = File('lib/features/social/comments/comments_page.dart')
        .readAsStringSync();
    final src = _strip(raw);

    test('_confirmAndDelete success path: invalidate + snackbar', () {
      expect(
        src.contains('ref.invalidate(socialCommentsProvider(postId))'),
        isTrue,
      );
      expect(
        src.contains('ref.invalidate(feedPostByIdProvider(postId))'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.feedCommentDeletedSnack'),
        isTrue,
        reason: 'Successful delete snackbar is shown',
      );
    });

    test('_confirmAndDelete error path: snackbar + guest guard', () {
      expect(src.contains('on GuestActionRequiredException'), isTrue);
      expect(src.contains('showAuthRequiredSheet'), isTrue);
      expect(
        src.contains('AppStrings.feedCommentDeleteFailed'),
        isTrue,
        reason: 'Generic error snackbar is shown',
      );
    });

    test('debugPrint tap/success/error trace', () {
      expect(src.contains('[FirinNet][Comments] delete tap'), isTrue);
      expect(src.contains('[FirinNet][Comments] delete success'), isTrue);
      expect(src.contains('[FirinNet][Comments] delete error'), isTrue);
    });
  });

  group('P0 - Post delete wiring', () {
    final raw = File('lib/features/social/post/social_post_card.dart')
        .readAsStringSync();
    final src = _strip(raw);

    test('_onDeleteTap success path: 3 invalidate', () {
      expect(src.contains('ref.invalidate(feedPostsProvider)'), isTrue);
      expect(
        src.contains('ref.invalidate(feedPostByIdProvider(post.id))'),
        isTrue,
      );
      expect(
        src.contains('ref.invalidate(userPostsProvider(post.ownerId))'),
        isTrue,
      );
    });

    test('_onDeleteTap 15s timeout + Turkish error message', () {
      expect(src.contains('.timeout(const Duration(seconds: 15))'), isTrue);
      expect(src.contains('AppStrings.feedPostDeleteError'), isTrue);
      expect(src.contains('AppStrings.feedPostDeleteSuccess'), isTrue);
    });

    test('debugPrint tap/success/error trace', () {
      expect(src.contains('[FirinNet][PostCard] delete tap'), isTrue);
      expect(src.contains('[FirinNet][PostCard] delete success'), isTrue);
      expect(src.contains('[FirinNet][PostCard] delete error'), isTrue);
    });
  });

  group('P0 - SocialPostCard navigation guards', () {
    final raw = File('lib/features/social/post/social_post_card.dart')
        .readAsStringSync();
    final src = _strip(raw);

    test('Root Container onTap none (full-card tap does not open comments)', () {
      expect(
        src.contains('GestureDetector('),
        isFalse,
        reason: 'Card root does not use GestureDetector',
      );
      final containerOccurrences = 'Container('.allMatches(src).length;
      expect(containerOccurrences, greaterThan(0));
    });

    test('SocialCommentsPage.show called from exactly 2 places', () {
      final calls = RegExp(r'SocialCommentsPage\.show\(').allMatches(src);
      expect(calls.length, 2, reason: 'Only comment button + view-all tap');
    });

    test('CommentsPreview chevron + brandLemonPressed link appearance', () {
      expect(src.contains('Icons.chevron_right_rounded'), isTrue);
      expect(src.contains('AppColors.brandLemonPressed'), isTrue);
      expect(src.contains('postViewAllComments'), isTrue);
    });
  });

  group('P0 - Comments page order: PostContext -> Heading -> List -> Composer',
      () {
    final raw = File('lib/features/social/comments/comments_page.dart')
        .readAsStringSync();
    final src = _strip(raw);

    test('ListView first item _PostContextHeader', () {
      expect(src.contains('if (i == 0) return _PostContextHeader('), isTrue);
    });

    test('ListView second item _SectionHeading "Yorumlar (N)"', () {
      expect(src.contains('if (i == 1) return _SectionHeading('), isTrue);
      expect(src.contains('AppStrings.postCommentsHeading'), isTrue);
    });

    test('Composer body Column last child (sticky bottom)', () {
      final expandedIdx = src.indexOf('Expanded(');
      final composerIdx = src.indexOf('_CommentComposer(');
      expect(expandedIdx, greaterThan(0));
      expect(composerIdx, greaterThan(expandedIdx));
    });
  });

  group('P0 - AppStrings new delete fail text', () {
    test('feedCommentDeleteFailed Turkish + retry hint', () {
      expect(AppStrings.feedCommentDeleteFailed.isNotEmpty, isTrue);
      expect(
        AppStrings.feedCommentDeleteFailed.toLowerCase().contains('silinemedi'),
        isTrue,
      );
    });
  });

  group('P0 - Supabase delete hardening: .select(id) + empty -> throw', () {
    test('supabase_social_comments_repository deleteComment .select(id)', () {
      final raw = File(
        'lib/features/social/repositories/supabase_social_comments_repository.dart',
      ).readAsStringSync();
      final src = _strip(raw);
      expect(src.contains(".select('id')"), isTrue);
      expect(src.contains('(rows as List).isEmpty'), isTrue);
      expect(
        src.contains("'Yorum silinemedi: yetki yok veya kayıt bulunamadı.'"),
        isTrue,
      );
    });

    test('supabase_feed_repository deletePost .select(id)', () {
      final raw = File(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      ).readAsStringSync();
      final src = _strip(raw);
      final start = src.indexOf('Future<void> deletePost(String postId)');
      final endMarker = src.indexOf('Future<', start + 30);
      expect(start, greaterThan(0));
      expect(endMarker, greaterThan(start));
      final body = src.substring(start, endMarker);
      expect(body.contains(".select('id')"), isTrue, reason: 'deletePost hardened');
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(
        body.contains("'Gönderi silinemedi: yetki yok veya kayıt bulunamadı.'"),
        isTrue,
      );
    });
  });
}
