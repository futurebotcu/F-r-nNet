import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/job_offer_post.dart';
import 'job_offer_repository.dart';

class SupabaseJobOfferRepository implements JobOfferRepository {
  SupabaseJobOfferRepository(this._client);

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

  static const String _columns =
      'id, owner_id, bakery_id, title, role_title, role_code, '
      'city, district, city_code, district_code, '
      'description, salary_min, salary_max, '
      'shift_type, shift_code, experience_required, experience_code, '
      'is_active, contact_preference, contact_phone, '
      'author_name, author_role, created_at, updated_at';

  @override
  Future<List<JobOfferPost>> listActiveOffers({int limit = 100}) async {
    final rows = await _client
        .from('job_offer_posts')
        .select(_columns)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobOfferPost.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<JobOfferPost>> listMyOffers() async {
    final ownerId = _requireUserId();
    final rows = await _client
        .from('job_offer_posts')
        .select(_columns)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(500); // Hardening: defansif üst sınır.
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JobOfferPost.fromRow)
        .toList(growable: false);
  }

  @override
  Future<JobOfferPost?> getOffer(String id) async {
    _requireUserId();
    final row = await _client
        .from('job_offer_posts')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return JobOfferPost.fromRow(row);
  }

  @override
  Future<JobOfferPost> upsertOffer(JobOfferPost post) async {
    final ownerId = _requireUserId();
    final payload = post.toInsertRow(ownerId);
    Map<String, dynamic> row;
    if (post.id == null || post.id!.startsWith('lo_')) {
      row = await _client
          .from('job_offer_posts')
          .insert(payload)
          .select(_columns)
          .single();
    } else {
      row = await _client
          .from('job_offer_posts')
          .update(<String, dynamic>{
            ...payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', post.id!)
          .eq('owner_id', ownerId)
          .select(_columns)
          .single();
    }
    _notify();
    return JobOfferPost.fromRow(row);
  }

  @override
  Future<void> setActive(String id, bool active) async {
    final ownerId = _requireUserId();
    await _client
        .from('job_offer_posts')
        .update(<String, dynamic>{'is_active': active})
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Future<void> deleteOffer(String id) async {
    final ownerId = _requireUserId();
    await _client
        .from('job_offer_posts')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
