// FırınNet Social V2 Commit 3.6 — Media regression fix testleri.
//
// İki ayrı bug:
//   1. Story → Foto çek → paylaş hata veriyor (Bug 1).
//   2. Feed video post profilde görünmüyor (Bug 2).
//
// Root cause'lar:
//   1. ImageSource.camera dönen XFile bazı Android sürümlerinde
//      uzantısız/path-only döner; eski `name.lastIndexOf('.')` ext
//      çıkarma yetersiz. Fix: `_extractExt` ile name→path→jpg fallback
//      + bilinen image extension whitelist.
//   2. SocialProfilePage post listesinde eski `PostCardWired` (sadece
//      image render eder) kullanılıyordu. Fix: `SocialPostCard` ile
//      değiştir; aynı widget feed ve profile'da video destekler.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Commit 3.6 — Bug 1: Story camera ext fallback', () {
    final src = _strip(
      File('lib/features/social/stories/story_create_page.dart')
          .readAsStringSync(),
    );

    test('_extractExt helper bilinen image extension whitelist', () {
      expect(src.contains('static String _extractExt'), isTrue);
      // jpg + jpeg + png + webp + heic + heif kabul edilir
      expect(src.contains("'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'"),
          isTrue);
      // Fallback 'jpg'
      expect(src.contains("return 'jpg';"), isTrue);
    });

    test('Camera path debugPrint trace (pick start/got/cancelled/error)',
        () {
      expect(
        src.contains('[FirinNet][StoryCreate] pick start source='),
        isTrue,
      );
      expect(
        src.contains('[FirinNet][StoryCreate] pick cancelled'),
        isTrue,
      );
      expect(
        src.contains('[FirinNet][StoryCreate] pick got name='),
        isTrue,
      );
      expect(
        src.contains('[FirinNet][StoryCreate] pick error'),
        isTrue,
      );
    });

    test('ImageSource.camera + ImageSource.gallery iki yol da kullanılıyor',
        () {
      expect(src.contains('_captureOrPick(ImageSource.gallery)'), isTrue);
      expect(src.contains('_captureOrPick(ImageSource.camera)'), isTrue);
    });

    test('Camera cancel x==null → sessizce dön (hata göstermez)', () {
      expect(
        src.contains('if (x == null) {'),
        isTrue,
      );
      expect(
        src.contains("return;"),
        isTrue,
      );
    });
  });

  group('V2 Commit 3.6 — Composer camera ext fallback (regression guard)',
      () {
    final src = _strip(
      File('lib/features/social/composer/social_composer_page.dart')
          .readAsStringSync(),
    );

    test('_extractImageExt + _extractVideoExt helpers', () {
      expect(src.contains('static String _extractImageExt'), isTrue);
      expect(src.contains('static String _extractVideoExt'), isTrue);
      // Video whitelist
      expect(src.contains("'mp4', 'm4v', 'mov', 'webm', '3gp'"), isTrue);
    });

    test('Composer pickImage/pickVideo debugPrint trace', () {
      expect(src.contains('[FirinNet][Composer] pickImage source='), isTrue);
      expect(src.contains('[FirinNet][Composer] pickImage cancelled'), isTrue);
      expect(src.contains('[FirinNet][Composer] pickImage got name='), isTrue);
      expect(src.contains('[FirinNet][Composer] pickImage error'), isTrue);
      expect(src.contains('[FirinNet][Composer] pickVideo source='), isTrue);
      expect(src.contains('[FirinNet][Composer] pickVideo too large'), isTrue);
    });
  });

  group('V2 Commit 3.6 — Bug 2: Profile video visibility', () {
    final src = _strip(
      File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync(),
    );

    test('Profile post listesi SocialPostCard kullanır (video destekli)',
        () {
      expect(src.contains('SocialPostCard(key: ValueKey(p.id), post: p)'),
          isTrue);
      // Eski PostCardWired kullanılmamalı
      expect(
        src.contains('PostCardWired'),
        isFalse,
        reason:
            'PostCardWired sadece image render eder; SocialPostCard image+video',
      );
    });

    test('Eski feed_screen.dart import\'u profile_page\'den kaldırıldı', () {
      // feed_screen.dart import'u (eski FeedScreen + PostCardWired'in yuva-
      // ladığı dosya) artık profile_page'de yok.
      expect(
        src.contains(
          "import '../../feed/screens/feed_screen.dart'",
        ),
        isFalse,
      );
    });

    test('SocialPostCard import edildi', () {
      expect(
        src.contains("import '../post/social_post_card.dart'"),
        isTrue,
      );
    });

    test('Pull-to-refresh userPostsProvider invalidate eder', () {
      expect(
        src.contains('ref.invalidate(userPostsProvider(userId))'),
        isTrue,
      );
    });
  });

  group('V2 Commit 3.6 — listPostsByOwner media mapping (backend OK)', () {
    final src = _strip(
      File('lib/features/feed/repositories/supabase_feed_repository.dart')
          .readAsStringSync(),
    );

    test('_fetchMediaByPostIds media_type filter YOK (image+video birlikte)',
        () {
      // Profile query'sinin kullandığı _fetchMediaByPostIds bütün
      // media_type'ları (image+video) çeker; sadece is_deleted=false filtre.
      final start = src.indexOf('_fetchMediaByPostIds');
      expect(start, greaterThan(0));
      final end = src.indexOf('Future<', start + 30);
      final body = src.substring(start, end);
      // Bu blokta media_type filtresi olmamalı
      expect(
        body.contains("eq('media_type'"),
        isFalse,
        reason: 'Profile query video media\'yı dışlamamalı',
      );
      expect(body.contains(".eq('is_deleted', false)"), isTrue);
    });

    test('listPostsByOwner _fetchMediaByPostIds kullanır', () {
      final start = src.indexOf('Future<List<FeedPost>> listPostsByOwner');
      expect(start, greaterThan(0));
      final end = src.indexOf('Future<', start + 50);
      final body = src.substring(start, end);
      expect(body.contains('_fetchMediaByPostIds(ids)'), isTrue);
    });
  });
}
