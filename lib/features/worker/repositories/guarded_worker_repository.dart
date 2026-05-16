import '../../auth/services/auth_required_guard.dart';
import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';
import 'worker_repository.dart';

/// V1.3.3 — guest write korumalı [WorkerRepository] dekoratörü.
class GuardedWorkerRepository implements WorkerRepository {
  GuardedWorkerRepository({required this.inner, required this.canWriteCheck});

  final WorkerRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<WorkerProfile?> getMyProfile() => inner.getMyProfile();

  @override
  Future<List<WorkerExperience>> listMyExperiences() =>
      inner.listMyExperiences();

  @override
  Future<List<JobSeekPost>> listMyJobSeekPosts() => inner.listMyJobSeekPosts();

  @override
  Future<List<JobSeekPost>> listActiveJobSeekPosts({int limit = 100}) =>
      inner.listActiveJobSeekPosts(limit: limit);

  @override
  Future<JobSeekPost?> getJobSeekPost(String id) => inner.getJobSeekPost(id);

  @override
  Stream<void> watch() => inner.watch();

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<WorkerProfile> upsertMyProfile(WorkerProfile profile) {
    _requireWrite('ustalık profili kaydetmek');
    return inner.upsertMyProfile(profile);
  }

  @override
  Future<WorkerExperience> addExperience(WorkerExperience experience) {
    _requireWrite('tecrübe eklemek');
    return inner.addExperience(experience);
  }

  @override
  Future<void> deleteExperience(String id) {
    _requireWrite('tecrübe silmek');
    return inner.deleteExperience(id);
  }

  @override
  Future<JobSeekPost> upsertJobSeekPost(JobSeekPost post) {
    _requireWrite('iş arıyorum ilanı kaydetmek');
    return inner.upsertJobSeekPost(post);
  }

  @override
  Future<void> deleteJobSeekPost(String id) {
    _requireWrite('iş arıyorum ilanı silmek');
    return inner.deleteJobSeekPost(id);
  }
}
