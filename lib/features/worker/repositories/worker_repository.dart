import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';

/// Bireysel ustalık profili + tecrübe + iş arıyorum ilanları için soyut erişim.
///
/// V1.2 implementasyonları:
/// - `LocalWorkerRepository` — in-memory, Supabase yokken.
/// - `SupabaseWorkerRepository` — `worker_profiles` + `worker_experiences`
///   + `job_seek_posts` tablolarına yazar/okur. RLS owner CRUD; read serbest
///   (authenticated).
abstract class WorkerRepository {
  Future<WorkerProfile?> getMyProfile();
  Future<WorkerProfile> upsertMyProfile(WorkerProfile profile);

  Future<List<WorkerExperience>> listMyExperiences();
  Future<WorkerExperience> addExperience(WorkerExperience experience);
  Future<void> deleteExperience(String id);

  Future<List<JobSeekPost>> listMyJobSeekPosts();
  Future<JobSeekPost?> getJobSeekPost(String id);
  Future<JobSeekPost> upsertJobSeekPost(JobSeekPost post);
  Future<void> deleteJobSeekPost(String id);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
