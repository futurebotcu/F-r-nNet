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
    testWidgets('0 beğeni + 0 yorum → sayı gösterilmez (yazısız ikonlar)',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 0, commentCount: 0)));
      await tester.pump();
      // Yazısız ikon satırı: buton etiketi YOK, ikonlar var.
      expect(find.text(AppStrings.feedActionLike), findsNothing);
      expect(find.text(AppStrings.feedActionComment), findsNothing);
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
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

  group('Yazısız ikon satırı + overflow', () {
    testWidgets('Buton metni yok; 5 ikon (beğeni/yorum/repost/kaydet/paylaş)',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      // Yazılı etiket yok.
      expect(find.text(AppStrings.feedActionLike), findsNothing);
      expect(find.text(AppStrings.feedActionComment), findsNothing);
      expect(find.text(AppStrings.feedActionSave), findsNothing);
      expect(find.text(AppStrings.feedActionShare), findsNothing);
      expect(find.text(AppStrings.feedActionRepost), findsNothing);
      // İkonlar var (repost dahil).
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
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
