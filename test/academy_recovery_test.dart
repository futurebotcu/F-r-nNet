// Final audit P1 — Akademi:
//  * ilk yükleme hatası kalıcı boş-durum üretmez: hata → Tekrar dene →
//    provider yeniden istenir → içerik gelir,
//  * loadMore hatası sessiz kaybolmaz (satır içi Tekrar dene),
//  * hızlı filtre değişiminde eski yanıt state'i ezmez,
//  * Akademi botu profilinin ekran başlığı bot adı değil "FırınNet Akademi".

import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/models/academy_recipe.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/academy/screens/academy_page.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _botA = 'ab010000-0000-4000-8000-000000000001';
const _botB = 'ab010000-0000-4000-8000-000000000002';

AcademyBotProfile _bot(String id, AcademyTopic topic, {bool humor = false}) =>
    AcademyBotProfile(
      profileId: id,
      botKey: topic.persistKey,
      topic: topic,
      bio: 'bio',
      isHumor: humor,
      allowDm: humor,
      displayOrder: 10,
    );

final _bots = [
  _bot(_botA, AcademyTopic.ekmekFermantasyon),
  _bot(_botB, AcademyTopic.hijyen),
];

FeedPost _post(String owner, int i) => FeedPost(
  id: 'p-$owner-$i',
  ownerId: owner,
  author: 'Bot',
  role: '',
  type: PostType.announcement,
  text: 'İçerik $owner #$i',
  tags: const ['akademi'],
  createdAt: DateTime.now().subtract(Duration(minutes: 5 + i)),
  gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
);

/// visibleBots / tarifler ilk çağrıda hata, sonra başarı.
class _FlakyAcademyRepo extends LocalAcademyRepository {
  _FlakyAcademyRepo() : super(bots: _bots);
  int botCalls = 0;
  int recipeCalls = 0;

  @override
  Future<List<AcademyBotProfile>> visibleBots() async {
    botCalls++;
    if (botCalls == 1) throw Exception('offline');
    return super.visibleBots();
  }

  @override
  Future<List<AcademyRecipe>> listPublishedRecipes() async {
    recipeCalls++;
    if (recipeCalls == 1) throw Exception('offline');
    return const <AcademyRecipe>[];
  }
}

/// Bot postları; [failOffsets]'teki sayfa bir kez hata verir; [gates] verilen
/// botun yanıtını dışarıdan geciktirir.
class _FeedRepo extends LocalFeedRepository {
  _FeedRepo(this.posts) : super(seed: false);
  final List<FeedPost> posts;
  final Set<int> failOffsets = <int>{};
  final Map<String, Completer<void>> gates = {};

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async {
    for (final id in followingIds) {
      final g = gates[id];
      if (g != null) await g.future;
    }
    if (failOffsets.remove(offset)) throw Exception('timeout');
    final f = posts.where((p) => followingIds.contains(p.ownerId)).toList();
    if (offset >= f.length) return const <FeedPost>[];
    return f.sublist(offset, (offset + limit).clamp(0, f.length));
  }
}

Widget _host(
  AcademyRepository academy,
  LocalFeedRepository feed,
  Widget child,
) => ProviderScope(
  overrides: [
    currentAuthUserProvider.overrideWith((_) => null),
    feedRepositoryProvider.overrideWith((_) => feed),
    academyRepositoryProvider.overrideWithValue(academy),
  ],
  child: MaterialApp(home: child),
);

ProviderContainer _container(LocalFeedRepository feed) {
  final c = ProviderContainer(
    overrides: [
      currentAuthUserProvider.overrideWith((_) => null),
      feedRepositoryProvider.overrideWith((_) => feed),
      academyRepositoryProvider.overrideWithValue(
        LocalAcademyRepository(bots: _bots),
      ),
    ],
  );
  c.listen(academyBotsProvider, (_, __) {});
  c.listen(academyFeedProvider, (_, __) {});
  return c;
}

void main() {
  testWidgets('ilk yükleme hatası → Tekrar dene → içerik (kalıcı boş yok)', (
    tester,
  ) async {
    final academy = _FlakyAcademyRepo();
    final feed = _FeedRepo([_post(_botA, 0)]);
    await tester.pumpWidget(_host(academy, feed, const AcademyPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('academy_retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('academy_empty')), findsNothing);
    expect(find.byKey(const ValueKey('academy_recipes_retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('academy_retry')));
    await tester.pumpAndSettle();
    expect(academy.botCalls, 2, reason: 'retry bot listesini yeniden ister');
    expect(academy.recipeCalls, 2, reason: 'retry tarifleri de tazeler');
    expect(find.byKey(const ValueKey('academy_retry')), findsNothing);
    expect(find.textContaining('İçerik $_botA #0'), findsOneWidget);
  });

  test(
    'loadMore hatası görünür kalır; otomatik değil retry ile yeniden dener',
    () async {
      final feed = _FeedRepo([for (var i = 0; i < 25; i++) _post(_botA, i)]);
      final container = _container(feed);
      addTearDown(container.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final n = container.read(academyFeedProvider.notifier);
      expect(container.read(academyFeedProvider).posts.length, 20);

      feed.failOffsets.add(20);
      await n.loadMore();
      var s = container.read(academyFeedProvider);
      expect(s.error, isTrue);
      expect(s.posts.length, 20, reason: 'mevcut sayfa kaybolmaz');

      await n.loadMore(); // kaydırma: hata sonrası otomatik tekrar YOK
      expect(container.read(academyFeedProvider).error, isTrue);

      await n.loadMore(retry: true);
      s = container.read(academyFeedProvider);
      expect(s.error, isFalse);
      expect(s.posts.length, 25);
    },
  );

  test('hızlı filtre değişimi: eski yanıt yeni filtreyi ezmez', () async {
    final feed = _FeedRepo([_post(_botA, 0), _post(_botB, 0)]);
    final container = _container(feed);
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final n = container.read(academyFeedProvider.notifier);

    final gateA = Completer<void>();
    feed.gates[_botA] = gateA;
    final slow = n.refresh(filterBotId: _botA); // yavaş yanıt
    final fast = n.refresh(filterBotId: _botB); // kullanıcı hemen değiştirdi
    await fast;
    gateA.complete();
    await slow;
    final s = container.read(academyFeedProvider);
    expect(s.filterBotId, _botB);
    expect(s.posts.map((p) => p.ownerId).toSet(), {_botB});
  });

  testWidgets(
    'Akademi botu profil başlığı = FırınNet Akademi (bot adı değil)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          LocalAcademyRepository(bots: _bots),
          _FeedRepo(const []),
          const SocialProfilePage(userId: _botB),
        ),
      );
      await tester.pumpAndSettle();
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect((appBar.title! as Text).data, AppStrings.academyTitle);
    },
  );

  testWidgets('Mizah botu başlığı Akademi\'ye çevrilmez', (tester) async {
    await tester.pumpWidget(
      _host(
        LocalAcademyRepository(
          bots: [_bot(_botA, AcademyTopic.mizah, humor: true)],
        ),
        _FeedRepo(const []),
        const SocialProfilePage(userId: _botA),
      ),
    );
    await tester.pumpAndSettle();
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect((appBar.title! as Text).data, isNot(AppStrings.academyTitle));
  });
}
