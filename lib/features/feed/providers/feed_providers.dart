import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/can_write_check_provider.dart';
import '../models/feed_insight.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';
import '../repositories/feed_repository.dart';
import '../repositories/guarded_feed_repository.dart';
import '../repositories/local_feed_repository.dart';

/// V1.3.3 — Guarded wrapper ile sarılı feed repository.
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final FeedRepository inner = LocalFeedRepository(seed: true);
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedFeedRepository(inner: inner, canWriteCheck: canWrite);
});

/// Repository değişikliklerini dinleyen tick.
final feedChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.watch();
});

/// Ana feed postları (newest first), opsiyonel tip filtresi.
final feedPostsProvider = FutureProvider.autoDispose
    .family<List<FeedPost>, PostType?>((ref, type) async {
  ref.watch(feedChangesProvider);
  final repo = ref.watch(feedRepositoryProvider);
  return repo.listPosts(type: type);
});

/// Insight kartları.
final feedInsightsProvider =
    FutureProvider.autoDispose<List<FeedInsight>>((ref) async {
  ref.watch(feedChangesProvider);
  final repo = ref.watch(feedRepositoryProvider);
  return repo.listInsights();
});
