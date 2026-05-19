import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/follow_providers.dart';
import '../models/social_comment.dart';
import '../models/social_profile.dart';
import '../repositories/guarded_social_comments_repository.dart';
import '../repositories/local_social_comments_repository.dart';
import '../repositories/social_comments_repository.dart';
import '../repositories/supabase_social_comments_repository.dart';

/// FırınNet Social — provider katmanı.
///
/// Donor-first sosyal modül için Riverpod glue. Comments / future feed /
/// profile / follow / stories aynı dosyada toplu provider olarak verilir;
/// kazalardan kaçınmak için interface'ler net.

// ═══════════════════════════════════════════════════════════════════════
// Comments
// ═══════════════════════════════════════════════════════════════════════

final socialCommentsRepositoryProvider =
    Provider<SocialCommentsRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final SocialCommentsRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseSocialCommentsRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalSocialCommentsRepository(
      currentUserId: user?.id ?? 'me_misafir',
    );
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedSocialCommentsRepository(
    inner: inner,
    canWriteCheck: canWrite,
  );
});

/// Tick — comment repository değişikliklerinde fire eder.
final socialCommentsChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(socialCommentsRepositoryProvider);
  return repo.watch();
});

/// Bir post için yorumlar (eski tarih önce).
final socialCommentsProvider = FutureProvider.autoDispose
    .family<List<SocialComment>, String>((ref, postId) async {
  ref.watch(socialCommentsChangesProvider);
  final repo = ref.watch(socialCommentsRepositoryProvider);
  return repo.listComments(postId);
});

// ═══════════════════════════════════════════════════════════════════════
// Profile (F2)
// ═══════════════════════════════════════════════════════════════════════

/// Bir user id için public profile snapshot. RPC
/// `public_profile_snapshot(uuid[])` üzerinden — RLS-safe.
///
/// RPC null veya boş dönerse fallback `SocialProfile(id: userId)` döner
/// (UI'da `displayNameOrFallback` ile "FırınNet Kullanıcısı" gösterilir).
final socialProfileProvider = FutureProvider.autoDispose
    .family<SocialProfile, String>((ref, userId) async {
  if (!AppConfig.supabaseEnabled) {
    return SocialProfile(id: userId);
  }
  final client = sb.Supabase.instance.client;
  try {
    final rows = await client.rpc(
      'public_profile_snapshot',
      params: <String, dynamic>{
        'p_user_ids': <String>[userId],
      },
    );
    if (rows is! List || rows.isEmpty) {
      return SocialProfile(id: userId);
    }
    final row = (rows.first as Map).cast<String, dynamic>();
    return SocialProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String?,
      professionBadge: row['profession_badge'] as String?,
      city: row['city'] as String?,
    );
  } catch (_) {
    return SocialProfile(id: userId);
  }
});

/// Bir user id listesi için batch profile snapshot. Followers/Following
/// list page için: tek RPC ile çoklu profil çekilir.
final socialProfilesBatchProvider = FutureProvider.autoDispose
    .family<Map<String, SocialProfile>, List<String>>((ref, userIds) async {
  if (userIds.isEmpty || !AppConfig.supabaseEnabled) {
    return <String, SocialProfile>{
      for (final id in userIds) id: SocialProfile(id: id),
    };
  }
  final client = sb.Supabase.instance.client;
  try {
    final rows = await client.rpc(
      'public_profile_snapshot',
      params: <String, dynamic>{
        'p_user_ids': userIds,
      },
    );
    final map = <String, SocialProfile>{
      for (final id in userIds) id: SocialProfile(id: id),
    };
    if (rows is List) {
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final id = r['id'] as String;
        map[id] = SocialProfile(
          id: id,
          displayName: r['display_name'] as String?,
          professionBadge: r['profession_badge'] as String?,
          city: r['city'] as String?,
        );
      }
    }
    return map;
  } catch (_) {
    return <String, SocialProfile>{
      for (final id in userIds) id: SocialProfile(id: id),
    };
  }
});

/// Profile post count. Mevcut `userPostsProvider` zaten var; sayım için
/// onun length'ini kullanırız.
final socialProfilePostCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, userId) async {
  final posts = await ref.watch(userPostsProvider(userId).future);
  return posts.length;
});

/// Followers user id listesi (most recent first).
final socialFollowersIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, userId) async {
  ref.watch(followChangesProvider);
  final repo = ref.watch(followRepositoryProvider);
  return repo.listFollowerIds(userId);
});

/// Following user id listesi.
final socialFollowingIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, userId) async {
  ref.watch(followChangesProvider);
  final repo = ref.watch(followRepositoryProvider);
  return repo.listFollowingIds(userId);
});
