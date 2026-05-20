// FırınNet Social F2 — Donor-first Profile + Follow + Followers/Following.
//
// Background:
//   Eski public_profile_screen.dart yamalama yerine yeni
//   lib/features/social/profile/ donor pattern kuruldu:
//   * SocialProfile model + composite providers (profile snapshot +
//     post count + follow counts + isFollowing).
//   * ProfilePage (donor user_profile_page).
//   * ProfileHeader, ProfileStatistics widgets.
//   * SocialUserListPage (followers/following — donor list pattern).
//   * AppRouter `/u/:userId`, `/u/:userId/followers`, `/u/:userId/following`.
//   * Feed header avatar tap → kendi public profile (own profile entry).
//   * FollowRepository extended: listFollowerIds + listFollowingIds.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/repositories/local_follow_repository.dart';
import 'package:firin_defter/features/social/models/social_profile.dart';

void main() {
  group('F2 — AppStrings yeni sabitler', () {
    test('Profile statistics + list titles', () {
      expect(AppStrings.profileStatPosts, 'Gönderi');
      expect(AppStrings.profileStatFollowers, 'Takipçi');
      expect(AppStrings.profileStatFollowing, 'Takip');
      expect(AppStrings.followersListTitle, 'Takipçiler');
      expect(AppStrings.followingListTitle, 'Takip edilenler');
    });

    test('Empty state metinleri', () {
      expect(AppStrings.followersEmpty, 'Henüz takipçi yok.');
      expect(AppStrings.followingEmpty, 'Henüz takip edilen yok.');
    });
  });

  group('F2 — SocialProfile model', () {
    test('displayNameOrFallback boş/null → fallback', () {
      const p1 = SocialProfile(id: 'u1', displayName: 'Hasan Usta');
      expect(p1.displayNameOrFallback, 'Hasan Usta');
      const p2 = SocialProfile(id: 'u2');
      expect(p2.displayNameOrFallback, SocialProfile.fallbackName);
      const p3 = SocialProfile(id: 'u3', displayName: '   ');
      expect(p3.displayNameOrFallback, SocialProfile.fallbackName);
    });

    test('initial — avatar placeholder', () {
      const p1 = SocialProfile(id: 'u1', displayName: 'Hasan Usta');
      expect(p1.initial, 'H');
      const p2 = SocialProfile(id: 'u2');
      expect(p2.initial, 'F'); // FırınNet Kullanıcısı → 'F'
    });
  });

  group('F2 — FollowRepository listFollowerIds + listFollowingIds (local)',
      () {
    test('Local repo follow + list', () async {
      // İki ayrı user perspektifinde repo örnekleri kur, follow edip
      // ardından listFollowerIds / listFollowingIds doğrula.
      final aRepo = LocalFollowRepository(currentUserId: 'a');
      await aRepo.followProfile('b');
      await aRepo.followProfile('c');

      // a → b, a → c (a takip ediyor b ve c'yi).
      final aFollowing = await aRepo.listFollowingIds('a');
      expect(aFollowing, containsAll(<String>['b', 'c']));

      // b'yi takip edenler — sadece a (local repo, kendi state'inde).
      final bFollowers = await aRepo.listFollowerIds('b');
      expect(bFollowers, contains('a'));
    });

    test('Boş set → empty list', () async {
      final repo = LocalFollowRepository(currentUserId: 'solo');
      expect(await repo.listFollowerIds('solo'), isEmpty);
      expect(await repo.listFollowingIds('solo'), isEmpty);
    });
  });

  group('F2 — Source-level: app router', () {
    final src = File('lib/app/router/app_router.dart').readAsStringSync();

    test('SocialProfilePage route registered', () {
      expect(src.contains('SocialProfilePage('), isTrue);
      expect(
        src.contains("'\${AppRoutes.userPublicProfile}/:userId'"),
        isTrue,
      );
    });

    test('Followers + Following list routes', () {
      expect(
        src.contains('/:userId/followers'),
        isTrue,
        reason: 'Followers route registered',
      );
      expect(
        src.contains('/:userId/following'),
        isTrue,
      );
      expect(src.contains('SocialUserListPage('), isTrue);
      expect(src.contains('UserListKind.followers'), isTrue);
      expect(src.contains('UserListKind.following'), isTrue);
    });
  });

  group('F2 — Source-level: SocialProfilePage donor pattern', () {
    final src = File(
      'lib/features/social/profile/profile_page.dart',
    ).readAsStringSync();

    test('RefreshIndicator + composite providers + tap navigations', () {
      expect(src.contains('RefreshIndicator'), isTrue);
      expect(src.contains('socialProfileProvider'), isTrue);
      expect(src.contains('userPostsProvider'), isTrue);
      expect(src.contains('followCountsProvider'), isTrue);
      expect(src.contains('socialProfilePostCountProvider'), isTrue);
      // Followers/Following tap → list pages
      expect(src.contains('/followers'), isTrue);
      expect(src.contains('/following'), isTrue);
    });

    test('Boş ekran fallback: empty/error states görünür', () {
      expect(src.contains('publicProfileLoadError'), isTrue);
      expect(src.contains('publicProfilePostsEmpty'), isTrue);
    });

    test('Kendi profilinde follow button gizli', () {
      expect(
        src.contains('if (!isSelf)'),
        isTrue,
        reason: 'isSelf true ise FollowButton render edilmemeli',
      );
    });
  });

  group('F2 — Source-level: feed header avatar tap → own public profile',
      () {
    // V2 Commit 4 cleanup: eski feed_screen.dart silindi. Header
    // SocialFeedPage'a taşındı (_SocialFeedHeader → _ProfileAvatarAction).
    final src = File(
      'lib/features/social/feed/social_feed_page.dart',
    ).readAsStringSync();

    test('Avatar tap currentAuthUser.id ile userPublicProfile route\'a gider',
        () {
      // _ProfileAvatarAction içinde currentAuthUserProvider + userPublicProfile
      // birlikte kullanılıyor.
      expect(src.contains('currentAuthUserProvider'), isTrue);
      expect(src.contains('AppRoutes.userPublicProfile'), isTrue);
      expect(
        src.contains("'\${AppRoutes.userPublicProfile}/\${user.id}'"),
        isTrue,
      );
    });
  });
}
