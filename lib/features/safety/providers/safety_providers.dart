// FırınNet UGC Safety V1 — provider katmanı.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../repositories/guarded_safety_repository.dart';
import '../repositories/local_safety_repository.dart';
import '../repositories/safety_repository.dart';
import '../repositories/supabase_safety_repository.dart';

/// Supabase aktif + oturum varsa gerçek backend; aksi halde Local (guest).
///
/// Yalnız userId izlenir (select) — token refresh/app resume emisyonları
/// repo'yu ve blocked cache'i resetlemez (grup composer P0 dersi).
final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final SafetyRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseSafetyRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalSafetyRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedSafetyRepository(inner: inner, canWriteCheck: canWrite);
});

/// Block/unblock tick'i — blocked set tüketicileri tazelenir.
final safetyChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  return repo.watch();
});

/// Mevcut kullanıcının engellediği user id seti (DB kaynaklı).
///
/// Feed/yorum/grup filtreleri bunu izler. Guest'te boş set.
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(safetyChangesProvider);
  final repo = ref.watch(safetyRepositoryProvider);
  return repo.listBlockedUserIds();
});

/// Sync convenience — yüklenene/refresh sırasında ESKİ veriyi korur
/// (skipLoadingOnRefresh), hiç veri yoksa boş set. Build içinde watch edilir.
final blockedUserIdsSyncProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(blockedUserIdsProvider);
  return async.maybeWhen(
    data: (ids) => ids,
    orElse: () => const <String>{},
  );
});
