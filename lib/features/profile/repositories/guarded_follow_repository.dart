import '../../auth/services/auth_required_guard.dart';
import 'follow_repository.dart';

/// V1 Social S2 — guest write korumalı [FollowRepository] dekoratörü.
///
/// Read metodları doğrudan delege; write metodları `canWriteCheck()` false
/// dönerse [GuestActionRequiredException] atar — UI tarafı bunu yakalayıp
/// AuthRequiredSheet'i gösterir.
class GuardedFollowRepository implements FollowRepository {
  GuardedFollowRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final FollowRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<void> followProfile(String userId) {
    _requireWrite('takip etmek');
    return inner.followProfile(userId);
  }

  @override
  Future<void> unfollowProfile(String userId) {
    _requireWrite('takipten çıkmak');
    return inner.unfollowProfile(userId);
  }

  @override
  Future<bool> toggleFollow(String userId) {
    _requireWrite('takibi değiştirmek');
    return inner.toggleFollow(userId);
  }

  @override
  Future<bool> isFollowing(String userId) => inner.isFollowing(userId);

  @override
  Future<({int followers, int following})> getFollowCounts(String userId) =>
      inner.getFollowCounts(userId);

  @override
  Future<List<String>> listFollowerIds(String userId) =>
      inner.listFollowerIds(userId);

  @override
  Future<List<String>> listFollowingIds(String userId) =>
      inner.listFollowingIds(userId);

  @override
  Stream<void> watch() => inner.watch();
}
