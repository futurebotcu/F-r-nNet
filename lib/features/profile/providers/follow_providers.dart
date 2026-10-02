import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../repositories/follow_repository.dart';
import '../repositories/guarded_follow_repository.dart';
import '../repositories/local_follow_repository.dart';
import '../repositories/supabase_follow_repository.dart';

/// V1 Social S2 — Follow repository provider.
///
/// Supabase aktif + oturum varsa [SupabaseFollowRepository], aksi halde
/// [LocalFollowRepository]. Yazma metodları [GuardedFollowRepository] ile
/// guest guard'lı.
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  // Yalnız uid izlenir: token refresh / app resume yeni AuthUser örneği
  // üretir; tüm nesne izlenirse repo yeniden kurulur → feed page 1'e düşer.
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final FollowRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseFollowRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalFollowRepository(currentUserId: userId ?? 'me_misafir');
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedFollowRepository(inner: inner, canWriteCheck: canWrite);
});

/// Follow repository tick — mutation sonrası UI invalidation için.
final followChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(followRepositoryProvider);
  return repo.watch();
});

/// V1 Social S2 — Şu anki kullanıcı `userId`'yi takip ediyor mu?
///
/// Self-id geçilirse her zaman false döner (kendini takip yok).
final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  userId,
) async {
  ref.watch(followChangesProvider);
  final repo = ref.watch(followRepositoryProvider);
  return repo.isFollowing(userId);
});

/// V1 Social S2 — `(followers, following)` count tuple.
final followCountsProvider = FutureProvider.autoDispose
    .family<({int followers, int following}), String>((ref, userId) async {
      ref.watch(followChangesProvider);
      final repo = ref.watch(followRepositoryProvider);
      return repo.getFollowCounts(userId);
    });
