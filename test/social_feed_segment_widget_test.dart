// Social UI Polish Sprint 2A — feed segmentation widget testleri.
//
// Source-level + minimal davranış: SocialFeedPage'in feed segment chip
// row'unu içerdiği, segment provider'ı kullandığı, empty state widget'larının
// segment-aware olduğunu doğrular.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Social UI Polish Sprint 2A — source-level guardrails', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/feed/social_feed_page.dart')
          .readAsStringSync();
    });

    test('_FeedSegment widget tanımlı + feedSegmentProvider kullanır', () {
      expect(src.contains('class _FeedSegment'), isTrue);
      expect(src.contains('feedSegmentProvider'), isTrue);
      expect(src.contains('AppStrings.feedSegmentAll'), isTrue);
      expect(src.contains('AppStrings.feedSegmentFollowing'), isTrue);
    });

    test('_FollowingEmpty widget tanımlı + 3 alt-durum mesajları', () {
      expect(src.contains('class _FollowingEmpty'), isTrue);
      expect(src.contains('AppStrings.feedFollowingEmptyGuest'), isTrue);
      expect(src.contains('AppStrings.feedFollowingEmptyNoFollows'), isTrue);
      expect(src.contains('AppStrings.feedFollowingEmptyNoPosts'), isTrue);
      // "Tüm akışa dön" CTA ortak — 3 alt-durumda da kullanılır.
      expect(src.contains('AppStrings.feedFollowingBackToAll'), isTrue);
    });

    test('_FeedList segment parametresi alır', () {
      expect(src.contains('required this.segment'), isTrue);
      expect(src.contains('final int segment;'), isTrue);
    });

    test('build() segment\'e göre doğru paged notifier seçer', () {
      expect(src.contains('feedSegmentProvider'), isTrue);
      expect(src.contains('feedPagedNotifierProvider'), isTrue);
      expect(src.contains('feedFollowingPagedNotifierProvider'), isTrue);
    });

    test('Header sequence stories + segment + composer sıralı', () {
      // _headers() helper'ı _FeedSegment'i InlineComposerCard'ın üstüne
      // ekler. Sıra: stories carousel → _FeedSegment → InlineComposerCard.
      final headersStart = src.indexOf('static List<Widget> _headers()');
      expect(headersStart, isNonNegative);
      final headersEnd = src.indexOf('@override', headersStart);
      final headersBlock = src.substring(headersStart, headersEnd);
      final segmentIdx = headersBlock.indexOf('_FeedSegment()');
      final composerIdx = headersBlock.indexOf('InlineComposerCard()');
      expect(segmentIdx, isNonNegative);
      expect(composerIdx, isNonNegative);
      expect(segmentIdx, lessThan(composerIdx),
          reason: '_FeedSegment InlineComposerCard\'ın üstünde olmalı');
    });
  });

  group('AppStrings — Social UI Polish Sprint 2A tanımları', () {
    test('feedSegmentAll + feedSegmentFollowing', () {
      expect(AppStrings.feedSegmentAll, 'Genel Akış');
      expect(AppStrings.feedSegmentFollowing, 'Takip Edilenler');
    });

    test('feedFollowingEmpty* + feedFollowingBackToAll', () {
      expect(AppStrings.feedFollowingEmptyNoFollows, isNotEmpty);
      expect(AppStrings.feedFollowingEmptyNoFollowsHint, isNotEmpty);
      expect(AppStrings.feedFollowingEmptyNoPosts, isNotEmpty);
      expect(AppStrings.feedFollowingEmptyGuest, isNotEmpty);
      expect(AppStrings.feedFollowingBackToAll, 'Tüm akışa dön');
    });
  });
}
