// V1.4 P1.18 / P1.19 / P1.20 / P1.21 — Feed/Group write action hata
// yönetimi regression.
//
// 10/10 Risk Discovery (U-1) bulguları:
//   P1.18  feed like toggle no try/catch
//   P1.19  feed save toggle no try/catch
//   P1.20  group leave non-guest errors propagate
//   P1.21  group message send no error UX
//
// Bu test her dört handler için:
//   - Repo throws → Türkçe hata snackbar görünür
//   - State temiz kalır (input metni korunur, button re-enabled)
//
// Pattern: P0.1 (feed composer) ve P1.23 (dealer note) ile aynı.

import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/models/feed_comment.dart';
import 'package:firin_defter/features/feed/models/feed_insight.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/feed/screens/feed_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_join_request.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/models/social_group.dart';
import 'package:firin_defter/features/social_groups/providers/social_group_providers.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/social_group_repository.dart';
import 'package:firin_defter/features/social_groups/screens/group_detail_screen.dart';
import 'package:firin_defter/features/social_groups/services/group_join_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────── Fakes

class _ThrowingFeedRepo extends LocalFeedRepository {
  _ThrowingFeedRepo({this.throwOnLike = false, this.throwOnSave = false})
      : super(seed: false);

  final bool throwOnLike;
  final bool throwOnSave;
  int toggleLikeCalls = 0;
  int toggleSaveCalls = 0;

  @override
  Future<FeedPost> toggleLike(String postId) {
    toggleLikeCalls++;
    if (throwOnLike) {
      return Future<FeedPost>.error(Exception('network boom (like)'));
    }
    return super.toggleLike(postId);
  }

  @override
  Future<FeedPost> toggleSave(String postId) {
    toggleSaveCalls++;
    if (throwOnSave) {
      return Future<FeedPost>.error(Exception('network boom (save)'));
    }
    return super.toggleSave(postId);
  }
}

class _ThrowingGroupRepo implements SocialGroupRepository {
  _ThrowingGroupRepo({this.throwOnLeave = false, this.throwOnPost = false});

  final bool throwOnLeave;
  final bool throwOnPost;
  int leaveCalls = 0;
  int postCalls = 0;
  final _changes = StreamController<void>.broadcast();
  final _local = LocalSocialGroupRepository();

  @override
  Future<void> leaveGroup(String id) {
    leaveCalls++;
    if (throwOnLeave) {
      return Future<void>.error(Exception('network boom (leave)'));
    }
    return _local.leaveGroup(id);
  }

  @override
  Future<void> postMessage(GroupMessage m) {
    postCalls++;
    if (throwOnPost) {
      return Future<void>.error(Exception('network boom (post)'));
    }
    return _local.postMessage(m);
  }

  // Tüm diğer metodlar `LocalSocialGroupRepository`'ye delege.
  @override
  Future<List<SocialGroup>> listGroups({GroupCategory? category}) =>
      _local.listGroups(category: category);

  @override
  Future<List<SocialGroup>> listPopular({int limit = 6}) =>
      _local.listPopular(limit: limit);

  @override
  Future<List<SocialGroup>> listJoined() => _local.listJoined();

  @override
  Future<SocialGroup?> getGroup(String id) => _local.getGroup(id);

  @override
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    String city = '',
    bool isPrivate = false,
    int? maxMembers,
    List<String> tags = const <String>[],
  }) =>
      _local.createGroup(
        name: name,
        description: description,
        category: category,
        city: city,
        isPrivate: isPrivate,
        maxMembers: maxMembers,
        tags: tags,
      );

  @override
  Future<GroupJoinResult> joinGroup(String id) => _local.joinGroup(id);

  @override
  bool isJoined(String id) => _local.isJoined(id);

  @override
  Future<List<GroupMessage>> listMessages(String groupId) =>
      _local.listMessages(groupId);

  // V1 P1-D — Private join requests delegation (test scope: no throw).
  @override
  Future<GroupJoinRequest> requestJoinGroup(
    String groupId, {
    String? message,
  }) =>
      _local.requestJoinGroup(groupId, message: message);

  @override
  Future<GroupJoinRequest?> getMyJoinRequest(String groupId) =>
      _local.getMyJoinRequest(groupId);

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests(String groupId) =>
      _local.listPendingJoinRequests(groupId);

  @override
  Future<int> pendingJoinRequestCount(String groupId) =>
      _local.pendingJoinRequestCount(groupId);

  @override
  Future<GroupJoinRequest> approveJoinRequest(String requestId) =>
      _local.approveJoinRequest(requestId);

  @override
  Future<GroupJoinRequest> rejectJoinRequest(String requestId) =>
      _local.rejectJoinRequest(requestId);

  @override
  Stream<void> watch() => _changes.stream;
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _realProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

