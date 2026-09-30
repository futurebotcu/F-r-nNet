import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/models/academy_recipe.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/academy/screens/academy_page.dart';
import 'package:firin_defter/features/academy/widgets/humor_prefs_tiles.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _botId = 'ab010000-0000-4000-8000-000000000001';
const _mizahId = 'ab010000-0000-4000-8000-000000000011';

AcademyBotProfile _bot({
  String id = _botId,
  String key = 'ekmek_fermantasyon',
  AcademyTopic topic = AcademyTopic.ekmekFermantasyon,
  bool humor = false,
}) {
  return AcademyBotProfile(
    profileId: id,
    botKey: key,
    topic: topic,
    bio: 'test bio',
    isHumor: humor,
    allowDm: humor,
    displayOrder: humor ? 110 : 10,
  );
}

FeedPost _post({String owner = _botId, String author = 'FırınNet Ekmek'}) {
  return FeedPost(
    id: 'p-$owner',
    ownerId: owner,
    author: author,
    role: '',
    type: PostType.announcement,
    text: 'Fermantasyon üzerine kaynaklı bilgi.',
    tags: const ['akademi'],
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
  );
}

/// Bot postlarını dışarıdan seed edilebilir kılan test reposu.
class _SeedFeedRepo extends LocalFeedRepository {
  _SeedFeedRepo(this.seeded) : super(seed: false);

  final List<FeedPost> seeded;

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async {
    final filtered = seeded
        .where((p) => followingIds.contains(p.ownerId))
        .toList(growable: false);
    if (offset >= filtered.length) return const <FeedPost>[];
    return filtered.sublist(
      offset,
      (offset + limit).clamp(0, filtered.length),
    );
  }
}

