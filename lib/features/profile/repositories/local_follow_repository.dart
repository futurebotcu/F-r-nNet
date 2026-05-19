import 'dart:async';

import 'follow_repository.dart';

/// In-memory follow repository. Test ve local mode (Supabase disabled)
/// için. Self-follow yapısal olarak engelli.
class LocalFollowRepository implements FollowRepository {
  LocalFollowRepository({String currentUserId = 'me_misafir'})
      : _meId = currentUserId;

  final String _meId;

  /// `{ followerId → set of followingIds }`.
  final Map<String, Set<String>> _follows = <String, Set<String>>{};

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  @override
  Future<void> followProfile(String userId) async {
    if (userId == _meId) return; // self-follow no-op
    final set = _follows.putIfAbsent(_meId, () => <String>{});
    if (set.add(userId)) _notify();
  }

  @override
  Future<void> unfollowProfile(String userId) async {
    final set = _follows[_meId];
    if (set == null) return;
    if (set.remove(userId)) _notify();
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
    if (userId == _meId) return false;
    return _follows[_meId]?.contains(userId) ?? false;
  }

  @override
  Future<({int followers, int following})> getFollowCounts(
    String userId,
  ) async {
    var followers = 0;
    for (final set in _follows.values) {
      if (set.contains(userId)) followers++;
    }
    final following = _follows[userId]?.length ?? 0;
    return (followers: followers, following: following);
  }

  @override
  Future<List<String>> listFollowerIds(String userId) async {
    final out = <String>[];
    for (final entry in _follows.entries) {
      if (entry.value.contains(userId)) out.add(entry.key);
    }
    return out;
  }

  @override
  Future<List<String>> listFollowingIds(String userId) async {
    return List<String>.from(_follows[userId] ?? const <String>{});
  }

  @override
  Stream<void> watch() => _changes.stream;
}
