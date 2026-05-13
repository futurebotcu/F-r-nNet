import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';
import '../repositories/local_worker_repository.dart';
import '../repositories/supabase_worker_repository.dart';
import '../repositories/worker_repository.dart';

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseWorkerRepository(sb.Supabase.instance.client);
  }
  return LocalWorkerRepository();
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
