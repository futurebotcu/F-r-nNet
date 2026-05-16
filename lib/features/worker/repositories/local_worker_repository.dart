import 'dart:async';

import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';
import 'worker_repository.dart';

/// In-memory bireysel repo — Supabase yokken / oturumsuz fallback.
class LocalWorkerRepository implements WorkerRepository {
  WorkerProfile? _profile;
  final List<WorkerExperience> _experiences = <WorkerExperience>[];
  final List<JobSeekPost> _posts = <JobSeekPost>[];

  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  void _notify() => _changes.add(null);
  String _gen() => 'l_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<WorkerProfile?> getMyProfile() async => _profile;

  @override
  Future<WorkerProfile> upsertMyProfile(WorkerProfile profile) async {
    final now = DateTime.now();
    _profile = profile.copyWith(
      id: profile.id ?? 'l_profile',
      createdAt: _profile?.createdAt ?? now,
      updatedAt: now,
    );
    _notify();
    return _profile!;
  }

  @override
  Future<List<WorkerExperience>> listMyExperiences() async {
    final out = List<WorkerExperience>.from(_experiences);
    out.sort((a, b) {
      final ad = a.startDate ?? a.createdAt ?? DateTime(1900);
      final bd = b.startDate ?? b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return List.unmodifiable(out);
  }

  @override
  Future<WorkerExperience> addExperience(WorkerExperience experience) async {
    final saved = experience.copyWith(
      id: experience.id ?? _gen(),
      createdAt: experience.createdAt ?? DateTime.now(),
    );
    _experiences.add(saved);
    _notify();
    return saved;
  }

  @override
  Future<void> deleteExperience(String id) async {
    _experiences.removeWhere((e) => e.id == id);
    _notify();
  }

  @override
  Future<List<JobSeekPost>> listMyJobSeekPosts() async {
    final out = List<JobSeekPost>.from(_posts);
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return List.unmodifiable(out);
  }

  @override
  Future<List<JobSeekPost>> listActiveJobSeekPosts({int limit = 100}) async {
    final out = _posts.where((p) => p.isActive).toList();
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    if (out.length > limit) out.length = limit;
    return List.unmodifiable(out);
  }

  @override
  Future<JobSeekPost?> getJobSeekPost(String id) async {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<JobSeekPost> upsertJobSeekPost(JobSeekPost post) async {
    final now = DateTime.now();
    final idx = _posts.indexWhere((p) => p.id == post.id && post.id != null);
    if (idx >= 0) {
      _posts[idx] = post.copyWith(updatedAt: now);
      _notify();
      return _posts[idx];
    }
    final saved = post.copyWith(
      id: post.id ?? _gen(),
      createdAt: post.createdAt ?? now,
      updatedAt: now,
    );
    _posts.add(saved);
    _notify();
    return saved;
  }

  @override
  Future<void> deleteJobSeekPost(String id) async {
    _posts.removeWhere((p) => p.id == id);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
