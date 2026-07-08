// FırınNet Akademi PR A2 — feed kartı bot rozeti + provider testleri.
//
// Bot tespiti public academy_bot_profiles setinden (profiles owner-only).
// Asıl güvenlik server-side (A1 RLS smoke PASS): bot postu yalnız service_role.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAcademyRepository implements AcademyRepository {
  _FakeAcademyRepository({this.ids = const {}, this.profiles = const {}});
  final Set<String> ids;
  final Map<String, AcademyBotProfile> profiles;
  @override
  Future<Set<String>> visibleBotIds() async => ids;
  @override
  Future<AcademyBotProfile?> botProfile(String userId) async =>
      profiles[userId];
}

const _profile = BakeryProfile(
  displayName: 'Hasan Kara',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'hasan@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

FeedPost _post({required String ownerId, String role = 'Usta Fırıncı'}) =>
    FeedPost(
      id: 'p1',
      ownerId: ownerId,
      type: PostType.announcement,
      author: 'FırınNet Akademi',
      role: role,
      text: 'Dünyadan fırıncılık içgörüsü.',
      createdAt: DateTime(2026, 1, 1),
      gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
    );

Widget _wrap(FeedPost post, AcademyRepository repo) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWith(
        (_) => LocalFeedRepository(seed: false),
      ),
      currentAuthUserProvider.overrideWith((_) => null),
      guestModeProvider.overrideWith(
        (_) => GuestModeNotifier()..setGuest(false),
      ),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _profile),
      ),
      academyRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SocialPostCard(post: post)),
      ),
    ),
  );
}

void main() {
  group('Feed kartı Akademi bot rozeti', () {
    testWidgets('bot postunda "AI destekli içerik hesabı" etiketi', (
      tester,
    ) async {
      final repo = _FakeAcademyRepository(ids: {'bot-1'});
      await tester.pumpWidget(_wrap(_post(ownerId: 'bot-1'), repo));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feed_academy_bot_badge')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.academyBotContentLabel), findsOneWidget);
      // Yanıltıcı rol rozeti gösterilmez.
      expect(find.text('Usta Fırıncı'), findsNothing);
    });

    testWidgets('normal kullanıcı postunda bot rozeti yok, rol var', (
      tester,
    ) async {
      final repo = _FakeAcademyRepository(ids: {'bot-1'});
      await tester.pumpWidget(_wrap(_post(ownerId: 'user-9'), repo));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('feed_academy_bot_badge')),
        findsNothing,
      );
      expect(find.text('Usta Fırıncı'), findsOneWidget);
    });
  });

  group('Academy providerlar', () {
    test('academyBotIdsProvider fake set döndürür', () async {
      final repo = _FakeAcademyRepository(ids: {'a', 'b'});
      final c = ProviderContainer(
        overrides: [academyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final ids = await c.read(academyBotIdsProvider.future);
      expect(ids, {'a', 'b'});
    });

    test('academyBotProfileProvider bot metadata / null döndürür', () async {
      const bot = AcademyBotProfile(
        profileId: 'bot-1',
        botKey: 'akademi',
        topic: AcademyTopic.akademi,
        bio: 'Sektör içgörüleri',
      );
      final repo = _FakeAcademyRepository(profiles: {'bot-1': bot});
      final c = ProviderContainer(
        overrides: [academyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final found = await c.read(academyBotProfileProvider('bot-1').future);
      expect(found?.botKey, 'akademi');
      expect(found?.topic, AcademyTopic.akademi);
      final none = await c.read(academyBotProfileProvider('user-9').future);
      expect(none, isNull);
    });
  });
}
