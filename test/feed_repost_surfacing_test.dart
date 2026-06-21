// Repost surfacing — repost'lar akışta/profilde "X yeniden paylaştı" girişi
// olarak yüzeye çıkar. Migration YOK; client-side merge (mergeFeedEntriesPage).

import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LocalFeedRepository _repo() =>
    LocalFeedRepository(seed: false, currentUserId: 'me', currentUserName: 'Ben');

void main() {
  group('mergeFeedEntriesPage (saf)', () {
    test('feedSortAt desc sıralar + feedEntryKey ile dedupe + dilim', () {
      final base = FeedPost(
        id: 'a',
        ownerId: 'o',
        type: PostType.production,
        author: 'Y',
        role: 'r',
        text: 'a',
        createdAt: DateTime(2026, 1, 1),
        gradient: const [Color(0xFF111111), Color(0xFF222222)],
      );
      final older = base; // 2026-01-01
      final repostEntry = FeedPost.repostEntry(
        original: base,
        repostedByProfileId: 'f',
        repostedByName: 'Arkadaş',
        repostedAt: DateTime(2030, 1, 1), // en yeni
      );
      final merged = mergeFeedEntriesPage(
        postEntries: [older],
        repostEntries: [repostEntry],
        offset: 0,
        limit: 10,
      );
      expect(merged.length, 2);
      expect(merged.first.isRepostEntry, isTrue); // 2030 > 2026
      expect(merged.last.isRepostEntry, isFalse);
      // Farklı feedEntryKey → ikisi de kaldı (req 6).
      expect(merged.map((e) => e.feedEntryKey).toSet().length, 2);
    });
  });

  group('Ana feed (takip edilenlerin repost\'ları)', () {
    test('repostByOwnerIds dolu → repost girişi orijinalle birlikte görünür',
        () async {
      final repo = _repo();
      final p = await repo.addPost(
        type: PostType.production,
        author: 'X',
        role: 'r',
        text: 'POST ICERIK',
      );
      repo.seedRepost(
        postId: p.id,
        ownerId: 'friend',
        ownerName: 'Arkadaş',
        at: DateTime(2030),
      );

      final feed = await repo.listPostsPage(repostByOwnerIds: {'friend'});
      // Orijinal post + repost girişi ayrı ayrı.
      expect(feed.where((e) => !e.isRepostEntry && e.id == p.id).length, 1);
      final entry = feed.firstWhere((e) => e.isRepostEntry);
      expect(entry.id, p.id); // orijinal post içeriği
      expect(entry.text, 'POST ICERIK');
      expect(entry.repostedByName, 'Arkadaş');
      expect(entry.repostedByProfileId, 'friend');
      expect(entry.feedSortAt, DateTime(2030));
    });

    test('repostByOwnerIds boş → repost girişi YOK', () async {
      final repo = _repo();
      final p = await repo.addPost(
        type: PostType.production,
        author: 'X',
        role: 'r',
        text: 'POST',
      );
      repo.seedRepost(
        postId: p.id,
        ownerId: 'friend',
        ownerName: 'Arkadaş',
        at: DateTime(2030),
      );
      final feed = await repo.listPostsPage();
      expect(feed.any((e) => e.isRepostEntry), isFalse);
    });

    test('takip edilmeyenin repost\'u ana feed\'e GİRMEZ', () async {
      final repo = _repo();
      final p = await repo.addPost(
        type: PostType.production,
        author: 'X',
        role: 'r',
        text: 'POST',
      );
      repo.seedRepost(
        postId: p.id,
        ownerId: 'stranger',
        ownerName: 'Yabancı',
        at: DateTime(2030),
      );
      final feed = await repo.listPostsPage(repostByOwnerIds: {'friend'});
      expect(feed.any((e) => e.isRepostEntry), isFalse);
    });
  });

  group('Profil + toggle', () {
    test('toggleRepost → profilde "Ben yeniden paylaştı" girişi; toggle-off kalkar',
        () async {
      final repo = _repo();
      final p = await repo.addPost(
        type: PostType.production,
        author: 'X',
        role: 'r',
        text: 'POST',
      );
      await repo.toggleRepost(p.id); // me reposts

      var prof = await repo.listPostsByOwner('me');
      final entries = prof.where((e) => e.isRepostEntry).toList();
      expect(entries.length, 1);
      expect(entries.single.repostedByName, 'Ben');
      expect(entries.single.id, p.id);

      await repo.toggleRepost(p.id); // toggle off
      prof = await repo.listPostsByOwner('me');
      expect(prof.any((e) => e.isRepostEntry), isFalse);
    });
  });

  group('Attribution UI', () {
    testWidgets('repost girişi kartında "<Ad> yeniden paylaştı" görünür',
        (tester) async {
      final original = FeedPost(
        id: 'p1',
        ownerId: 'o',
        type: PostType.production,
        author: 'Hasan Kara',
        role: 'Usta',
        text: 'simit tarifi',
        createdAt: DateTime(2026, 1, 1),
        gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
      );
      final entry = FeedPost.repostEntry(
        original: original,
        repostedByProfileId: 'f',
        repostedByName: 'Fatih Kartal',
        repostedAt: DateTime(2026, 2, 1),
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          feedRepositoryProvider.overrideWith(
            (_) => LocalFeedRepository(seed: false),
          ),
          currentAuthUserProvider.overrideWith((_) => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SocialPostCard(post: entry)),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Fatih Kartal yeniden paylaştı'), findsOneWidget);
      // Kart orijinal post içeriğini gösterir.
      expect(find.text('simit tarifi'), findsOneWidget);
    });

    testWidgets('orijinal post kartında attribution satırı YOK', (tester) async {
      final post = FeedPost(
        id: 'p2',
        ownerId: 'o',
        type: PostType.production,
        author: 'Hasan Kara',
        role: 'Usta',
        text: 'ekmek',
        createdAt: DateTime(2026, 1, 1),
        gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
      );
      await tester.pumpWidget(ProviderScope(
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
      ));
      await tester.pump();
      expect(find.textContaining('yeniden paylaştı'), findsNothing);
    });
  });
}
