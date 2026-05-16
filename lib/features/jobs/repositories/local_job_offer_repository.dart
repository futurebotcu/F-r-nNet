import 'dart:async';

import '../models/job_offer_post.dart';
import 'job_offer_repository.dart';

class LocalJobOfferRepository implements JobOfferRepository {
  final List<JobOfferPost> _items = <JobOfferPost>[];
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);
  String _gen() => 'lo_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<List<JobOfferPost>> listActiveOffers({int limit = 100}) async {
    final out = _items.where((p) => p.isActive).toList();
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    if (out.length > limit) out.length = limit;
    return List.unmodifiable(out);
  }

  @override
  Future<List<JobOfferPost>> listMyOffers() async {
    // Local mode'da "my" ayrımı yok — tüm liste.
    final out = List<JobOfferPost>.from(_items);
    out.sort((a, b) {
      final ad = a.createdAt ?? DateTime(1900);
      final bd = b.createdAt ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return List.unmodifiable(out);
  }

  @override
  Future<JobOfferPost?> getOffer(String id) async {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<JobOfferPost> upsertOffer(JobOfferPost post) async {
    final now = DateTime.now();
    final idx = _items.indexWhere((p) => p.id == post.id && post.id != null);
    if (idx >= 0) {
      _items[idx] = _replace(_items[idx], post, updatedAt: now);
      _notify();
      return _items[idx];
    }
    final saved = JobOfferPost(
      id: post.id ?? _gen(),
      ownerId: post.ownerId,
      bakeryId: post.bakeryId,
      title: post.title,
      roleTitle: post.roleTitle,
      city: post.city,
      district: post.district,
      description: post.description,
      salaryMin: post.salaryMin,
      salaryMax: post.salaryMax,
      shiftType: post.shiftType,
      experienceRequired: post.experienceRequired,
      isActive: post.isActive,
      contactPreference: post.contactPreference,
      authorName: post.authorName,
      authorRole: post.authorRole,
      createdAt: post.createdAt ?? now,
      updatedAt: now,
    );
    _items.add(saved);
    _notify();
    return saved;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    final i = _items.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(isActive: active);
    _notify();
  }

  @override
  Future<void> deleteOffer(String id) async {
    _items.removeWhere((p) => p.id == id);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  JobOfferPost _replace(JobOfferPost old, JobOfferPost upd, {required DateTime updatedAt}) {
    return JobOfferPost(
      id: old.id,
      ownerId: old.ownerId,
      bakeryId: upd.bakeryId ?? old.bakeryId,
      title: upd.title,
      roleTitle: upd.roleTitle,
      city: upd.city,
      district: upd.district,
      description: upd.description,
      salaryMin: upd.salaryMin,
      salaryMax: upd.salaryMax,
      shiftType: upd.shiftType,
      experienceRequired: upd.experienceRequired,
      isActive: upd.isActive,
      contactPreference: upd.contactPreference,
      authorName: old.authorName,
      authorRole: old.authorRole,
      createdAt: old.createdAt,
      updatedAt: updatedAt,
    );
  }
}