// ─────────────────────────────────────── Helpers

Widget _wrapFeed(FeedRepository repo, Widget child) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
}

Widget _wrapGroup(SocialGroupRepository repo, Widget child) {
  return ProviderScope(
    overrides: [
      socialGroupRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
}

FeedPost _samplePost() {
  return FeedPost(
    id: 'p1',
    type: PostType.production,
    author: 'Hasan Usta',
    role: 'Fırıncı',
    text: 'Sabah 50 kg un yoğurdum.',
    createdAt: DateTime(2026, 5, 17, 8, 0),
    gradient: const <Color>[Color(0xFFF0E5C8), Color(0xFFD9B97A)],
  );
}

SocialGroup _sampleGroup() {
  return SocialGroup(
    id: 'g1',
    name: 'Konya Fırıncıları',
    description: 'Kardeş esnaf grubu.',
    category: GroupCategory.bakers,
    ownerName: 'Owner',
    ownerId: 'o1',
    currentMemberCount: 12,
    createdAt: DateTime(2026, 5, 1),
    visualSeed: 1,
  );
}

void main() {
  testWidgets(
    'P1.18 — toggleLike throws → Türkçe hata snackbar görünür',
    (tester) async {
      final repo = _ThrowingFeedRepo(throwOnLike: true);
      await tester.pumpWidget(
        _wrapFeed(repo, PostCardWired(post: _samplePost())),
      );

      // İlk render — like butonu (favorite_outline_rounded, isLiked=false).
      expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_outline_rounded));
      await tester.pumpAndSettle();

      expect(repo.toggleLikeCalls, 1);
      expect(
        find.text(AppStrings.feedLikeUpdateError),
        findsOneWidget,
        reason: 'toggleLike fırlattığında Türkçe hata gösterilmeli.',
      );
    },
  );

  testWidgets(
    'P1.19 — toggleSave throws → Türkçe hata snackbar görünür',
    (tester) async {
      final repo = _ThrowingFeedRepo(throwOnSave: true);
      await tester.pumpWidget(
        _wrapFeed(repo, PostCardWired(post: _samplePost())),
      );

      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pumpAndSettle();

      expect(repo.toggleSaveCalls, 1);
      expect(
        find.text(AppStrings.feedSaveUpdateError),
        findsOneWidget,
        reason: 'toggleSave fırlattığında Türkçe hata gösterilmeli.',
      );
    },
  );

  testWidgets(
    'P1.20 — leaveGroup throws → Türkçe hata snackbar; '
    'runGuardedMutation davranışı korunur',
    (tester) async {
      final repo = _ThrowingGroupRepo(throwOnLeave: true);
      await tester.pumpWidget(
        _wrapGroup(
          repo,
          PrimaryActionButton(group: _sampleGroup(), isJoined: true),
        ),
      );

      // isJoined=true → buton "Gruptan ayrıl" + logout ikonu.
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      expect(repo.leaveCalls, 1);
      expect(
        find.text(AppStrings.groupLeaveError),
        findsOneWidget,
        reason: 'leaveGroup fırlattığında Türkçe hata gösterilmeli.',
      );
      // Success snackbar görünmemeli.
      expect(find.text(AppStrings.groupDetailLeaveSnackSuccess), findsNothing);
    },
  );

  testWidgets(
    'P1.21 — postMessage throws → Türkçe hata snackbar, '
    'input metni korunur, buton tekrar basılabilir',
    (tester) async {
      final repo = _ThrowingGroupRepo(throwOnPost: true);
      await tester.pumpWidget(
        _wrapGroup(
          repo,
          GroupComposer(group: _sampleGroup(), isJoined: true),
        ),
      );

      const userText = 'Selam çocuklar — bu hafta tam buğdaya geçtim.';
      await tester.enterText(find.byType(TextField), userText);
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.postCalls, 1);
      expect(
        find.text(AppStrings.groupMessageSendError),
        findsOneWidget,
        reason: 'postMessage fırlattığında Türkçe hata gösterilmeli.',
      );

      // Kullanıcı metni input'ta korunmuş.
      expect(find.text(userText), findsOneWidget);

      // FilledButton tekrar basılabilir (no _saving state in _Composer).
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);

      // İkinci tap → repo ikinci çağrıyı görmeli.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repo.postCalls, 2);
    },
  );
}
