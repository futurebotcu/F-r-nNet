import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';
import '../repositories/guarded_worker_repository.dart';
import '../repositories/local_worker_repository.dart';
import '../repositories/supabase_worker_repository.dart';
import '../repositories/worker_repository.dart';

/// V1.3.3 — Guarded wrapper ile sarılı worker repository.
final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  // P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final WorkerRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseWorkerRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalWorkerRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedWorkerRepository(inner: inner, canWriteCheck: canWrite);
});

final workerChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(workerRepositoryProvider);
  return repo.watch();
});

/// V1.4 P1.1 — autoDispose: `getMyProfile()` currentUser'a bağlı; sign-out
/// sonrası workerRepositoryProvider değişir, autoDispose ile birlikte
/// listener kalmadığında önceki kullanıcının profil cache'i temizlenir.
final myWorkerProfileProvider =
    FutureProvider.autoDispose<WorkerProfile?>((ref) async {
  ref.watch(workerChangesProvider);
  return ref.watch(workerRepositoryProvider).getMyProfile();
});

final myWorkerExperiencesProvider =
    FutureProvider<List<WorkerExperience>>((ref) async {
  ref.watch(workerChangesProvider);
  return ref.watch(workerRepositoryProvider).listMyExperiences();
});

final myJobSeekPostsProvider = FutureProvider<List<JobSeekPost>>((ref) async {
  ref.watch(workerChangesProvider);
  return ref.watch(workerRepositoryProvider).listMyJobSeekPosts();
});

/// Sektörde aktif olan iş arayan ilanları (V1 JobsScreen tab içeriği).
final activeJobSeekPostsProvider =
    FutureProvider<List<JobSeekPost>>((ref) async {
  ref.watch(workerChangesProvider);
  return ref.watch(workerRepositoryProvider).listActiveJobSeekPosts();
});

/// Professional Profile Center Sprint 1 — belirli bir kullanıcının aktif
/// "iş arıyorum" ilanı (varsa). Profil vitrininde "İş Arıyor" kartı için.
///
/// Yeni fetch/repo metodu eklemeden `activeJobSeekPostsProvider` (RLS:
/// is_active=true authenticated read açık) üzerinden owner filtrelenir.
/// İlk (en yeni) aktif ilan döner; yoksa null.
final activeJobSeekOfProvider = FutureProvider.autoDispose
    .family<JobSeekPost?, String>((ref, ownerId) async {
  final all = await ref.watch(activeJobSeekPostsProvider.future);
  for (final p in all) {
    if (p.ownerId == ownerId) return p;
  }
  return null;
});
