// FırınNet — Donor-first social module rebuild kanıt testi.
//
// Bu testler eski sosyal sistemin (FeedScreen, FeedComposer, PostCardWired,
// FeedCommentSheet) **devre dışı** kaldığını ve yeni donor-first
// modüllerin (SocialFeedPage, SocialPostCard, SocialComposerPage,
// SocialStoriesCarousel) yerine geldiğini source-level guard ile doğrular.
//
// Donor: itsezlife flutter-instagram-offline-first-clone (MIT). Bkz.
// `third_party/instagram_offline_first_clone/LICENSE` ve repo kökündeki
// `THIRD_PARTY_NOTICES.md`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('Donor-First — third_party LICENSE + notices', () {
    test('third_party/instagram_offline_first_clone/LICENSE var', () {
      final f = File(
        'third_party/instagram_offline_first_clone/LICENSE',
      );
      expect(f.existsSync(), isTrue, reason: 'Donor LICENSE eklendi');
      final body = f.readAsStringSync();
      expect(body.contains('MIT License'), isTrue);
      expect(body.contains('Emil Zulufov'), isTrue);
    });

    test('THIRD_PARTY_NOTICES.md var ve donor attribution içeriyor', () {
      final f = File('THIRD_PARTY_NOTICES.md');
      expect(f.existsSync(), isTrue);
      final body = f.readAsStringSync();
      expect(body.contains('flutter-instagram-offline-first-clone'), isTrue);
      expect(body.contains('Riverpod'), isTrue);
      expect(body.contains('Supabase'), isTrue);
      // Substantial modification clause açıkça belirtildi.
      expect(body.contains('substantially modified'), isTrue);
    });
  });

  group('Donor-First — AppStrings yeni sabitler', () {
    test('feedLoadError + feedEmpty + retry + storiesMyStoryLabel', () {
      expect(AppStrings.feedLoadError.isNotEmpty, isTrue);
      expect(AppStrings.feedEmpty.isNotEmpty, isTrue);
      expect(AppStrings.retry, 'Yeniden dene');
      expect(AppStrings.storiesMyStoryLabel, 'Senin Hikayen');
      expect(AppStrings.feedComposerNewPostCta, 'Paylaş');
    });
  });

  group('Donor-First — Router: /feed → SocialFeedPage', () {
    final rawSrc = File('lib/app/router/app_router.dart')
        .readAsStringSync();
    final src = _strip(rawSrc);

    test('SocialFeedPage import edildi, FeedScreen import edilmedi', () {
      expect(src.contains('SocialFeedPage'), isTrue);
      expect(
        src.contains("import '../../features/feed/screens/feed_screen.dart'"),
        isFalse,
        reason: 'Eski FeedScreen import\'u router\'dan kaldırıldı',
      );
    });

    test('AppRoutes.feed pageBuilder SocialFeedPage döner', () {
      // ShellRoute içindeki AppRoutes.feed route'unu izole et.
      final start = src.indexOf('path: AppRoutes.feed,');
      expect(start, greaterThan(0));
      final end = src.indexOf('GoRoute(', start + 20);
      expect(end, greaterThan(start));
      final body = src.substring(start, end);
      expect(body.contains('SocialFeedPage()'), isTrue);
      expect(
        body.contains('FeedScreen()'),
        isFalse,
        reason: '/feed artık eski FeedScreen\'i kullanmıyor',
      );
    });

    test('AppRoutes.socialComposer route registered', () {
      expect(
        src.contains("static const String socialComposer = '/social/composer'"),
        isTrue,
      );
      // Feed Premium Sprint — composer artık `?media=`/`?type=` query
      // param'larıyla argümanlı kurulduğu için `SocialComposerPage(` yeterli.
      expect(src.contains('SocialComposerPage('), isTrue);
    });
  });

  group('Donor-First — SocialFeedPage', () {
    final rawSrc = File(
      'lib/features/social/feed/social_feed_page.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('NestedScrollView değil; Column + RefreshIndicator + ListView', () {
      // Donor pattern body. RefreshIndicator + ListView zorunlu.
      expect(src.contains('RefreshIndicator'), isTrue);
      expect(src.contains('ListView'), isTrue);
    });

    test('Paged feed notifier akışı (V2: feedPagedNotifierProvider)', () {
      // V2 Social Core: tekli feedPostsProvider yerine paged AsyncNotifier.
      // Pull-to-refresh notifier.refresh() çağırır; loadMore bottom scroll'da.
      expect(src.contains('feedPagedNotifierProvider'), isTrue);
      expect(
        src.contains('feedPagedNotifierProvider.notifier'),
        isTrue,
      );
      expect(src.contains('.refresh()'), isTrue);
      expect(src.contains('.loadMore()'), isTrue);
    });

    test('FloatingActionButton SocialComposer route\'a push eder', () {
      expect(src.contains('AppRoutes.socialComposer'), isTrue);
      // Feed Premium Sprint — inline composer paneli varken FAB minimal
      // (küçük, ikon-only) tutuldu; route/aksiyon korunur.
      expect(src.contains('FloatingActionButton.small'), isTrue);
    });

    test('SocialStoriesCarousel ve SocialPostCard kullanılıyor', () {
      expect(src.contains('SocialStoriesCarousel'), isTrue);
      expect(src.contains('SocialPostCard'), isTrue);
    });
  });

  group('Donor-First — SocialPostCard', () {
    final rawSrc = File(
      'lib/features/social/post/social_post_card.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('Optimistic UI override pattern (like + save + likeCount)', () {
      expect(src.contains('_likedOverride'), isTrue);
      expect(src.contains('_savedOverride'), isTrue);
      expect(src.contains('_likeCountOverride'), isTrue);
    });

    test('toggleLike + toggleSave + deletePost ve guest guard', () {
      expect(src.contains('toggleLike'), isTrue);
      expect(src.contains('toggleSave'), isTrue);
      expect(src.contains('deletePost'), isTrue);
      expect(src.contains('AuthRequiredGuard.canWriteWithRef'), isTrue);
      expect(src.contains('showAuthRequiredSheet'), isTrue);
    });

    test('Comment ikonu SocialCommentsPage.show açıyor (donor wiring)', () {
      expect(
        src.contains('SocialCommentsPage.show(context, post.id)'),
        isTrue,
      );
      // Eski FeedCommentSheet kullanılmıyor.
      expect(src.contains('FeedCommentSheet'), isFalse);
    });

    test('Native share + 15s timeout + Türkçe hata mesajları', () {
      expect(src.contains('Share.share'), isTrue);
      expect(
        src.contains('.timeout(const Duration(seconds: 15))'),
        isTrue,
      );
      expect(src.contains('AppStrings.feedLikeUpdateError'), isTrue);
      expect(src.contains('AppStrings.feedSaveUpdateError'), isTrue);
    });

    test('P0 — Beğeni Twitter/Facebook tarzı thumb_up, kalp YOK', () {
      // Kullanıcı kararı: kalp + kırmızı Instagram romantik dili istemiyoruz.
      // Aktif: Icons.thumb_up_alt_rounded, idle: Icons.thumb_up_alt_outlined.
      expect(src.contains('Icons.thumb_up_alt_rounded'), isTrue);
      expect(src.contains('Icons.thumb_up_alt_outlined'), isTrue);
      expect(
        src.contains('Icons.favorite_rounded'),
        isFalse,
        reason: 'P0 sonrası favorite/kalp ikonu kalmamalı',
      );
      expect(
        src.contains('Icons.favorite_border_rounded'),
        isFalse,
        reason: 'P0 sonrası favorite_border kalmamalı',
      );
    });

    test('P0 — Aktif beğeni rengi softGold (danger YOK)', () {
      // PostCard'ın action row'unda isLiked ? softGold : textPrimary
      // mapping'i. AppColors.danger sadece destructive aksiyon (Sil) için
      // kullanılır.
      expect(
        src.contains('isLiked ? AppColors.softGold : AppColors.textPrimary'),
        isTrue,
        reason: 'Beğeni aktif renk softGold (amber) olmalı',
      );
    });

    test('Feed Premium Sprint — sade action label + etkileşim özeti', () {
      // Sayılar action row'dan çıktı (artık "$label · $count" yok); etkileşim
      // özeti satırına taşındı (_PostEngagementSummary + _formatCount).
      expect(src.contains("'\$label · \$count'"), isFalse,
          reason: 'Action row artık sayı göstermiyor');
      expect(src.contains('_PostEngagementSummary'), isTrue);
      expect(src.contains('_formatCount'), isTrue);
      // Etkileşim özeti string'leri.
      expect(src.contains('AppStrings.postLikesShortLabel'), isTrue);
      expect(src.contains('AppStrings.postCommentsCountLabel'), isTrue);
      expect(src.contains('AppStrings.postViewAllComments'), isTrue);
      // Action row sade label'lar korunur.
      expect(src.contains('AppStrings.feedActionLike'), isTrue);
      expect(src.contains('AppStrings.feedActionComment'), isTrue);
      expect(src.contains('AppStrings.feedActionSave'), isTrue);
      expect(src.contains('AppStrings.feedActionShare'), isTrue);
    });

    test('P0 — Caption font 17 / author 15.5 / action label 12', () {
      expect(src.contains('fontSize: 17'), isTrue,
          reason: 'Caption 17 px (Twitter okunabilirlik)');
      expect(src.contains('fontSize: 15.5'), isTrue,
          reason: 'Author 15.5 px w800');
      // Feed Premium Sprint — kompakt yatay sosyal aksiyon: label 12 px.
      expect(src.contains('fontSize: 12'), isTrue,
          reason: 'Action label 12 px (kompakt social row)');
    });
  });

  group('Donor-First — SocialComposerPage', () {
    final rawSrc = File(
      'lib/features/social/composer/social_composer_page.dart',
    ).readAsStringSync();
    final src = _strip(rawSrc);

    test('image_picker + addPost + uploadFeedImage + rollback pipeline', () {
      expect(src.contains("import 'package:image_picker/image_picker.dart'"),
          isTrue);
      // dart format multi-line: `repo` ve `.addPost(` ayrı satırlarda; literal
      // arama yerine fonksiyon adlarını arıyoruz.
      expect(src.contains('.addPost('), isTrue);
      expect(src.contains('.uploadFeedImage('), isTrue);
      // Upload fail → repo.deletePost(post.id) rollback (silent text-only
      // fallback YOK).
      expect(src.contains('repo.deletePost(post.id)'), isTrue);
      expect(src.contains('feedComposerUploadError'), isTrue);
    });

    test('Auth guard + 30s/60s timeout', () {
      expect(src.contains('AuthRequiredGuard.canWriteWithRef'), isTrue);
      expect(
        src.contains('.timeout(const Duration(seconds: 30))'),
        isTrue,
      );
      expect(
        src.contains('.timeout(const Duration(seconds: 60))'),
        isTrue,
      );
    });

    test('Type chips: production/question/supply/equipment/job', () {
      expect(src.contains('PostType.production'), isTrue);
      expect(src.contains('PostType.question'), isTrue);
      expect(src.contains('PostType.supply'), isTrue);
      expect(src.contains('PostType.equipment'), isTrue);
      expect(src.contains('PostType.job'), isTrue);
    });
  });

  group('Donor-First — Legacy social cleanup (V2 Commit 4)', () {
    test('Router\'da FeedScreen import yok ve /feed → SocialFeedPage', () {
      final routerSrc = _strip(
        File('lib/app/router/app_router.dart').readAsStringSync(),
      );
      expect(routerSrc.contains('FeedScreen()'), isFalse);
    });

    test('Eski feed_screen.dart dosyası tamamen silindi', () {
      final f = File('lib/features/feed/screens/feed_screen.dart');
      expect(f.existsSync(), isFalse,
          reason: 'V2 Commit 4: legacy FeedScreen + PostCardWired silindi');
    });

    test('Eski feed_composer.dart dosyası tamamen silindi', () {
      final f = File('lib/features/feed/widgets/feed_composer.dart');
      expect(f.existsSync(), isFalse,
          reason: 'V2 Commit 4: legacy FeedComposer silindi');
    });

    test('Eski feed_comment_sheet.dart dosyası tamamen silindi', () {
      final f = File('lib/features/feed/widgets/feed_comment_sheet.dart');
      expect(f.existsSync(), isFalse,
          reason: 'V2 Commit 4: legacy FeedCommentSheet silindi');
    });

    test('Eski premium/feed_post_card.dart dosyası tamamen silindi', () {
      final f = File('lib/core/widgets/premium/feed_post_card.dart');
      expect(f.existsSync(), isFalse,
          reason: 'V2 Commit 4: legacy FeedPostCard silindi');
    });

    test('Eski public_profile_screen.dart dosyası tamamen silindi', () {
      final f = File('lib/features/profile/screens/public_profile_screen.dart');
      expect(f.existsSync(), isFalse,
          reason: 'V2 Commit 4: legacy PublicProfileScreen silindi '
              '(SocialProfilePage F2\'de yerini almıştı)');
    });
  });
}
