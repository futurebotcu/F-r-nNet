// Feed Premium Sprint — Post etkileşim özeti satırı widget testleri.
//
// Sayılar action row'dan çıkıp ince/şık bir özet satırına taşındı:
//   Sol: 👍 N beğeni · Sağ: N yorum · Tüm yorumları gör ›
// Kurallar: 0 değerler gizlenir, hiç etkileşim yoksa satır tamamen gizli,
// kibar Türkçe format (B / Mn). Action row sade kalır (sayı yok).

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
  group('Post etkileşim özeti — görünürlük', () {
    testWidgets('0 beğeni + 0 yorum → özet satırı gizli', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 0, commentCount: 0)));
      await tester.pump();
      expect(find.textContaining(AppStrings.postLikesShortLabel), findsNothing);
      expect(find.textContaining(AppStrings.postViewAllComments), findsNothing);
    });

    testWidgets('Sadece beğeni → "142 beğeni" görünür, yorum linki yok',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 0)));
      await tester.pump();
      expect(find.text('142 ${AppStrings.postLikesShortLabel}'),
          findsOneWidget);
      expect(find.textContaining(AppStrings.postViewAllComments), findsNothing);
    });

    testWidgets('Sadece yorum → "Tüm yorumları gör" görünür, beğeni yok',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 0, commentCount: 23)));
      await tester.pump();
      expect(find.textContaining(AppStrings.postViewAllComments), findsOneWidget);
      expect(find.textContaining(AppStrings.postLikesShortLabel), findsNothing);
    });

    testWidgets('Beğeni + yorum birlikte görünür', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      expect(find.text('142 ${AppStrings.postLikesShortLabel}'),
          findsOneWidget);
      expect(find.textContaining(AppStrings.postViewAllComments), findsOneWidget);
    });
  });

  group('Post etkileşim özeti — kibar Türkçe sayı formatı', () {
    testWidgets('1234 beğeni → "1,2 B beğeni"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 1234)));
      await tester.pump();
      expect(find.text('1,2 B ${AppStrings.postLikesShortLabel}'),
          findsOneWidget);
    });

    testWidgets('12400 beğeni → "12,4 B beğeni"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 12400)));
      await tester.pump();
      expect(find.text('12,4 B ${AppStrings.postLikesShortLabel}'),
          findsOneWidget);
    });

    testWidgets('1100000 beğeni → "1,1 Mn beğeni"', (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 1100000)));
      await tester.pump();
      expect(find.text('1,1 Mn ${AppStrings.postLikesShortLabel}'),
          findsOneWidget);
    });
  });

  group('Action row sade kalır (sayı yok)', () {
    testWidgets('Beğen/Yorum/Kaydet/Paylaş label var, sayı bitişik değil',
        (tester) async {
      await tester.pumpWidget(_wrap(_post(likeCount: 142, commentCount: 23)));
      await tester.pump();
      expect(find.text(AppStrings.feedActionLike), findsOneWidget);
      expect(find.text(AppStrings.feedActionComment), findsOneWidget);
      expect(find.text(AppStrings.feedActionSave), findsOneWidget);
      expect(find.text(AppStrings.feedActionShare), findsOneWidget);
      // Eski "Beğen · 142" bitişik formatı kalmadı.
      expect(find.textContaining('${AppStrings.feedActionLike} · '),
          findsNothing);
    });

    testWidgets('Hiç overflow yok (dar genişlik)', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(_post(likeCount: 12400, commentCount: 999)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
