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
  final user = ref.watch(currentAuthUserProvider);
  final WorkerRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
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

final myWorkerProfileProvider = FutureProvider<WorkerProfile?>((ref) async {
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
