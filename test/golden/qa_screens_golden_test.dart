// Görsel QA — detay/form ekranları: ilan detayı, iş ilanı detayı, ilan
// formu, post detayı, Akademi. 390px normal + 320px @1.5x büyük yazı.
// Windows'ta üretilen baseline; CI 'golden' tag'ini hariç tutar.
@Tags(['golden'])
library;

import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/core/widgets/premium/job_opportunity_card.dart';
import 'package:firin_defter/features/academy/data/academy_repository.dart';
import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:firin_defter/features/academy/providers/academy_providers.dart';
import 'package:firin_defter/features/academy/screens/academy_page.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/jobs/screens/jobs_screen.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/providers/market_listing_providers.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/screens/market_listing_form_screen.dart';
import 'package:firin_defter/features/marketplace/screens/marketplace_detail_screen.dart';
import 'package:firin_defter/features/social/comments/comments_page.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
import 'package:firin_defter/features/social/repositories/local_social_comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _loadGoldenFont() async {
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  for (final family in ['Inter', 'Ahem', 'Roboto']) {
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(regular))
          ..addFont(Future<ByteData>.value(bold)))
        .load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future<ByteData>.value(icons))).load();
}

class _FixedMarketRepo extends LocalMarketListingRepository {
  _FixedMarketRepo(this.existing);
  final MarketListing existing;
  @override
  Future<MarketListing?> getListing(String id) async => existing;
}

class _SeedFeedRepo extends LocalFeedRepository {
  _SeedFeedRepo(this.seeded) : super(seed: false);
  final List<FeedPost> seeded;
  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) async => offset > 0
      ? const <FeedPost>[]
      : seeded.where((p) => followingIds.contains(p.ownerId)).toList();
}

final _now = DateTime.now();
const _bot = 'ab010000-0000-4000-8000-000000000001';

MarketListing _market() => MarketListing(
  id: 'm1',
  ownerId: 'owner-1',
  title: 'Merkezde devren satılık taş fırın, günlük 2.000 ekmek kapasiteli',
  category: 'devren_firin',
  listingType: 'bakery_transfer',
  city: 'Kahramanmaraş',
  district: 'Onikişubat',
  transferPrice: 4250000,
  rentPrice: 45000,
  negotiable: true,
  areaM2: 180,
  hasLicense: true,
  description:
      'Müşteri portföyü hazır, 2 taş fırın ve 1 döner fırın çalışır '
      'durumda. Kira sözleşmesi 5 yıl. Devir nedeni emeklilik.',
  authorName: 'Maraş Ekmek Fırını',
  contactPreference: 'phone',
  contactPhone: '05321234567',
  createdAt: _now.subtract(const Duration(hours: 3)),
);

FeedPost _post({String owner = 'u2', String author = 'Hasan Kara'}) => FeedPost(
  id: 'p-$owner',
  ownerId: owner,
  author: author,
  role: 'Usta Fırıncı · Konya',
  type: PostType.production,
  text:
      'Tam buğday simit denemeleri 90 dakika fermantasyonla çok daha '
      'güzel oturdu. Tahin akışkanlığı 70/30 dengeledim.',
  tags: const ['ekşimaya', 'simit'],
  createdAt: _now.subtract(const Duration(hours: 2)),
  gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
);

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        builder: (ctx, w) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: const Key('shot'), child: w!),
        ),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull, reason: name);
  await expectLater(
    find.byKey(const Key('shot')),
    matchesGoldenFile('goldens/qa_$name.png'),
  );
}

Widget _jobDetail() => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      child: JobListingDetailView(
        kind: JobListingKind.hiring,
        title: 'Gece vardiyası için hamur ustası aranıyor',
        keyFact: '₺ 35.000 – 42.000',
        location: 'İzmir · Bornova',
        ownerName: 'Ege Taş Fırın',
        rows: const [
          MapEntry('Vardiya', 'Gece'),
          MapEntry('Tecrübe', '3+ yıl'),
        ],
        description:
            'Taş fırında hamur hazırlama ve şekillendirme. Sigorta, yemek '
            've servis var.',
        createdAt: _now.subtract(const Duration(minutes: 40)),
        expiresAt: _now.add(const Duration(days: 20)),
        primaryLabel: 'Başvur',
        onPrimary: () {},
        phone: '05321234567',
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await _loadGoldenFont();
    await initializeDateFormatting('tr_TR');
  });

  final marketOverrides = <Override>[
    currentAuthUserProvider.overrideWith((_) => null),
    marketListingRepositoryProvider.overrideWith(
      (ref) => _FixedMarketRepo(_market()),
    ),
  ];

  testWidgets('ilan detayı', (tester) async {
    await _shot(
      tester,
      'market_detail',
      const MarketplaceDetailScreen(listingId: 'm1'),
      overrides: marketOverrides,
    );
  });

  testWidgets('ilan detayı 320 @1.5', (tester) async {
    await _shot(
      tester,
      'market_detail_320_x15',
      const MarketplaceDetailScreen(listingId: 'm1'),
      overrides: marketOverrides,
      size: const Size(320, 760),
      scale: 1.5,
    );
  });

  testWidgets('iş ilanı detayı', (tester) async {
    await _shot(tester, 'job_detail', _jobDetail());
  });

  testWidgets('iş ilanı detayı 320 @1.5', (tester) async {
    await _shot(
      tester,
      'job_detail_320_x15',
      _jobDetail(),
      size: const Size(320, 760),
      scale: 1.5,
    );
  });

  testWidgets('ilan formu', (tester) async {
    await _shot(
      tester,
      'market_form',
      const MarketListingFormScreen(),
      overrides: [currentAuthUserProvider.overrideWith((_) => null)],
    );
  });

  testWidgets('post detayı', (tester) async {
    await _shot(
      tester,
      'post_detail',
      SocialCommentsPage(postId: 'p-u2', initialPost: _post()),
      overrides: [
        currentAuthUserProvider.overrideWith((_) => null),
        socialCommentsRepositoryProvider.overrideWithValue(
          LocalSocialCommentsRepository(),
        ),
      ],
    );
  });

  testWidgets('Akademi', (tester) async {
    await _shot(
      tester,
      'academy',
      const AcademyPage(),
      overrides: [
        currentAuthUserProvider.overrideWith((_) => null),
        feedRepositoryProvider.overrideWith(
          (_) => _SeedFeedRepo([_post(owner: _bot, author: 'FırınNet Ekmek')]),
        ),
        academyRepositoryProvider.overrideWithValue(
          LocalAcademyRepository(
            bots: const [
              AcademyBotProfile(
                profileId: _bot,
                botKey: 'ekmek_fermantasyon',
                topic: AcademyTopic.ekmekFermantasyon,
                bio: 'Ekmek ve fermantasyon',
                isHumor: false,
                allowDm: false,
                displayOrder: 10,
              ),
            ],
          ),
        ),
      ],
    );
  });
}
