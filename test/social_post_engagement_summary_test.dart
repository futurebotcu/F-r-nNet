// PR #1 (Feed) — Action-row beğeni/yorum sayıları widget testleri.
//
// Sayılar action row'da ikon+etiketin yanında gösterilir (kibar Türkçe
// format: 142 / 1,2 B / 1,1 Mn). 0 sayılar gizli. Ayrı "etkileşim özeti"
// satırı kaldırıldı (çift gösterim yok). Kaydet/Paylaş sayaç göstermez.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FeedPost _post({int likeCount = 0, int commentCount = 0}) => FeedPost(
      id: 'p1',
      ownerId: 'owner-1',
      type: PostType.production,
      author: 'Hasan Kara',
      role: 'Usta Fırıncı · Konya',
      text: 'Tam buğday simit denemeleri.',
      createdAt: DateTime(2026, 1, 1),
      gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
      likeCount: likeCount,
      commentCount: commentCount,
    );

Widget _wrap(FeedPost post) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWith(
        (_) => LocalFeedRepository(seed: false),
      ),
      currentAuthUserProvider.overrideWith((_) => null),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SocialPostCard(post: post)),
      ),
    ),
  );
}

void main() {
  group('Action row sayıları — görünürlük', () {
    testWidgets('0 beğeni + 0 yorum → sayı gösterilmez (label kalır)',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 0, commentCount: 0)));
      await tester.pump();
      expect(find.text(AppStrings.feedActionLike), findsOneWidget);
      expect(find.text(AppStrings.feedActionComment), findsOneWidget);
      // 0 sayaç gizli.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('Sadece beğeni → "142" görünür', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 0)));
      await tester.pump();
      expect(find.text('142'), findsOneWidget);
    });

    testWidgets('Beğeni + yorum → her iki sayı görünür', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      expect(find.text('142'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
    });

    testWidgets('Eski etkileşim özeti satırı kaldırıldı', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      expect(find.textContaining(AppStrings.postLikesShortLabel), findsNothing);
      expect(
          find.textContaining(AppStrings.postViewAllComments), findsNothing);
    });
  });

  group('Kibar Türkçe sayı formatı (action row)', () {
    testWidgets('1234 → "1,2 B"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 1234)));
      await tester.pump();
      expect(find.text('1,2 B'), findsOneWidget);
    });

    testWidgets('12400 → "12,4 B"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 12400)));
      await tester.pump();
      expect(find.text('12,4 B'), findsOneWidget);
    });

    testWidgets('1100000 → "1,1 Mn"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 1100000)));
      await tester.pump();
      expect(find.text('1,1 Mn'), findsOneWidget);
    });
  });

  group('Action row label + overflow', () {
    testWidgets('Beğen/Yorum/Kaydet/Paylaş label var', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      expect(find.text(AppStrings.feedActionLike), findsOneWidget);
      expect(find.text(AppStrings.feedActionComment), findsOneWidget);
      expect(find.text(AppStrings.feedActionSave), findsOneWidget);
      expect(find.text(AppStrings.feedActionShare), findsOneWidget);
    });

    testWidgets('Dar genişlikte overflow yok', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(_post(likeCount: 12400, commentCount: 999)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
