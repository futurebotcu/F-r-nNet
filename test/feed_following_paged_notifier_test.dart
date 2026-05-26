// Social UI Polish Sprint 2A — FeedFollowingPagedNotifier testleri.
//
// build(): follow yoksa empty state; follow varsa filtered post listesi.
// loadMore + refresh standart paged notifier davranışı.

import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/profile/providers/follow_providers.dart';
import 'package:firin_defter/features/profile/repositories/follow_repository.dart';
import 'package:firin_defter/features/profile/repositories/local_follow_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _meId = 'test_user';

void main() {
  group('FeedFollowingPagedNotifier — build', () {
    test('Follow yoksa empty state (posts boş, hasMore false)', () async {
      final feedRepo = LocalFeedRepository(seed: true);
      final followRepo = LocalFollowRepository(currentUserId: _meId);
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWith((_) => feedRepo),
          followRepositoryProvider.overrideWith((_) => followRepo),
          currentFollowingIdsProvider
              .overrideWith((_) async => const <String>{}),
        ],
      );
      addTearDown(container.dispose);

      final state =
          await container.read(feedFollowingPagedNotifierProvider.future);
      expect(state.posts, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test(
        'Follow var → filtered postlar gelir (seed_owner_1 follow + seed posts)',
        () async {
      final feedRepo = LocalFeedRepository(seed: true);
      final followRepo = LocalFollowRepository(currentUserId: _meId);
      await followRepo.followProfile('seed_owner_1');

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWith((_) => feedRepo),
          followRepositoryProvider.overrideWith((_) => followRepo),
          currentFollowingIdsProvider
              .overrideWith((_) async => <String>{'seed_owner_1'}),
        ],
      );
      addTearDown(container.dispose);

      final state =
          await container.read(feedFollowingPagedNotifierProvider.future);
      // seed_owner_1'in en az 1 post'u seed'de var.
      expect(state.posts, isNotEmpty);
      for (final p in state.posts) {
        expect(p.ownerId, 'seed_owner_1',
            reason: 'Sadece seed_owner_1 postları döner');
      }
    });

    test('Follow var ama o owner\'ın postu yok → empty', () async {
      final feedRepo = LocalFeedRepository(seed: true);
      final followRepo = LocalFollowRepository(currentUserId: _meId);

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWith((_) => feedRepo),
          followRepositoryProvider.overrideWith((_) => followRepo),
          currentFollowingIdsProvider
              .overrideWith((_) async => <String>{'unknown_owner_id'}),
        ],
      );
      addTearDown(container.dispose);

      final state =
          await container.read(feedFollowingPagedNotifierProvider.future);
      expect(state.posts, isEmpty);
    });
  });
}
