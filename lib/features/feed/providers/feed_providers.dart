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

/// V2 Social Core — donor `posts_repository.getPage(offset, limit)` muadili
/// paged feed state. AsyncNotifier ile: ilk yükleme 20 post, scroll altta
/// loadMore +20, pull-to-refresh sıfırla. `hasMore` son sayfada false döner.
///
/// State akışı:
///   * `build()` → `listPostsPage(offset:0, limit:20)`.
///   * `loadMore()` → mevcut posts + yeni sayfa (limit kadar gelmezse
///     hasMore=false).
///   * `refresh()` → state sıfırla, ilk sayfayı tekrar çek (pull-to-refresh).
///
/// `feedChangesProvider` tick (post add/delete/like/save) sonrası UI
/// invalidate; sayfaları sıfırdan yükler. Donor BLoC `FeedPageRequested`
/// event'inin Riverpod transpozesi.
class FeedPagedState {
  const FeedPagedState({
    required this.posts,
    required this.isLoadingMore,
    required this.hasMore,
    required this.error,
  });

  final List<FeedPost> posts;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  FeedPagedState copyWith({
    List<FeedPost>? posts,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
  }) =>
      FeedPagedState(
        posts: posts ?? this.posts,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class FeedPagedNotifier extends AsyncNotifier<FeedPagedState> {
  static const int _pageSize = 20;

  @override
  Future<FeedPagedState> build() async {
    // feedChangesProvider tick → provider invalidate → ilk sayfayı tekrar
    // çek. Donor `FeedRefreshRequested` benzeri davranış.
    ref.watch(feedChangesProvider);
    final repo = ref.watch(feedRepositoryProvider);
    final first = await repo.listPostsPage(offset: 0, limit: _pageSize);
    return FeedPagedState(
      posts: first,
      isLoadingMore: false,
      hasMore: first.length == _pageSize,
      error: null,
    );
  }

  /// Sonraki sayfayı çek. Mevcut state üzerine append'ler.
  /// `isLoadingMore=true` sırasında tekrar çağrı no-op.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(feedRepositoryProvider);
      final next = await repo.listPostsPage(
        offset: current.posts.length,
        limit: _pageSize,
      );
      state = AsyncData(
        FeedPagedState(
          posts: <FeedPost>[...current.posts, ...next],
          isLoadingMore: false,
          hasMore: next.length == _pageSize,
          error: null,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, error: e),
      );
    }
  }

  /// Pull-to-refresh — state sıfırla ve ilk sayfayı tekrar çek.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(feedRepositoryProvider);
      final first = await repo.listPostsPage(offset: 0, limit: _pageSize);
      return FeedPagedState(
        posts: first,
        isLoadingMore: false,
        hasMore: first.length == _pageSize,
        error: null,
      );
    });
  }
}

final feedPagedNotifierProvider =
    AsyncNotifierProvider<FeedPagedNotifier, FeedPagedState>(
  FeedPagedNotifier.new,
);

/// M4 Polish — profile-scoped paged posts.
///
/// `userPostsProvider` (100-cap, tek shot) profilde çok-postlu kullanıcılarda
/// ilk açılışı şişirir. Bu notifier `listPostsByOwnerPage(offset, limit)`
/// üzerinden lazy yükler; UI altta "Daha fazla göster" CTA'sı ile sayfa
/// ister. Family by ownerId.
class UserPostsPagedNotifier
    extends FamilyAsyncNotifier<FeedPagedState, String> {
  static const int _pageSize = 20;

  @override
  Future<FeedPagedState> build(String ownerId) async {
    ref.watch(feedChangesProvider);
    final repo = ref.watch(feedRepositoryProvider);
    final first = await repo.listPostsByOwnerPage(
      ownerId: ownerId,
      offset: 0,
      limit: _pageSize,
    );
    return FeedPagedState(
      posts: first,
      isLoadingMore: false,
      hasMore: first.length == _pageSize,
      error: null,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(feedRepositoryProvider);
      final next = await repo.listPostsByOwnerPage(
        ownerId: arg,
        offset: current.posts.length,
        limit: _pageSize,
      );
      // Dedupe defansif — id çakışması append'lenmesin.
      final existingIds = <String>{for (final p in current.posts) p.id};
      final filtered = <FeedPost>[
        for (final p in next)
          if (!existingIds.contains(p.id)) p,
      ];
      state = AsyncData(
        FeedPagedState(
          posts: <FeedPost>[...current.posts, ...filtered],
          isLoadingMore: false,
          hasMore: next.length == _pageSize,
          error: null,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, error: e),
      );
    }
  }
}

final userPostsPagedNotifierProvider = AsyncNotifierProvider.family<
    UserPostsPagedNotifier, FeedPagedState, String>(
  UserPostsPagedNotifier.new,
);

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
