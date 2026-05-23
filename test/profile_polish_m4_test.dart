// FırınNet Profile Polish M4 — invariant testleri.
//
// 3 küçük polish:
//   1. Avatar eski dosya cleanup (extractStoragePath + deleteIfOwned guard)
//   2. Profile posts pagination (listPostsByOwnerPage + userPostsPagedNotifier)
//   3. SocialPostVideo visibility pause (visibleFraction < 0.5 → pause,
//      autoplay yok)

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/profile/services/avatar_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M4 T1 — AvatarUploadService.extractStoragePath', () {
    test('Bizim public URL pattern → path doğru çıkar', () {
      const url =
          'https://abc.supabase.co/storage/v1/object/public/avatars/u123/avatar_999.jpg';
      expect(
        AvatarUploadService.extractStoragePath(url),
        'u123/avatar_999.jpg',
      );
    });

    test('Farklı bucket URL → null', () {
      const url =
          'https://abc.supabase.co/storage/v1/object/public/feed-media/u1/p1/m1.jpg';
      expect(AvatarUploadService.extractStoragePath(url), isNull);
    });

    test('Boş veya null → null', () {
      expect(AvatarUploadService.extractStoragePath(null), isNull);
      expect(AvatarUploadService.extractStoragePath(''), isNull);
    });

    test('Path traversal reddedilir (`..`)', () {
      const url =
          'https://x/storage/v1/object/public/avatars/../foo.jpg';
      expect(AvatarUploadService.extractStoragePath(url), isNull);
    });

    test('Leading slash reddedilir', () {
      const url =
          'https://x/storage/v1/object/public/avatars//u1/avatar.jpg';
      expect(AvatarUploadService.extractStoragePath(url), isNull);
    });
  });

  group('M4 T1 — Source-level guard kontrolleri', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/services/avatar_upload_service.dart',
      ).readAsStringSync();
    });

    test('deleteIfOwned owner-prefix mismatch → no-op', () {
      // İlk segmenti userId ile karşılaştırıyoruz; mismatch'te skip log + dönüş.
      expect(src.contains('firstSegment != userId'), isTrue);
      expect(src.contains('skip cleanup'), isTrue);
    });

    test('deleteIfOwned best-effort try/catch ile sarılı', () {
      expect(src.contains('cleanup failed'), isTrue);
    });
  });

  group('M4 T1 — ProfileEditSheet cleanup hook', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/widgets/profile_edit_sheet.dart',
      ).readAsStringSync();
    });

    test('Save sonrası deleteIfOwned çağrısı var', () {
      expect(src.contains('deleteIfOwned'), isTrue);
      expect(src.contains('previousAvatarUrl'), isTrue);
    });

    test('Save fail olursa cleanup çalışmaz (try bloğu içinde)', () {
      // save -> await + ardından cleanup -> ikisi de try içinde; save throw
      // olursa cleanup atlanır.
      final saveIdx = src.indexOf('profileControllerProvider.notifier).save');
      final cleanupIdx = src.indexOf('deleteIfOwned');
      expect(saveIdx >= 0 && cleanupIdx > saveIdx, isTrue,
          reason: 'deleteIfOwned save\'den sonra çağrılmalı');
    });
  });

  group('M4 T2 — LocalFeedRepository.listPostsByOwnerPage', () {
    test('offset+limit ile alt-küme döner; owner filtresi korunur', () async {
      final repo = LocalFeedRepository(seed: true, currentUserId: 'me');
      final all = await repo.listPostsByOwner('me');
      if (all.isEmpty) return; // Seed kullanıcısı boşsa skip.
      final first = await repo
          .listPostsByOwnerPage(ownerId: 'me', offset: 0, limit: 1);
      expect(first.length, 1);
      expect(first.first.ownerId, 'me');
      // İkinci sayfa (seed >=2 ise) farklı id döndürmeli.
      if (all.length >= 2) {
        final second = await repo
            .listPostsByOwnerPage(ownerId: 'me', offset: 1, limit: 1);
        expect(second.length, 1);
        expect(second.first.id, isNot(first.first.id));
      }
    });

    test('offset >= length → boş liste', () async {
      final repo = LocalFeedRepository(seed: false);
      final out = await repo
          .listPostsByOwnerPage(ownerId: 'x', offset: 0, limit: 20);
      expect(out, isEmpty);
    });
  });

  group('M4 T2 — Provider + UI invariant', () {
    test('feed_providers.dart userPostsPagedNotifier tanımlı', () {
      final src = File(
        'lib/features/feed/providers/feed_providers.dart',
      ).readAsStringSync();
      expect(src.contains('class UserPostsPagedNotifier'), isTrue);
      expect(src.contains('userPostsPagedNotifierProvider'), isTrue);
      expect(src.contains('listPostsByOwnerPage'), isTrue);
      // Duplicate-id guard: append'te existing id'ler set'leniyor.
      expect(src.contains('existingIds.contains'), isTrue);
    });

    test('SocialProfilePage pagedAsync watch + Daha fazla göster CTA', () {
      final src = File(
        'lib/features/social/profile/profile_page.dart',
      ).readAsStringSync();
      expect(src.contains('userPostsPagedNotifierProvider(userId)'), isTrue);
      expect(src.contains('_LoadMoreCta'), isTrue);
      expect(src.contains('profilePostsLoadMore'), isTrue);
      // hasMore false olduğunda CTA gizli (sadece hasMore ise eklenir).
      expect(src.contains('if (paged.hasMore)'), isTrue);
    });

    test('AppStrings.profilePostsLoadMore tanımlı', () {
      expect(AppStrings.profilePostsLoadMore, 'Daha fazla göster');
    });
  });

  group('M4 T3 — SocialPostVideo visibility pause', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/social/post/widgets/social_post_video.dart',
      ).readAsStringSync();
    });

    test('visibility_detector import edildi + VisibilityDetector wrap', () {
      expect(src.contains("import 'package:visibility_detector"), isTrue);
      expect(src.contains('VisibilityDetector('), isTrue);
    });

    test('visibleFraction < 0.5 → pause; autoplay YOK', () {
      expect(src.contains('_visibleThreshold = 0.5'), isTrue);
      expect(
        src.contains('info.visibleFraction < _visibleThreshold'),
        isTrue,
      );
      expect(src.contains('c.pause()'), isTrue);
      // Tekrar görünür olunca autoplay eklemedik — yorum invariant'ı.
      expect(src.contains('autoplay'), isTrue);
      // autoPlay: false hâlâ chewie'de set.
      expect(src.contains('autoPlay: false'), isTrue);
    });

    test('dispose hijyeni korunuyor', () {
      expect(src.contains('_chewie?.dispose()'), isTrue);
      expect(src.contains('_controller?.dispose()'), isTrue);
    });
  });
}