void main() {
  recipeTests();
  group('AcademyTopic V1 taksonomisi', () {
    test('yeni konu anahtarları round-trip + eski anahtarlar korunur', () {
      for (final t in AcademyTopic.values) {
        expect(AcademyTopicMeta.fromKey(t.persistKey), t, reason: t.name);
      }
      expect(AcademyTopic.ekmekFermantasyon.persistKey, 'ekmek_fermantasyon');
      expect(AcademyTopic.mizah.persistKey, 'mizah');
      expect(AcademyTopic.fuarSektor.persistKey, 'fuar_sektor');
      expect(AcademyTopic.values.length, 22);
    });

    test('fromRow yeni alanları parse eder; eski backend default güvenli', () {
      final b = AcademyBotProfile.fromRow(const {
        'profile_id': _mizahId,
        'bot_key': 'mizah',
        'topic': 'mizah',
        'subtopics': ['Fırındaki gündelik durumlar', 'Özgün mizah'],
        'is_humor': true,
        'allow_dm': true,
        'display_order': 110,
      });
      expect(b.isHumor, isTrue);
      expect(b.allowDm, isTrue);
      expect(b.subtopics.length, 2);
      final legacy = AcademyBotProfile.fromRow(const {
        'profile_id': 'x',
        'bot_key': 'akademi',
        'topic': 'akademi',
      });
      expect(legacy.isHumor, isFalse);
      expect(legacy.allowDm, isFalse);
    });
  });

  Widget host({
    required Widget child,
    required List<AcademyBotProfile> bots,
    LocalFeedRepository? feedRepo,
  }) {
    return ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWith((_) => null),
        feedRepositoryProvider.overrideWith(
          (_) => feedRepo ?? LocalFeedRepository(seed: false),
        ),
        academyRepositoryProvider.overrideWithValue(
          LocalAcademyRepository(bots: bots),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('Feed kartı bot rozeti', () {
    testWidgets('Akademi botu postunda "Akademi • AI" rozeti görünür', (
      tester,
    ) async {
      await tester.pumpWidget(host(
        bots: [_bot()],
        child: SingleChildScrollView(child: SocialPostCard(post: _post())),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.academyAiBadge), findsOneWidget);
    });

    testWidgets('Mizah botu postunda "Mizah • AI" rozeti görünür', (
      tester,
    ) async {
      await tester.pumpWidget(host(
        bots: [_bot(id: _mizahId, key: 'mizah',
            topic: AcademyTopic.mizah, humor: true)],
        child: SingleChildScrollView(
          child: SocialPostCard(
            post: _post(owner: _mizahId, author: 'FırınNet Mizah'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.academyHumorBadge), findsOneWidget);
      expect(find.text(AppStrings.academyAiBadge), findsNothing);
    });

    testWidgets('normal kullanıcı postunda bot rozeti YOK', (tester) async {
      await tester.pumpWidget(host(
        bots: [_bot()],
        child: SingleChildScrollView(
          child: SocialPostCard(
            post: _post(owner: 'human-user', author: 'Ahmet Usta'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.academyAiBadge), findsNothing);
      expect(find.text(AppStrings.academyHumorBadge), findsNothing);
    });
  });

  group('HumorPrefsTiles (Ayarlar anahtarları)', () {
    testWidgets('DM varsayılan KAPALI; anahtarlar repo tercihi yazar', (
      tester,
    ) async {
      final repo = LocalAcademyRepository(bots: [_bot()]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            academyRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HumorPrefsTiles()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Varsayılanlar: yorum açık, kendiliğinden DM KAPALI.
      final dmSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('humor_pref_dm')),
      );
      expect(dmSwitch.value, isFalse);
      final cSwitch = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('humor_pref_comments')),
      );
      expect(cSwitch.value, isTrue);

      // DM iznini aç → repoya yazılır; kapat → geri alınır.
      await tester.tap(find.byKey(const ValueKey('humor_pref_dm')));
      await tester.pumpAndSettle();
      expect(repo.prefs.allowDm, isTrue);
      expect(repo.prefsWrites, 1);
      await tester.tap(find.byKey(const ValueKey('humor_pref_dm')));
      await tester.pumpAndSettle();
      expect(repo.prefs.allowDm, isFalse);

      // Yorum iznini kapat.
      await tester.tap(find.byKey(const ValueKey('humor_pref_comments')));
      await tester.pumpAndSettle();
      expect(repo.prefs.allowComments, isFalse);
    });
  });

  group('AcademyPage', () {
    testWidgets('başlık + bio + konu filtreleri + boş durum', (tester) async {
      await tester.pumpWidget(host(
        bots: [
          _bot(),
          _bot(id: 'ab010000-0000-4000-8000-000000000002', key: 'un_tahil',
              topic: AcademyTopic.unTahil),
          _bot(id: _mizahId, key: 'mizah',
              topic: AcademyTopic.mizah, humor: true),
        ],
        child: const AcademyPage(),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.academyTitle), findsWidgets);
      expect(find.text(AppStrings.academyBio), findsOneWidget);
      expect(
        find.byKey(const ValueKey('academy_chip_Tümü')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('academy_chip_Ekmek ve Fermantasyon')),
        findsOneWidget,
      );
      // Mizah botu Akademi filtrelerinde YOK (kendi profili var).
      expect(
        find.byKey(const ValueKey('academy_chip_Mizah')),
        findsNothing,
      );
      // İçerik yok → boş durum.
      expect(find.byKey(const ValueKey('academy_empty')), findsOneWidget);
    });

    testWidgets('bot postları listelenir; konu filtresi tek bota daraltır', (
      tester,
    ) async {
      final repo = _SeedFeedRepo([
        _post(),
        _post(
          owner: 'ab010000-0000-4000-8000-000000000002',
          author: 'FırınNet Un',
        ),
      ]);
      await tester.pumpWidget(host(
        bots: [
          _bot(),
          _bot(id: 'ab010000-0000-4000-8000-000000000002', key: 'un_tahil',
              topic: AcademyTopic.unTahil),
        ],
        feedRepo: repo,
        child: const AcademyPage(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SocialPostCard), findsNWidgets(2));

      await tester.tap(
        find.byKey(const ValueKey('academy_chip_Un ve Tahıl')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SocialPostCard), findsOneWidget);
      expect(find.text('FırınNet Un'), findsOneWidget);
    });
  });
}

// ── Akademi Tarifleri şeridi ────────────────────────────────────────────
AcademyRecipe _recipe() => const AcademyRecipe(
      id: 'r1',
      title: 'Klasik Beyaz Ekmek',
      authorName: 'FırınNet Akademi',
      sourceKind: 'master',
      ingredients: [
        AcademyRecipeIngredient(name: 'Un', grams: 1000, pct: 100),
        AcademyRecipeIngredient(name: 'Su', grams: 620, pct: 62),
        AcademyRecipeIngredient(name: 'Tuz', grams: 20, pct: 2),
      ],
      ovenC: 230,
      minutes: 35,
      steps: '1) Yoğur. 2) Mayalandır. 3) Pişir.',
    );

void recipeTests() {
  group('Akademi Tarifleri', () {
    testWidgets('yayımlı tarif şeritte görünür, detayda gramaj+% birlikte', (
      tester,
    ) async {
      final repo = LocalAcademyRepository(bots: [_bot()])
        ..recipes = [_recipe()];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWith((_) => null),
          feedRepositoryProvider.overrideWith(
            (_) => LocalFeedRepository(seed: false),
          ),
          academyRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AcademyPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('academy_recipes_title')),
          findsOneWidget);
      expect(find.text('Klasik Beyaz Ekmek'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('academy_recipe_r1')));
      await tester.pumpAndSettle();
      expect(find.text('Un 1000 g (%100)'), findsOneWidget);
      expect(find.text('Su 620 g (%62)'), findsOneWidget);
      expect(find.textContaining('İşlem sırası'), findsOneWidget);
    });

    testWidgets('tarif yoksa bölüm hiç görünmez', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWith((_) => null),
          feedRepositoryProvider.overrideWith(
            (_) => LocalFeedRepository(seed: false),
          ),
          academyRepositoryProvider.overrideWithValue(
            LocalAcademyRepository(bots: [_bot()]),
          ),
        ],
        child: const MaterialApp(home: AcademyPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('academy_recipes_title')),
          findsNothing);
    });
  });
}
