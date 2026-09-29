import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../feed/models/feed_post.dart';
import '../../feed/providers/feed_providers.dart';
import '../data/academy_repository.dart';
import '../data/supabase_academy_repository.dart';
import '../models/academy_bot_profile.dart';

/// Akademi okuma repository'si — Supabase açıksa canlı, değilse boş.
final academyRepositoryProvider = Provider<AcademyRepository>((ref) {
  if (!AppConfig.supabaseEnabled) return const EmptyAcademyRepository();
  return SupabaseAcademyRepository(sb.Supabase.instance.client);
});

/// Görünür botlar (display_order sıralı). Hata → boş liste (feed bozulmaz).
final academyBotsProvider =
    FutureProvider.autoDispose<List<AcademyBotProfile>>((ref) async {
  try {
    return await ref.watch(academyRepositoryProvider).visibleBots();
  } catch (_) {
    return const <AcademyBotProfile>[];
  }
});

/// profileId → bot map'i (feed kartı rozet/yönlendirme; ≤11 satır, cache).
final academyBotsByIdProvider =
    FutureProvider.autoDispose<Map<String, AcademyBotProfile>>((ref) async {
  final bots = await ref.watch(academyBotsProvider.future);
  return {for (final b in bots) b.profileId: b};
});

/// Kullanıcının mizah etkileşim tercihleri (Ayarlar anahtarları).
final humorPrefsProvider = FutureProvider.autoDispose<HumorPrefs>((ref) {
  return ref.watch(academyRepositoryProvider).humorPrefs();
});

/// Belirli bir profilin bot metadata'sı (profil sayfası davranışı).
final academyBotProfileProvider = FutureProvider.family
    .autoDispose<AcademyBotProfile?, String>((ref, userId) async {
  try {
    return await ref.watch(academyRepositoryProvider).botProfile(userId);
  } catch (_) {
    return null;
  }
});

/// Akademi sayfası post listesi durumu (offset sayfalama, konu filtresi).
class AcademyFeedState {
  const AcademyFeedState({
    this.posts = const <FeedPost>[],
    this.loading = false,
    this.error = false,
    this.endReached = false,
    this.filterBotId,
  });

  final List<FeedPost> posts;
  final bool loading;
  final bool error;
  final bool endReached;

  /// null = tüm Akademi botları; dolu = tek botun içerikleri.
  final String? filterBotId;

  AcademyFeedState copyWith({
    List<FeedPost>? posts,
    bool? loading,
    bool? error,
    bool? endReached,
    String? filterBotId,
    bool clearFilter = false,
  }) {
    return AcademyFeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      endReached: endReached ?? this.endReached,
      filterBotId: clearFilter ? null : (filterBotId ?? this.filterBotId),
    );
  }
}

/// Akademi içerik sayfalayıcısı: feed_posts owner_id IN (bot idleri) —
/// mevcut `listPostsPageForFollowing` sorgu deseni yeniden kullanılır.
class AcademyFeedNotifier extends StateNotifier<AcademyFeedState> {
  AcademyFeedNotifier(this._ref) : super(const AcademyFeedState());

  static const int pageSize = 20;
  final Ref _ref;

  Future<void> refresh({String? filterBotId, bool clearFilter = false}) async {
    state = AcademyFeedState(
      loading: true,
      filterBotId: clearFilter ? null : (filterBotId ?? state.filterBotId),
    );
    await _load(offset: 0);
  }

  Future<void> loadMore() async {
    if (state.loading || state.endReached) return;
    state = state.copyWith(loading: true, error: false);
    await _load(offset: state.posts.length);
  }

  Future<void> _load({required int offset}) async {
    try {
      final bots = await _ref.read(academyBotsProvider.future);
      final academyIds = {
        for (final b in bots)
          if (!b.isHumor) b.profileId,
      };
      final ids = state.filterBotId != null
          ? {state.filterBotId!}
          : academyIds;
      if (ids.isEmpty) {
        state = state.copyWith(
          posts: offset == 0 ? const <FeedPost>[] : null,
          loading: false,
          endReached: true,
        );
        return;
      }
      final page = await _ref.read(feedRepositoryProvider)
          .listPostsPageForFollowing(
            followingIds: ids,
            offset: offset,
            limit: pageSize,
          );
      state = state.copyWith(
        posts: offset == 0 ? page : [...state.posts, ...page],
        loading: false,
        error: false,
        endReached: page.length < pageSize,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true);
    }
  }
}

final academyFeedProvider = StateNotifierProvider.autoDispose<
    AcademyFeedNotifier, AcademyFeedState>((ref) {
  final n = AcademyFeedNotifier(ref);
  n.refresh();
  return n;
});
