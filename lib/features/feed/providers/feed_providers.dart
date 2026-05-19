import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';
import '../repositories/feed_repository.dart';
import '../repositories/guarded_feed_repository.dart';
import '../repositories/local_feed_repository.dart';
import '../repositories/supabase_feed_repository.dart';

/// Sosyal Omurga V1 — Supabase aktif ve oturum varsa gerçek backend; aksi
/// halde LocalFeedRepository (guest gezme + Supabase devre dışı senaryosu).
///
/// Guest kullanıcı için davranış:
/// - Supabase aktif ama oturum yoksa → LocalFeedRepository (anon SELECT yok,
///   feed_posts RLS only authenticated). Guest demo seed üzerinden gezebilir.
/// - Auth açıldığı an provider invalidate olur ve gerçek feed gelir.
///
/// V1.3.3 — Tüm yazma metodları GuardedFeedRepository ile sarılır;
/// `canWriteCheckProvider` guest durumlarda `GuestActionRequiredException`
/// fırlatılmasını garantiler.
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final FeedRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseFeedRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalFeedRepository(seed: true);
  }
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

/// V1 P1-B — Bir post için yorumlar (eski tarih önce).
final feedCommentsProvider = FutureProvider.autoDispose
    .family<List<FeedComment>, String>((ref, postId) async {
  ref.watch(feedChangesProvider);
  final repo = ref.watch(feedRepositoryProvider);
  return repo.listComments(postId);
});

/// V1 Social S1 — Belirli kullanıcının post listesi (public profile için).
/// Newest first; feedChangesProvider tick ile invalidate olur.
final userPostsProvider = FutureProvider.autoDispose
    .family<List<FeedPost>, String>((ref, ownerId) async {
  ref.watch(feedChangesProvider);
  final repo = ref.watch(feedRepositoryProvider);
  return repo.listPostsByOwner(ownerId);
});

/// V1 P0 — Twitter-style yorum sayfası üstündeki post context header için
/// tek post lookup. V1: ana feed liste içinden first-where; küçük feed
/// performans uygun. Bulunamazsa null (yeni paylaşılmış post + cache miss
/// senaryosu için header sade fallback'e düşer). V2'de Supabase tarafına
/// dedicated `feed_post_by_id` RPC eklenebilir.
final feedPostByIdProvider = FutureProvider.autoDispose
    .family<FeedPost?, String>((ref, postId) async {
  ref.watch(feedChangesProvider);
  final repo = ref.watch(feedRepositoryProvider);
  final posts = await repo.listPosts();
  for (final p in posts) {
    if (p.id == postId) return p;
  }
  return null;
});
