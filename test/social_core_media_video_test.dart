// FırınNet Social V2 Commit 3 — Video post desteği testleri.
//
// Kapsam:
//   * FeedRepository.uploadFeedVideo interface + Supabase/Local/Guarded
//     impl'lerinin parite.
//   * Supabase impl `media_type='video'` + storage rollback.
//   * Composer: pickVideo + 50MB size guard + 60s duration limit +
//     mutually exclusive image/video state + uploadFeedVideo 120s timeout.
//   * Post card: firstVideo varsa SocialPostVideo render eder.
//   * FeedPost.hasVideo + firstVideo getters.
//   * AppStrings yeni video sabitleri.
//   * pubspec'te video_player + chewie bağımlılığı.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/models/feed_media.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Commit 3 — Pubspec video dependency', () {
    test('video_player + chewie bağımlılıkları eklendi', () {
      final src = File('pubspec.yaml').readAsStringSync();
      expect(src.contains('video_player:'), isTrue);
      expect(src.contains('chewie:'), isTrue);
    });
  });

  group('V2 Commit 3 — FeedRepository.uploadFeedVideo interface', () {
    final src = _strip(
      File('lib/features/feed/repositories/feed_repository.dart')
          .readAsStringSync(),
    );

    test('uploadFeedVideo imzası tanımlı', () {
      expect(src.contains('Future<FeedMedia> uploadFeedVideo'), isTrue);
      expect(src.contains('int? durationMs'), isTrue);
    });
  });

  group('V2 Commit 3 — Supabase uploadFeedVideo impl', () {
    final src = _strip(
      File('lib/features/feed/repositories/supabase_feed_repository.dart')
          .readAsStringSync(),
    );

    test("'video' media_type INSERT + rollback", () {
      final start = src.indexOf('Future<FeedMedia> uploadFeedVideo');
      expect(start, greaterThan(0));
      final next = src.indexOf('static String', start + 30);
      final body = src.substring(start, next);
      expect(body.contains("'media_type': 'video'"), isTrue);
      expect(body.contains(".storage.from('feed-media')"), isTrue);
      expect(body.contains('uploadBinary('), isTrue);
      // Rollback path
      expect(body.contains('.remove(<String>[path])'), isTrue);
    });

    test('_mimeForVideoExt mp4 + mov + webm', () {
      expect(src.contains("'video/mp4'"), isTrue);
      expect(src.contains("'video/quicktime'"), isTrue);
      expect(src.contains("'video/webm'"), isTrue);
    });
  });

  group('V2 Commit 3 — Guarded uploadFeedVideo guard', () {
    test('write guard + delegate', () {
      final src = _strip(
        File('lib/features/feed/repositories/guarded_feed_repository.dart')
            .readAsStringSync(),
      );
      expect(src.contains('Future<FeedMedia> uploadFeedVideo'), isTrue);
      expect(src.contains("'gönderiye video eklemek'"), isTrue);
      expect(src.contains('inner.uploadFeedVideo('), isTrue);
    });
  });

  group('V2 Commit 3 — Local uploadFeedVideo davranışı', () {
    test('Video media_type ile post.mediaList\'e eklenir', () async {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      final post = await repo.addPost(
        type: PostType.production,
        author: 'Me',
        role: 'Usta',
        text: 'video post',
      );
      final media = await repo.uploadFeedVideo(
        postId: post.id,
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        fileExtension: 'mp4',
      );
      expect(media.mediaType, 'video');
      expect(media.postId, post.id);
      expect(media.ownerId, 'me');
      // Liste'den de görünür
      final fetched = await repo.listPosts();
      expect(fetched.first.hasVideo, isTrue);
      expect(fetched.first.firstVideo?.id, media.id);
    });

    test('Var olmayan post için video upload → StateError', () {
      final repo = LocalFeedRepository(
        seed: false,
        currentUserId: 'me',
      );
      expect(
        () => repo.uploadFeedVideo(
          postId: 'not_exist',
          bytes: Uint8List.fromList(<int>[1]),
          fileExtension: 'mp4',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('V2 Commit 3 — FeedPost.hasVideo / firstVideo getters', () {
    test('Video media içeren post hasVideo true + firstVideo döner', () {
      final video = FeedMedia(
        id: 'fm1',
        postId: 'p1',
        ownerId: 'u1',
        mediaType: 'video',
        storagePath: 'u1/p1/fm1.mp4',
        publicUrl: 'https://example.com/v.mp4',
        createdAt: DateTime(2026, 5, 20),
      );
      final post = FeedPost(
        id: 'p1',
        ownerId: 'u1',
        type: PostType.production,
        author: 'a',
        role: 'r',
        text: 't',
        createdAt: DateTime(2026, 5, 20),
        gradient: const [],
        mediaList: <FeedMedia>[video],
      );
      expect(post.hasVideo, isTrue);
      expect(post.firstVideo?.id, 'fm1');
      expect(post.hasImage, isFalse);
      expect(post.firstImage, isNull);
    });
  });

  group('V2 Commit 3 — Composer video state machine', () {
    final src = _strip(
      File('lib/features/social/composer/social_composer_page.dart')
          .readAsStringSync(),
    );

    test('Maks 50 MB + 60s duration limit sabitleri', () {
      expect(
        src.contains('static const int _maxVideoBytes = 50 * 1024 * 1024'),
        isTrue,
      );
      expect(
        src.contains(
          'static const Duration _maxVideoDuration = Duration(seconds: 60)',
        ),
        isTrue,
      );
    });

    test('pickVideo + size guard + image mutually exclusive', () {
      expect(src.contains('Future<void> _pickVideo()'), isTrue);
      expect(src.contains('picker.pickVideo('), isTrue);
      expect(src.contains('bytes.length > _maxVideoBytes'), isTrue);
      expect(src.contains('AppStrings.composerVideoTooLargeError'), isTrue);
      // Image picked'ı sıfırla → mutually exclusive
      expect(
        src.contains('_pickedBytes = null'),
        isTrue,
        reason: 'Video seçilince image sıfırlanır',
      );
    });

    test('Submit pipeline uploadFeedVideo + 120s timeout + rollback', () {
      // dart format multi-line: `repo` ve `.uploadFeedVideo(` ayrı satırlarda;
      // method adıyla ara.
      expect(src.contains('.uploadFeedVideo('), isTrue);
      expect(
        src.contains('.timeout(const Duration(seconds: 120))'),
        isTrue,
      );
      expect(
        src.contains('AppStrings.composerVideoUploadError'),
        isTrue,
      );
      // Upload fail → repo.deletePost rollback (image yolundaki ile aynı)
      expect(src.contains('repo.deletePost(post.id)'), isTrue);
    });
  });

  group('V2 Commit 3 — SocialPostCard video player wiring', () {
    final src = _strip(
      File('lib/features/social/post/social_post_card.dart').readAsStringSync(),
    );

    test('post.firstVideo varsa SocialPostVideo render eder', () {
      expect(src.contains('post.firstVideo?.publicUrl'), isTrue);
      expect(src.contains('SocialPostVideo(url: videoUrl)'), isTrue);
      // Image VEYA video — image varsa öncelik (image kart-tap sarmalayıcı
      // içinde; video yalnız image yokken, kendi kontrolleriyle dışarıda).
      expect(src.contains('if (imageUrl != null)'), isTrue);
      expect(src.contains('imageUrl == null && videoUrl != null'), isTrue);
    });
  });

  group('V2 Commit 3 — SocialPostVideo widget kontratları', () {
    final src = _strip(
      File('lib/features/social/post/widgets/social_post_video.dart')
          .readAsStringSync(),
    );

    test('Chewie + video_player import ve autoPlay=false', () {
      expect(src.contains("import 'package:chewie/chewie.dart'"), isTrue);
      expect(
        src.contains("import 'package:video_player/video_player.dart'"),
        isTrue,
      );
      expect(src.contains('autoPlay: false'), isTrue);
      expect(src.contains('looping: false'), isTrue);
    });

    test('Init fail durumunda fallback hata kutusu', () {
      expect(src.contains('_initFailed'), isTrue);
      expect(src.contains('AppStrings.postVideoPlaybackError'), isTrue);
    });

    test('Dispose chewie + controller', () {
      expect(src.contains('_chewie?.dispose()'), isTrue);
      expect(src.contains('_controller?.dispose()'), isTrue);
    });
  });

  group('V2 Commit 3 — AppStrings video sabitleri', () {
    test('Composer + post-card video metinleri', () {
      // V2 Commit 3.5'te "Video ekle" → "Video seç" rename edildi (4-buton
      // pattern: Foto seç / Foto çek / Video seç / Video çek).
      expect(AppStrings.composerPickVideoCta, 'Video seç');
      expect(AppStrings.composerVideoTooLargeError.contains('50 MB'), isTrue);
      expect(AppStrings.composerVideoTooLongError.contains('60'), isTrue);
      expect(AppStrings.postVideoPlaybackError.contains('oynatılamadı'), isTrue);
    });
  });
}
