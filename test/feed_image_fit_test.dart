import 'package:cached_network_image/cached_network_image.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_media.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:firin_defter/features/social/post/widgets/feed_post_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FeedPost _postWith({int? w, int? h, bool image = true}) {
  return FeedPost(
    id: 'p1',
    ownerId: 'owner',
    author: 'FırınNet Akademi',
    role: '',
    type: PostType.announcement,
    text: 'Hamur sıcaklığı üzerine kısa bir not.',
    tags: const [],
    createdAt: DateTime(2026, 10, 1, 10),
    gradient: const [Color(0xFFFFF3C4), Color(0xFFFFE082)],
    mediaList: [
      if (image)
        FeedMedia(
          id: 'm1',
          postId: 'p1',
          ownerId: 'owner',
          mediaType: 'image',
          storagePath: 'x/card.png',
          publicUrl: 'https://example.invalid/card.png',
          width: w,
          height: h,
          createdAt: DateTime(2026, 10, 1, 10),
        ),
    ],
  );
}

Widget _host(Widget child, {double width = 390}) {
  return ProviderScope(
    overrides: [
      currentAuthUserProvider.overrideWith((_) => null),
      feedRepositoryProvider.overrideWith(
        (_) => LocalFeedRepository(seed: false),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
}

double _boxRatio(WidgetTester tester) {
  final box = tester.getSize(find.byType(FeedPostImage).first);
  return box.width / box.height;
}

BoxFit? _fit(WidgetTester tester) =>
    tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).fit;

void main() {
  group('Academy feed image is not cropped', () {
    testWidgets('16:9 Akademi PNG kartı (1200x675) gerçek oranında, kırpmasız',
        (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _postWith(w: 1200, h: 675))));
      await tester.pump();
      expect(_boxRatio(tester), closeTo(1200 / 675, 0.01));
      expect(_fit(tester), BoxFit.contain);
    });

    testWidgets('4:3 yatay görsel kendi oranında', (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _postWith(w: 1600, h: 1200))));
      await tester.pump();
      expect(_boxRatio(tester), closeTo(4 / 3, 0.01));
      expect(_fit(tester), BoxFit.contain);
    });

    testWidgets('1:1 kare görsel kare kutuda', (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _postWith(w: 1080, h: 1080))));
      await tester.pump();
      expect(_boxRatio(tester), closeTo(1, 0.01));
      expect(_fit(tester), BoxFit.contain);
    });

    testWidgets('dikey görsel 4:5 tavanıyla sınırlanır, contain ile tamamı görünür',
        (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _postWith(w: 1080, h: 1920))));
      await tester.pump();
      expect(_boxRatio(tester), closeTo(4 / 5, 0.01));
      expect(_fit(tester), BoxFit.contain);
    });

    testWidgets('boyutu bilinmeyen görsel kırpılmaz (contain)', (tester) async {
      await tester.pumpWidget(_host(SocialPostCard(post: _postWith())));
      await tester.pump();
      expect(_fit(tester), BoxFit.contain);
    });

    testWidgets('görselsiz post görsel alanı olmadan render olur', (tester) async {
      await tester.pumpWidget(
          _host(SocialPostCard(post: _postWith(image: false))));
      await tester.pump();
      expect(find.byType(FeedPostImage), findsNothing);
      expect(find.text('Hamur sıcaklığı üzerine kısa bir not.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 390.0, 600.0]) {
      testWidgets('genişlik $width: 16:9 kartta overflow yok', (tester) async {
        await tester.pumpWidget(_host(
          SocialPostCard(post: _postWith(w: 1200, h: 675)),
          width: width,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_boxRatio(tester), closeTo(1200 / 675, 0.01));
      });
    }

    testWidgets('detay görünümü feed ile aynı kuralı kullanır', (tester) async {
      await tester.pumpWidget(_host(
        const FeedPostImage(
          imageUrl: 'https://example.invalid/card.png',
          width: 1200,
          height: 675,
        ),
      ));
      await tester.pump();
      expect(_boxRatio(tester), closeTo(1200 / 675, 0.01));
      expect(_fit(tester), BoxFit.contain);
    });
  });
}
