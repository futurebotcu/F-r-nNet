import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'follow_repository.dart';

/// Supabase implementasyonu. `profile_follows` tablosu üzerinde çalışır.
///
/// RLS server tarafında:
///   * SELECT herkes (count'lar dahil)
///   * INSERT yalnız `follower_id = auth.uid()`
///   * DELETE yalnız `follower_id = auth.uid()`
///
/// Client tarafı ek defansif kontrol:
///   * Self-follow erken-reddetme (server CHECK constraint zaten ikinci
///     katman).
class SupabaseFollowRepository implements FollowRepository {
  SupabaseFollowRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> followProfile(String userId) async {
    final me = _currentUserId;
    if (me == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    if (me == userId) return; // self-follow no-op
    try {
      await _client.from('profile_follows').insert(<String, dynamic>{
        'follower_id': me,
        'following_id': userId,
      });
    } on sb.PostgrestException catch (e) {
      // 23505 = unique_violation (PK ihlali → zaten takipte; idempotent).
      // 23514 = check_violation (self-follow CHECK; client zaten engeller).
      if (e.code == '23505' || e.code == '23514') return;
      rethrow;
    }
    _notify();
  }

  @override
  Future<void> unfollowProfile(String userId) async {
    final me = _currentUserId;
    if (me == null) return;
    await _client
        .from('profile_follows')
        .delete()
        .eq('follower_id', me)
        .eq('following_id', userId);
    _notify();
  }

  @override
  Future<bool> toggleFollow(String userId) async {
    final following = await isFollowing(userId);
    if (following) {
      await unfollowProfile(userId);
      return false;
    }
    await followProfile(userId);
    return true;
  }

  @override
  Future<bool> isFollowing(String userId) async {
    final me = _currentUserId;
    if (me == null || me == userId) return false;
    final row = await _client
        .from('profile_follows')
        .select('follower_id')
        .eq('follower_id', me)
        .eq('following_id', userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<({int followers, int following})> getFollowCounts(
    String userId,
  ) async {
    // İki paralel count (RLS SELECT herkes, sayılar açık).
    final results = await Future.wait<int>(<Future<int>>[
      _countOf(column: 'following_id', value: userId),
      _countOf(column: 'follower_id', value: userId),
    ]);
    return (followers: results[0], following: results[1]);
  }

  Future<int> _countOf({required String column, required String value}) async {
    try {
      final res = await _client
          .from('profile_follows')
          .select('follower_id')
          .eq(column, value)
          .count(sb.CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<String>> listFollowerIds(String userId) async {
    final rows = await _client
        .from('profile_follows')
        .select('follower_id')
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['follower_id'] as String)
        .toList(growable: false);
  }

  @override
  Future<List<String>> listFollowingIds(String userId) async {
    final rows = await _client
        .from('profile_follows')
        .select('following_id')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['following_id'] as String)
        .toList(growable: false);
  }

  @override
  Stream<void> watch() => _changes.stream;
}
