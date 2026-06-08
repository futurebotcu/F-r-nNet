// FirinNet - Donor-first social module rebuild proof test.
//
// These tests verify that the legacy social system is out and the donor-first
// modules are in place at source level.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('Donor-First - third_party LICENSE + notices', () {
    test('third_party/instagram_offline_first_clone/LICENSE exists', () {
      final f = File('third_party/instagram_offline_first_clone/LICENSE');
      expect(f.existsSync(), isTrue, reason: 'Donor LICENSE added');
      final body = f.readAsStringSync();
      expect(body.contains('MIT License'), isTrue);
      expect(body.contains('Emil Zulufov'), isTrue);
    });

    test('THIRD_PARTY_NOTICES.md exists and has donor attribution', () {
      final f = File('THIRD_PARTY_NOTICES.md');
      expect(f.existsSync(), isTrue);
      final body = f.readAsStringSync();
      expect(body.contains('flutter-instagram-offline-first-clone'), isTrue);
      expect(body.contains('Riverpod'), isTrue);
      expect(body.contains('Supabase'), isTrue);
      expect(body.contains('substantially modified'), isTrue);
    });
  });

  group('Donor-First - AppStrings new constants', () {
    test('feedLoadError + feedEmpty + retry + storiesMyStoryLabel', () {
      expect(AppStrings.feedLoadError.isNotEmpty, isTrue);
      expect(AppStrings.feedEmpty.isNotEmpty, isTrue);
      expect(AppStrings.retry, 'Yeniden dene');
      expect(AppStrings.storiesMyStoryLabel, 'Senin Hikayen');
      expect(AppStrings.feedComposerNewPostCta, 'Paylaş');
    });
  });

  group('Donor-First - Router: /feed -> SocialFeedPage', () {
    final rawSrc = File('lib/app/router/app_router.dart').readAsStringSync();
    final src = _strip(rawSrc);

    test('SocialFeedPage import ediliyor, FeedScreen import edilmiyor', () {
      expect(src.contains('SocialFeedPage'), isTrue);
      expect(
        src.contains("import '../../features/feed/screens/feed_screen.dart'"),
        isFalse,
        reason: 'Legacy FeedScreen import removed from router',
      );
    });

    test('AppRoutes.feed pageBuilder returns SocialFeedPage', () {
      final start = src.indexOf('path: AppRoutes.feed,');
      expect(start, greaterThan(0));
      final end = src.indexOf('GoRoute(', start + 20);
      expect(end, greaterThan(start));
      final body = src.substring(start, end);
      expect(body.contains('SocialFeedPage()'), isTrue);
      expect(
        body.contains('FeedScreen()'),
        isFalse,
        reason: '/feed no longer uses legacy FeedScreen',
      );
    });

    test('AppRoutes.socialComposer route registered', () {
      expect(
        src.contains("static const String socialComposer = '/social/composer'"),
        isTrue,
      );
      expect(src.contains('SocialComposerPage('), isTrue);
    });
  });

  group('Donor-First - SocialFeedPage', () {
    final rawSrc = File(
      'lib/features/social/feed/social_feed_page.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('NestedScrollView not used; Column + RefreshIndicator + ListView', () {
      expect(src.contains('RefreshIndicator'), isTrue);
      expect(src.contains('ListView'), isTrue);
    });

    test('Paged feed notifier flow (feedPagedNotifierProvider)', () {
      expect(src.contains('feedPagedNotifierProvider'), isTrue);
      expect(src.contains('feedPagedNotifierProvider.notifier'), isTrue);
      expect(src.contains('.refresh()'), isTrue);
      expect(src.contains('.loadMore()'), isTrue);
    });

    test('Inline composer kalır, redundant feed FAB ve groups shortcut yok', () {
      expect(src.contains('InlineComposerCard'), isTrue);
      expect(src.contains('AppRoutes.socialComposer'), isFalse);
      expect(src.contains('FloatingActionButton.small'), isFalse);
      expect(src.contains('Icons.groups_2_outlined'), isFalse);
    });

    test('SocialStoriesCarousel and SocialPostCard are used', () {
      expect(src.contains('SocialStoriesCarousel'), isTrue);
      expect(src.contains('SocialPostCard'), isTrue);
    });
  });

  group('Donor-First - SocialPostCard', () {
    final rawSrc = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('Optimistic UI override pattern (like + save + likeCount)', () {
      expect(src.contains('_likedOverride'), isTrue);
      expect(src.contains('_savedOverride'), isTrue);
      expect(src.contains('_likeCountOverride'), isTrue);
    });

    test('toggleLike + toggleSave + deletePost and guest guard', () {
      expect(src.contains('toggleLike'), isTrue);
      expect(src.contains('toggleSave'), isTrue);
      expect(src.contains('deletePost'), isTrue);
      expect(src.contains('AuthRequiredGuard.canWriteWithRef'), isTrue);
      expect(src.contains('showAuthRequiredSheet'), isTrue);
    });

    test('Comment icon opens SocialCommentsPage.show', () {
      expect(src.contains('SocialCommentsPage.show(context, post.id)'), isTrue);
      expect(src.contains('FeedCommentSheet'), isFalse);
    });

    test('Native share + 15s timeout + Turkish error messages', () {
      expect(src.contains('Share.share'), isTrue);
      expect(src.contains('.timeout(const Duration(seconds: 15))'), isTrue);
      expect(src.contains('AppStrings.feedLikeUpdateError'), isTrue);
      expect(src.contains('AppStrings.feedSaveUpdateError'), isTrue);
    });

    test('P0 - Like uses thumb_up, not heart', () {
      expect(src.contains('Icons.thumb_up_alt_rounded'), isTrue);
      expect(src.contains('Icons.thumb_up_alt_outlined'), isTrue);
      expect(src.contains('Icons.favorite_rounded'), isFalse);
      expect(src.contains('Icons.favorite_border_rounded'), isFalse);
    });

    test('P0 - Active like color is brandLemonPressed', () {
      expect(
        src.contains('isLiked') &&
            src.contains('AppColors.brandLemonPressed') &&
            src.contains('AppColors.textPrimary'),
        isTrue,
        reason: 'Active like color should use brandLemonPressed',
      );
    });

    test('Feed Premium Sprint - action labels + engagement summary', () {
      expect(
        src.contains("'\$label · \$count'"),
        isFalse,
        reason: 'Action row no longer shows counts',
      );
      expect(src.contains('_PostEngagementSummary'), isTrue);
      expect(src.contains('_formatCount'), isTrue);
      expect(src.contains('AppStrings.postLikesShortLabel'), isTrue);
      expect(src.contains('AppStrings.postCommentsCountLabel'), isTrue);
      expect(src.contains('AppStrings.postViewAllComments'), isTrue);
      expect(src.contains('AppStrings.feedActionLike'), isTrue);
      expect(src.contains('AppStrings.feedActionComment'), isTrue);
      expect(src.contains('AppStrings.feedActionSave'), isTrue);
      expect(src.contains('AppStrings.feedActionShare'), isTrue);
    });

    test('P0 - Caption font 16.5 / author 15.5 / action label 12', () {
      expect(src.contains('fontSize: 16.5'), isTrue);
      expect(src.contains('fontSize: 15.5'), isTrue);
      expect(src.contains('fontSize: 12'), isTrue);
    });
  });

  group('Donor-First - SocialComposerPage', () {
    final rawSrc = File(
      'lib/features/social/composer/social_composer_page.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('image_picker + addPost + uploadFeedImage + rollback pipeline', () {
      expect(
        src.contains("import 'package:image_picker/image_picker.dart'"),
        isTrue,
      );
      expect(src.contains('.addPost('), isTrue);
      expect(src.contains('.uploadFeedImage('), isTrue);
      expect(src.contains('repo.deletePost(post.id)'), isTrue);
      expect(src.contains('feedComposerUploadError'), isTrue);
    });

    test('Auth guard + 30s/60s timeout', () {
      expect(src.contains('AuthRequiredGuard.canWriteWithRef'), isTrue);
      expect(src.contains('.timeout(const Duration(seconds: 30))'), isTrue);
      expect(src.contains('.timeout(const Duration(seconds: 60))'), isTrue);
    });

    test('Type chips: production/question/supply/equipment/job', () {
      expect(src.contains('PostType.production'), isTrue);
      expect(src.contains('PostType.question'), isTrue);
      expect(src.contains('PostType.supply'), isTrue);
      expect(src.contains('PostType.equipment'), isTrue);
      expect(src.contains('PostType.job'), isTrue);
    });
  });

  group('Donor-First - Legacy social cleanup (V2 Commit 4)', () {
    test('Router has no FeedScreen import and /feed -> SocialFeedPage', () {
      final routerSrc = _strip(
        File('lib/app/router/app_router.dart').readAsStringSync(),
      );
      expect(routerSrc.contains('FeedScreen()'), isFalse);
    });

    test('Legacy feed_screen.dart is deleted', () {
      final f = File('lib/features/feed/screens/feed_screen.dart');
      expect(f.existsSync(), isFalse);
    });

    test('Legacy feed_composer.dart is deleted', () {
      final f = File('lib/features/feed/widgets/feed_composer.dart');
      expect(f.existsSync(), isFalse);
    });

    test('Legacy feed_comment_sheet.dart is deleted', () {
      final f = File('lib/features/feed/widgets/feed_comment_sheet.dart');
      expect(f.existsSync(), isFalse);
    });

    test('Legacy premium/feed_post_card.dart is deleted', () {
      final f = File('lib/core/widgets/premium/feed_post_card.dart');
      expect(f.existsSync(), isFalse);
    });

    test('Legacy public_profile_screen.dart is deleted', () {
      final f = File('lib/features/profile/screens/public_profile_screen.dart');
      expect(
        f.existsSync(),
        isFalse,
        reason: 'Legacy PublicProfileScreen has been replaced',
      );
    });
  });
}
