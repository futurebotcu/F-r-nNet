import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/job_seek_post.dart';
import '../models/worker_profile.dart';
import 'worker_repository.dart';

/// Supabase V1.2 implementasyonu — worker_profiles + worker_experiences +
/// job_seek_posts. RLS owner CRUD + authenticated read (sektör profili).
class SupabaseWorkerRepository implements WorkerRepository {
  SupabaseWorkerRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  // ───────────────────────────────── Profile

  static const String _profileColumns =
      'id, owner_id, profession_badge, profession_badge_code, '
      'experience_years, cities, city_codes, '
      'shift_preference, salary_expectation, work_type, skills, bio, '
      'created_at, updated_at';

  @override
  Future<WorkerProfile?> getMyProfile() async {
    final ownerId = _requireUserId();
    final row = await _client
        .from('worker_profiles')
        .select(_profileColumns)
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (row == null) return null;
    return WorkerProfile.fromRow(row);
  }

  @override
  Future<WorkerProfile> upsertMyProfile(WorkerProfile profile) async {
    final ownerId = _requireUserId();
    final payload = profile.toInsertRow(ownerId);

    final existing = await _client
        .from('worker_profiles')
        .select('id')
        .eq('owner_id', ownerId)
        .maybeSingle();

    Map<String, dynamic> row;
    if (existing == null) {
      row = await _client
          .from('worker_profiles')
          .insert(payload)
          .select(_profileColumns)
          .single();
    } else {
      row = await _client
          .from('worker_profiles')
          .update(<String, dynamic>{...payload, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('owner_id', ownerId)
          .select(_profileColumns)
          .single();
    }
    _notify();
    return WorkerProfile.fromRow(row);
  }

  // ───────────────────────────────── Experiences

  static const String _experienceColumns =
      'id, owner_id, title, workplace, city, city_code, '
      'start_date, end_date, description, created_at';

  @override
  Future<List<WorkerExperience>> listMyExperiences() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('worker_experiences')
        .select(_experienceColumns)
        .eq('owner_id', ownerId)
        .order('start_date', ascending: false, nullsFirst: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WorkerExperience.fromRow)
        .toList(growable: false);
  }

  @override
  Future<WorkerExperience> addExperience(WorkerExperience experience) async {
    final ownerId = _requireUserId();
    final row = await _client
        .from('worker_experiences')
        .insert(experience.toInsertRow(ownerId))
        .select(_experienceColumns)
        .single();
    _notify();
    return WorkerExperience.fromRow(row);
  }

  @override
  Future<void> deleteExperience(String id) async {
    final ownerId = _requireUserId();
    await _client
        .from('worker_experiences')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  // ───────────────────────────────── Job seek posts

  static const String _postColumns =
      'id, owner_id, title, profession_badge, profession_badge_code, '
      'city, city_code, experience_years, '
      'salary_expectation, description, is_active, created_at, updated_at';

  @override
  Future<List<JobSeekPost>> listMyJobSeekPosts() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('job_seek_posts')
        .select(_postColumns)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobSeekPost.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<JobSeekPost>> listActiveJobSeekPosts({int limit = 100}) async {
    // RLS: job_seek_posts_select_active_or_own → herhangi authenticated user
    // is_active=true satırları görebilir (worker_and_jobseek migration).
    final rows = await _client
        .from('job_seek_posts')
        .select(_postColumns)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobSeekPost.fromRow)
        .toList(growable: false);
  }

  @override
  Future<JobSeekPost?> getJobSeekPost(String id) async {
    _requireUserId();
    final row = await _client
        .from('job_seek_posts')
        .select(_postColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return JobSeekPost.fromRow(row);
  }

  @override
  Future<JobSeekPost> upsertJobSeekPost(JobSeekPost post) async {
    final ownerId = _requireUserId();
    final payload = post.toInsertRow(ownerId);

    Map<String, dynamic> row;
    if (post.id == null || post.id!.startsWith('l_')) {
      row = await _client
          .from('job_seek_posts')
          .insert(payload)
          .select(_postColumns)
          .single();
    } else {
      row = await _client
          .from('job_seek_posts')
          .update(<String, dynamic>{...payload, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', post.id!)
          .eq('owner_id', ownerId)
          .select(_postColumns)
          .single();
    }
    _notify();
    return JobSeekPost.fromRow(row);
  }

  @override
  Future<void> deleteJobSeekPost(String id) async {
    final ownerId = _requireUserId();
    await _client
        .from('job_seek_posts')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
