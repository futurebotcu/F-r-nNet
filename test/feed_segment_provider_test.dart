// Social UI Polish Sprint 2A — feedSegmentProvider state testleri.

import 'package:firin_defter/features/social/feed/feed_segment_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('feedSegmentProvider', () {
    test('Default değer 0 (Genel Akış)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(feedSegmentProvider), 0);
    });

    test('State 1 (Takip Edilenler) olarak set edilir', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(feedSegmentProvider.notifier).state = 1;
      expect(container.read(feedSegmentProvider), 1);
    });

    test('State 1 -> 0 reset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(feedSegmentProvider.notifier).state = 1;
      container.read(feedSegmentProvider.notifier).state = 0;
      expect(container.read(feedSegmentProvider), 0);
    });
  });
}
